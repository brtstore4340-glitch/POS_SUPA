-- Helper function to get the user's role from JWT
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN auth.jwt() ->> 'user_role';
END;
$$;

-- Helper function to get the user's employee_id from JWT
CREATE OR REPLACE FUNCTION public.get_employee_id()
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN auth.jwt() ->> 'employee_id';
END;
$$;

-- Function to verify PIN and return role/employee_id
CREATE OR REPLACE FUNCTION public.verify_user_pin(p_user_id UUID, p_plain_pin TEXT)
RETURNS TABLE (employee_id TEXT, role TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pin_hash TEXT;
    v_employee_id TEXT;
    v_role TEXT;
BEGIN
    SELECT pin_hash, public.user_pins.employee_id, public.user_pins.role
    INTO v_pin_hash, v_employee_id, v_role
    FROM public.user_pins
    WHERE user_id = p_user_id AND is_active = TRUE;

    IF v_pin_hash IS NULL THEN
        RAISE EXCEPTION 'PIN not found or inactive for user.';
    END IF;

    -- Compare the provided plain PIN with the stored hash
    -- Using crypt for bcrypt comparison
    IF crypt(p_plain_pin, v_pin_hash) = v_pin_hash THEN
        RETURN QUERY SELECT v_employee_id, v_role;
    ELSE
        RAISE EXCEPTION 'Invalid PIN.';
    END IF;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.verify_user_pin(UUID, TEXT) TO authenticated;

-- Function to update user metadata with role and employee_id after successful PIN verification
CREATE OR REPLACE FUNCTION public.set_user_authentication_context(p_employee_id TEXT, p_role TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_raw_meta_data JSONB;
    v_new_raw_meta_data JSONB;
BEGIN
    -- Ensure the user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated.';
    END IF;

    -- Get current raw_user_meta_data
    SELECT raw_user_meta_data INTO v_current_raw_meta_data
    FROM auth.users
    WHERE id = v_user_id;

    -- Construct new raw_user_meta_data with 'user_role' and 'employee_id'
    -- If raw_user_meta_data is null, initialize it as an empty jsonb object first.
    v_new_raw_meta_data := COALESCE(v_current_raw_meta_data, '{}'::jsonb) || jsonb_build_object('user_role', p_role, 'employee_id', p_employee_id);

    -- Update auth.users.raw_user_meta_data
    UPDATE auth.users
    SET raw_user_meta_data = v_new_raw_meta_data
    WHERE id = v_user_id;

    RETURN '{"status": "success", "message": "User authentication context updated."}';
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.set_user_authentication_context(TEXT, TEXT) TO authenticated;

-- Function for admin to manage user pins
CREATE OR REPLACE FUNCTION public.admin_manage_user_pins(
    p_target_user_id UUID,
    p_employee_id TEXT,
    p_operation TEXT, -- 'CREATE', 'UPDATE', 'DEACTIVATE', 'DELETE'
    p_new_plain_pin TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_current_user_role TEXT;
    v_pin_hash TEXT;
BEGIN
    -- Check if the current user is an admin using the helper function
    IF public.get_user_role() != 'admin' THEN
        RAISE EXCEPTION 'Permission denied: Only admins can manage user pins.';
    END IF;

    IF p_operation = 'CREATE' THEN
        IF p_new_plain_pin IS NULL OR p_role IS NULL THEN
            RAISE EXCEPTION 'Missing parameters for CREATE operation: new_plain_pin and role are required.';
        END IF;
        -- Hash the new PIN using gen_salt and crypt
        v_pin_hash := crypt(p_new_plain_pin, gen_salt('bf'));
        INSERT INTO public.user_pins (user_id, employee_id, pin_hash, role, is_active)
        VALUES (p_target_user_id, p_employee_id, v_pin_hash, p_role, TRUE);
        RETURN '{"status": "success", "message": "PIN created successfully."}';

    ELSIF p_operation = 'UPDATE' THEN
        IF p_new_plain_pin IS NOT NULL THEN
            v_pin_hash := crypt(p_new_plain_pin, gen_salt('bf'));
        END IF;

        UPDATE public.user_pins
        SET
            pin_hash = COALESCE(v_pin_hash, pin_hash),
            role = COALESCE(p_role, role),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = NOW()
        WHERE user_id = p_target_user_id AND employee_id = p_employee_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'PIN not found for update.';
        END IF;
        RETURN '{"status": "success", "message": "PIN updated successfully."}';

    ELSIF p_operation = 'DEACTIVATE' THEN
        UPDATE public.user_pins
        SET is_active = FALSE, updated_at = NOW()
        WHERE user_id = p_target_user_id AND employee_id = p_employee_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'PIN not found for deactivation.';
        END IF;
        RETURN '{"status": "success", "message": "PIN deactivated successfully."}';

    ELSIF p_operation = 'DELETE' THEN
        DELETE FROM public.user_pins
        WHERE user_id = p_target_user_id AND employee_id = p_employee_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'PIN not found for deletion.';
        END IF;
        RETURN '{"status": "success", "message": "PIN deleted successfully."}';

    ELSE
        RAISE EXCEPTION 'Invalid operation type: %', p_operation;
    END IF;
END;
$$;

-- Grant execution to authenticated users (admins will call this)
GRANT EXECUTE ON FUNCTION public.admin_manage_user_pins(UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;