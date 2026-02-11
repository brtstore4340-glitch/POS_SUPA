-- supabase/migrations/20260211100001_rpc_and_rls_helper_functions.sql

-- Function to get the user's role from the user_profiles table
-- This function will be used in RLS policies to check the user's role dynamically.
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER -- Use SECURITY DEFINER to run with creator's privileges (postgres), avoiding RLS issues on profiles table
AS $$
DECLARE
    user_role text;
BEGIN
    SELECT up.user_role INTO user_role
    FROM public.user_profiles up
    WHERE up.id = auth.uid();

    RETURN user_role;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated;


-- Function to get the employee_id from the user_profiles table
CREATE OR REPLACE FUNCTION public.get_employee_id()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    employee_id text;
BEGIN
    SELECT up.employee_id INTO employee_id
    FROM public.user_profiles up
    WHERE up.id = auth.uid();

    RETURN employee_id;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.get_employee_id() TO authenticated;


-- RPC Function to verify a user's PIN and return associated employee_id and role
-- This function is crucial for the post-Google OAuth PIN validation flow.
CREATE OR REPLACE FUNCTION public.verify_user_pin(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_pin_hash text;
    v_profile_id uuid;
    v_employee_id text;
    v_user_role text;
BEGIN
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated.';
    END IF;

    -- Find the profile_id linked to the authenticated user
    SELECT id INTO v_profile_id
    FROM public.user_profiles
    WHERE id = v_user_id;

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'User profile not found.';
    END IF;

    -- Verify the provided PIN against hashed PINs for this profile
    SELECT up.pin_hash, upr.employee_id, upr.user_role
    INTO v_pin_hash, v_employee_id, v_user_role
    FROM public.user_pins up
    JOIN public.user_profiles upr ON up.profile_id = upr.id
    WHERE up.profile_id = v_profile_id AND up.is_active = true AND up.pin_hash = crypt(p_pin, up.pin_hash);

    IF v_pin_hash IS NULL THEN
        RAISE EXCEPTION 'Invalid PIN or inactive PIN.';
    END IF;

    -- If PIN is valid, update the user's raw_user_meta_data in auth.users to include the active employee_id and role
    -- This will enrich the JWT for subsequent RLS policies.
    PERFORM auth.update_user_metadata(
        v_user_id,
        jsonb_build_object(
            'active_employee_id', v_employee_id,
            'active_user_role', v_user_role
        )
    );

    RETURN jsonb_build_object(
        'employee_id', v_employee_id,
        'user_role', v_user_role,
        'message', 'PIN verified and context updated.'
    );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.verify_user_pin(text) TO authenticated;


-- RPC Function for Admin to manage user PINs (create, update, deactivate)
CREATE OR REPLACE FUNCTION public.admin_manage_user_pins(
    p_target_user_id uuid,
    p_employee_id text,
    p_new_pin text DEFAULT NULL,
    p_new_role text DEFAULT NULL,
    p_is_active boolean DEFAULT NULL,
    p_pin_entry_id uuid DEFAULT NULL -- Used for updating a specific PIN entry
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_role text := public.get_user_role();
    v_profile_id uuid;
    v_hashed_pin text;
BEGIN
    -- Only allow admins to execute this function
    IF v_caller_role <> 'admin' THEN
        RAISE EXCEPTION 'Permission denied: Admin role required.';
    END IF;

    -- Get the profile_id for the target_user_id
    SELECT id INTO v_profile_id
    FROM public.user_profiles
    WHERE id = p_target_user_id;

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Target user profile not found.';
    END IF;

    -- Hash the new PIN if provided
    IF p_new_pin IS NOT NULL THEN
        v_hashed_pin := crypt(p_new_pin, gen_salt('bf'));
    END IF;

    IF p_pin_entry_id IS NOT NULL THEN
        -- Update an existing PIN entry
        UPDATE public.user_pins
        SET
            pin_hash = COALESCE(v_hashed_pin, pin_hash),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = now()
        WHERE id = p_pin_entry_id AND profile_id = v_profile_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PIN entry not found or does not belong to target user.';
        END IF;
    ELSE
        -- Create a new PIN entry or update profile (if employee_id is already linked)
        -- First, check if an employee_id already exists for this profile_id and p_employee_id
        PERFORM 1 FROM public.user_profiles WHERE id = v_profile_id AND employee_id = p_employee_id;

        IF FOUND THEN
             -- Update existing profile entry role if new_role provided, and create new pin entry
            IF p_new_role IS NOT NULL THEN
                UPDATE public.user_profiles
                SET user_role = p_new_role, updated_at = now()
                WHERE id = v_profile_id AND employee_id = p_employee_id;
            END IF;
            -- Always insert a new PIN entry even if profile is updated to allow multiple PINs for one employee_id/role pair
            INSERT INTO public.user_pins (profile_id, pin_hash, is_active) VALUES (v_profile_id, v_hashed_pin, COALESCE(p_is_active, true));
        ELSE
            -- If employee_id is not linked to this profile, it's an error or a new profile scenario
            -- For now, assume employee_id should already exist on the user_profiles for this user_id
            -- or that a new profile with employee_id is handled separately.
            RAISE EXCEPTION 'Employee ID must be linked to user profile before adding PINs, or PIN Entry ID required for update.';
        END IF;
    END IF;

    -- Additionally, update the user_profiles table if a new role is provided for the main profile
    IF p_new_role IS NOT NULL THEN
        UPDATE public.user_profiles
        SET user_role = p_new_role, updated_at = now()
        WHERE id = v_profile_id;
    END IF;

    RETURN jsonb_build_object('status', 'success', 'message', 'User PINs and profile updated.');
END;
$$;

-- Grant execution to authenticated users (admins will be filtered by internal logic)
GRANT EXECUTE ON FUNCTION public.admin_manage_user_pins(uuid, text, text, text, boolean, uuid) TO authenticated;


-- This function is a placeholder based on the previous architects suggestion, but it is not implemented in Supabase architect due to changes in requirement.
-- Instead, the `verify_user_pin` directly updates `auth.users.raw_user_meta_data`.
-- CREATE OR REPLACE FUNCTION auth.update_user_metadata(user_id uuid, metadata jsonb)
-- RETURNS void
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- AS $$
-- BEGIN
--     UPDATE auth.users
--     SET raw_user_meta_data = raw_user_meta_data || metadata
--     WHERE id = user_id;
-- END;
-- $$;
