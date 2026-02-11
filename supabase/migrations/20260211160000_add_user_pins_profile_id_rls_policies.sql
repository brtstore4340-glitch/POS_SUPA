-- supabase/migrations/20260211160000_add_user_pins_profile_id_rls_policies.sql

-- Policy: Allow authenticated users to read their own PIN entries
CREATE POLICY "Allow authenticated users to read own pins"
ON public.user_pins
FOR SELECT
TO authenticated
USING ( (SELECT 1 FROM public.user_profiles WHERE id = profile_id AND id = auth.uid()) IS NOT NULL );

-- Policy: Allow authenticated users to create/update their own PIN entries
CREATE POLICY "Allow authenticated users to manage own pins"
ON public.user_pins
FOR ALL
TO authenticated
USING ( (SELECT 1 FROM public.user_profiles WHERE id = profile_id AND id = auth.uid()) IS NOT NULL )
WITH CHECK ( (SELECT 1 FROM public.user_profiles WHERE id = profile_id AND id = auth.uid()) IS NOT NULL );