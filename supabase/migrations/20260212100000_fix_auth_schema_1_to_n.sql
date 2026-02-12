-- Migration: Fix Auth Schema for 1:N (User -> Profiles)

-- 1. Ensure user_profiles has user_id column
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 2. Populate user_id if null (assuming id was user_id previously)
DO $$ 
BEGIN
    -- Only run update if user_id is null and id matches a user
    -- We assume id was the user_id in the 1:1 schema
    UPDATE public.user_profiles 
    SET user_id = id 
    WHERE user_id IS NULL AND EXISTS (SELECT 1 FROM auth.users WHERE id = user_profiles.id);
END $$;

-- 3. Drop Foreign Key on id if it exists (to allow id to be independent UUID)
ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS user_profiles_id_fkey;

-- 4. Delete orphaned profiles (where user_id is still null) to enforce NOT NULL
DELETE FROM public.user_profiles WHERE user_id IS NULL;

-- 5. Set user_id NOT NULL
ALTER TABLE public.user_profiles ALTER COLUMN user_id SET NOT NULL;

-- 6. Change id default to gen_random_uuid() if not already
ALTER TABLE public.user_profiles ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 7. Update RLS on user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles visible to owner" ON public.user_profiles;
DROP POLICY IF EXISTS "Profiles insertable by owner" ON public.user_profiles;
DROP POLICY IF EXISTS "Profiles updatable by owner" ON public.user_profiles;

CREATE POLICY "Profiles visible to owner" ON public.user_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Profiles insertable by owner" ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Profiles updatable by owner" ON public.user_profiles FOR UPDATE USING (auth.uid() = user_id);

-- 8. Update RLS on user_pins (needs to join via user_profiles)
ALTER TABLE public.user_pins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read own pins" ON public.user_pins;
DROP POLICY IF EXISTS "Allow authenticated users to manage own pins" ON public.user_pins;

CREATE POLICY "Allow authenticated users to read own pins" ON public.user_pins FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = user_pins.profile_id AND user_id = auth.uid())
);

CREATE POLICY "Allow authenticated users to manage own pins" ON public.user_pins FOR ALL USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = user_pins.profile_id AND user_id = auth.uid())
) WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = user_pins.profile_id AND user_id = auth.uid())
);

-- 9. Scraped data policies
ALTER TABLE public.scraped_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Scraped data visible to authenticated users" ON public.scraped_data;
CREATE POLICY "Scraped data visible to authenticated users" ON public.scraped_data FOR SELECT TO authenticated USING (true);
