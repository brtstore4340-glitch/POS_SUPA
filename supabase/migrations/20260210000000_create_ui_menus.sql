-- supabase/migrations/20260210000000_create_ui_menus.sql

-- 1. Create the ui_menus table
CREATE TABLE public.ui_menus (
    id bigint NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    label text NOT NULL,
    route text NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    "order" integer NOT NULL DEFAULT 0,
    placement jsonb NOT NULL DEFAULT '{}'::jsonb,
    access jsonb NOT NULL DEFAULT '{"allowedRoles": ["admin"]}'::jsonb
);

-- 2. Add comments to the table and columns for clarity
COMMENT ON TABLE public.ui_menus IS 'Stores dynamic navigation menu items for the application UI.';
COMMENT ON COLUMN public.ui_menus.label IS 'The display text for the menu item.';
COMMENT ON COLUMN public.ui_menus.route IS 'The application route/path for navigation.';
COMMENT ON COLUMN public.ui_menus.enabled IS 'If false, the menu item will not be displayed.';
COMMENT ON COLUMN public.ui_menus."order" IS 'The sort order for the menu item within its group.';
COMMENT ON COLUMN public.ui_menus.placement IS 'JSONB object describing where the menu item should be placed (e.g., group, position).';
COMMENT ON COLUMN public.ui_menus.access IS 'JSONB object defining role-based access control.';

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.ui_menus ENABLE ROW LEVEL SECURITY;

-- 4. Create the Read Access Policy
-- This policy allows users to read a menu item if their role is in the 'allowedRoles' array within the 'access' JSONB column.
-- It assumes you have a custom claim 'user_role' in your JWT.
CREATE POLICY "Allow read access based on user role"
ON public.ui_menus
FOR SELECT
USING (
  (auth.jwt() ->> 'user_role') IS NOT NULL AND
  access @> jsonb_build_object('allowedRoles', jsonb_build_array(auth.jwt() ->> 'user_role'))
);

-- 5. Create the Admin Full Access Policy
-- This allows users with the 'admin' role to bypass RLS for all operations.
CREATE POLICY "Allow full access for admins"
ON public.ui_menus
FOR ALL
USING ( (auth.jwt() ->> 'user_role') = 'admin' );

-- 6. Ensure the table is owned by the correct role for migrations
ALTER TABLE public.ui_menus OWNER TO postgres;

