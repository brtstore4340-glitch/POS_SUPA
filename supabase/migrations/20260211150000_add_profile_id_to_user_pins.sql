-- supabase/migrations/20260211150000_add_profile_id_to_user_pins.sql

-- Add profile_id column to public.user_pins if it doesn't already exist
ALTER TABLE public.user_pins
ADD COLUMN IF NOT EXISTS profile_id uuid;

-- Add foreign key constraint to public.user_profiles
-- This ensures data integrity and links user_pins to user_profiles
ALTER TABLE public.user_pins
ADD CONSTRAINT fk_profile_id
FOREIGN KEY (profile_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.user_pins.profile_id IS 'Foreign key to the public.user_profiles table.';
