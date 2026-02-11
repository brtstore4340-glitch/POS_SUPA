-- RLS for public.profiles (admin policy)
-- This policy assumes get_user_role() works
CREATE POLICY "Admins can manage all profiles."
ON public.profiles FOR ALL
USING (public.get_user_role() = 'admin')
WITH CHECK (public.get_user_role() = 'admin');

-- RLS for public.user_pins (admin policy)
-- This policy assumes get_user_role() works
CREATE POLICY "Admins can manage all user pins."
ON public.user_pins FOR ALL
USING (public.get_user_role() = 'admin')
WITH CHECK (public.get_user_role() = 'admin');

-- RLS for public.ui_menus
ALTER TABLE public.ui_menus ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View UI menus based on role"
ON public.ui_menus FOR SELECT
USING (
    public.get_user_role() = 'admin' OR
    public.get_user_role() = 'cashier'
    -- Add other roles as needed
);

-- RLS for public.products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View products based on role"
ON public.products FOR SELECT
USING (
    public.get_user_role() = 'admin' OR
    public.get_user_role() = 'cashier'
);
CREATE POLICY "Manage products for admin"
ON public.products FOR ALL
USING (public.get_user_role() = 'admin')
WITH CHECK (public.get_user_role() = 'admin');



-- Assuming a public.bills table exists for sales records
-- RLS for public.bills
-- Bills might be more complex, e.g., cashiers can create/view their own, admins can view all.
-- Placeholder for public.bills
-- ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "View own bills as cashier"
-- ON public.bills FOR SELECT
-- USING (public.get_user_role() = 'cashier' AND public.get_employee_id() = employee_id);
--
-- CREATE POLICY "Admin access to all bills"
-- ON public.bills FOR ALL
-- USING (public.get_user_role() = 'admin')
-- WITH CHECK (public.get_user_role() = 'admin');