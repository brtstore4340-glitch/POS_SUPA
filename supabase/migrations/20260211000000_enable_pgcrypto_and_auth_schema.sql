
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop existing profiles table if it exists and needs recreation or modification
-- This is a placeholder, adapt based on actual existing schema
-- If profiles table already exists, consider ALTER TABLE instead of DROP/CREATE
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Create or alter public.profiles to link to auth.users
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE,
    avatar_url TEXT,
    full_name TEXT,
    -- Add any other profile-specific fields here
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up Row Level Security (RLS) for public.profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone."
ON public.profiles FOR SELECT USING (TRUE);

CREATE POLICY "Users can insert their own profile."
ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile."
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- New table: public.user_pins
CREATE TABLE IF NOT EXISTS public.user_pins (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    employee_id TEXT NOT NULL, -- Removed UNIQUE here, as a user can have multiple pins, but pin+employee_id for a user must be unique. employee_id itself is not unique across users.
    pin_hash TEXT NOT NULL,
    role TEXT NOT NULL, -- e.g., 'admin', 'cashier'
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create index on user_id for faster lookups
CREATE INDEX ON public.user_pins (user_id);

-- Create unique index on user_id and employee_id to ensure a user can only have one active pin per employee_id
CREATE UNIQUE INDEX ON public.user_pins (user_id, employee_id) WHERE is_active = TRUE;

-- Set up Row Level Security (RLS) for public.user_pins
ALTER TABLE public.user_pins ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their own user_pins
CREATE POLICY "Authenticated users can view their own pins."
ON public.user_pins FOR SELECT
USING (auth.uid() = user_id);
