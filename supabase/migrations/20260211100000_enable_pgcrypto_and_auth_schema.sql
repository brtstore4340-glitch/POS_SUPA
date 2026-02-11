-- supabase/migrations/20260211100000_enable_pgcrypto_and_auth_schema.sql

-- Enable pgcrypto extension for UUID generation and password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create public.user_profiles table
-- This table links auth.users to application-specific profiles with employee_id and user_role.
CREATE TABLE public.user_profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    employee_id text UNIQUE NOT NULL, -- Unique identifier for the employee, acts as system-level username
    user_role text NOT NULL DEFAULT 'staff', -- e.g., 'admin', 'manager', 'analyst', 'staff'
    full_name text, -- Optional: Employee's full name
    is_active boolean NOT NULL DEFAULT true -- For enabling/disabling a profile
);

COMMENT ON TABLE public.user_profiles IS 'Application-specific user profiles, linked to auth.users, storing employee ID and role.';
COMMENT ON COLUMN public.user_profiles.employee_id IS 'Unique employee identification number.';
COMMENT ON COLUMN public.user_profiles.user_role IS 'The role of the user within the application.';

-- Enable Row Level Security (RLS) for user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read their own profile
CREATE POLICY "Allow authenticated users to read own profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING ( auth.uid() = id );

-- Policy: Allow authenticated users to update their own profile (limited fields)
CREATE POLICY "Allow authenticated users to update own profile"
ON public.user_profiles
FOR UPDATE
TO authenticated
USING ( auth.uid() = id )
WITH CHECK ( auth.uid() = id ); -- Only allow updating own profile


-- 2. Create public.user_pins table
-- This table stores multiple PINs associated with a user_profile (and thus a Google authenticated user).
CREATE TABLE IF NOT EXISTS public.user_pins (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    pin_hash text NOT NULL, -- Hashed PIN
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_pins IS 'Stores hashed PINs for multiple roles/employee IDs associated with a user profile.';
COMMENT ON COLUMN public.user_pins.pin_hash IS 'Hashed version of the PIN.';

-- Enable RLS for user_pins
ALTER TABLE public.user_pins ENABLE ROW LEVEL SECURITY;




-- 3. Create public.scraped_data table
-- This table stores raw and processed data from web scraping.
CREATE TABLE public.scraped_data (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    source_url text NOT NULL, -- URL of the scraped source
    scraped_at timestamp with time zone NOT NULL DEFAULT now(),
    data_jsonb jsonb NOT NULL, -- Flexible JSONB column to store scraped data
    status text NOT NULL DEFAULT 'raw', -- e.g., 'raw', 'processed', 'error'
    scraped_by uuid REFERENCES auth.users(id) ON DELETE SET NULL -- User or system who initiated scraping
);

COMMENT ON TABLE public.scraped_data IS 'Stores raw and processed data obtained from web scraping.';
COMMENT ON COLUMN public.scraped_data.source_url IS 'The URL of the website or API endpoint that was scraped.';
COMMENT ON COLUMN public.scraped_data.data_jsonb IS 'The raw or processed data in JSONB format.';

-- Enable RLS for scraped_data
ALTER TABLE public.scraped_data ENABLE ROW LEVEL SECURITY;

-- Policy: Allow admins full access to scraped_data
CREATE POLICY "Allow admins full access to scraped data"
ON public.scraped_data
FOR ALL
USING ( (SELECT user_role FROM public.user_profiles WHERE id = auth.uid()) = 'admin' )
WITH CHECK ( (SELECT user_role FROM public.user_profiles WHERE id = auth.uid()) = 'admin' );

-- Policy: Allow manager and analyst roles read access to scraped_data
CREATE POLICY "Allow manager and analyst read access to scraped data"
ON public.scraped_data
FOR SELECT
TO authenticated
USING ( (SELECT user_role FROM public.user_profiles WHERE id = auth.uid()) IN ('manager', 'analyst', 'admin') );

ALTER TABLE public.user_profiles OWNER TO postgres;
ALTER TABLE public.user_pins OWNER TO postgres;
ALTER TABLE public.scraped_data OWNER TO postgres;
