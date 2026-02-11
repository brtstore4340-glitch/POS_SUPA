-- supabase/migrations/20260211100002_rbac_rls_policies.sql

-- IMPORTANT: These policies rely on the `get_user_role()` and `get_employee_id()` functions
-- and that `auth.users.raw_user_meta_data` has been updated with `active_user_role` and `active_employee_id`
-- by `verify_user_pin` RPC function upon successful PIN validation.

-- 1. Policies for public.user_profiles table (Admin full access)
-- Drop existing policies if they conflict with admin full access
DROP POLICY IF EXISTS "Allow admins full access to profiles" ON public.user_profiles;

CREATE POLICY "Admin full access to user_profiles"
ON public.user_profiles
FOR ALL
USING ( public.get_user_role() = 'admin' )
WITH CHECK ( public.get_user_role() = 'admin' );

-- 2. Policies for public.user_pins table (Admin full access)
-- Drop existing policies if they conflict with admin full access
DROP POLICY IF EXISTS "Allow admins full access to pins" ON public.user_pins;

CREATE POLICY "Admin full access to user_pins"
ON public.user_pins
FOR ALL
USING ( public.get_user_role() = 'admin' )
WITH CHECK ( public.get_user_role() = 'admin' );

-- 3. Policies for public.ui_menus table
-- Existing policy should be reviewed to use `public.get_user_role()`
-- Assuming original policy was 'Allow read access based on user role'
DROP POLICY IF EXISTS "Allow read access based on user role" ON public.ui_menus;
DROP POLICY IF EXISTS "Allow full access for admins" ON public.ui_menus;

ALTER TABLE public.ui_menus ENABLE ROW LEVEL SECURITY;

CREATE POLICY "UI menus read access by role"
ON public.ui_menus
FOR SELECT
USING ( public.get_user_role() = 'admin' OR public.get_user_role() = 'manager' OR public.get_user_role() = 'analyst' OR public.get_user_role() = 'staff' );

CREATE POLICY "UI menus admin full access"
ON public.ui_menus
FOR ALL
USING ( public.get_user_role() = 'admin' )
WITH CHECK ( public.get_user_role() = 'admin' );

-- 4. Policies for public.products table
-- Existing policies should be updated to use `public.get_user_role()`
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON public.products;
DROP POLICY IF EXISTS "Allow full access for admins" ON public.products;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Products read access by authenticated roles"
ON public.products
FOR SELECT
USING ( public.get_user_role() IN ('admin', 'manager', 'analyst', 'staff') );

CREATE POLICY "Products admin full access"
ON public.products
FOR ALL
USING ( public.get_user_role() = 'admin' )
WITH CHECK ( public.get_user_role() = 'admin' );

-- 5. Policies for public.carts table
-- Update existing policies to use `public.get_user_role()` for 'admin' and 'staff' (cashier equivalent) access
DROP POLICY IF EXISTS "Allow users to manage their own carts" ON public.carts;
DROP POLICY IF EXISTS "Allow admins and cashiers full access to carts" ON public.carts;

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;

-- New Policy: Allow admin and staff (cashier) to manage all carts
CREATE POLICY "Admin and Staff full access to carts"
ON public.carts
FOR ALL
USING ( public.get_user_role() IN ('admin', 'staff') )
WITH CHECK ( public.get_user_role() IN ('admin', 'staff') );

-- 6. Policies for public.cart_items table
-- Update existing policies to use `public.get_user_role()` for 'admin' and 'staff' (cashier equivalent) access
DROP POLICY IF EXISTS "Allow users to manage items in their own carts" ON public.cart_items;
DROP POLICY IF EXISTS "Allow admins and cashiers full access to cart_items" ON public.cart_items;

ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- New Policy: Allow admin and staff (cashier) to manage all cart_items
CREATE POLICY "Admin and Staff full access to cart_items"
ON public.cart_items
FOR ALL
USING ( public.get_user_role() IN ('admin', 'staff') )
WITH CHECK ( public.get_user_role() IN ('admin', 'staff') );

-- 7. Policies for public.scraped_data table (Defined in 20260211100000_enable_pgcrypto_and_auth_schema.sql already)
-- No additional policies needed here, as they are defined with the table creation.

-- 8. Policies for public.bills table (To be created in a later migration, but define policies based on current roles)
-- Assuming public.bills will exist and need RLS for admin/staff
-- Policies for public.bills (Future Migration)
-- DROP POLICY IF EXISTS "Allow authenticated users to read bills" ON public.bills;
-- DROP POLICY IF EXISTS "Allow cashiers and admins to create bills" ON public.bills;
--
-- ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY "Bills read access by authenticated roles"
-- ON public.bills
-- FOR SELECT
-- USING ( public.get_user_role() IN ('admin', 'manager', 'analyst', 'staff') );
--
-- CREATE POLICY "Bills admin and staff create access"
-- ON public.bills
-- FOR INSERT
-- USING ( public.get_user_role() IN ('admin', 'staff') )
-- WITH CHECK ( public.get_user_role() IN ('admin', 'staff') );
