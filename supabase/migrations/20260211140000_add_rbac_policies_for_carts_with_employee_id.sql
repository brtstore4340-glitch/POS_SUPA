-- supabase/migrations/20260211140000_add_rbac_policies_for_carts_with_employee_id.sql

-- RLS for public.carts
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can manage their own carts."
ON public.carts FOR ALL
USING (auth.uid() = user_id AND public.get_employee_id() = employee_id)
WITH CHECK (auth.uid() = user_id AND public.get_employee_id() = employee_id);

CREATE POLICY "Admins can manage all carts."
ON public.carts FOR ALL
USING (public.get_user_role() = 'admin')
WITH CHECK (public.get_user_role() = 'admin');

-- RLS for public.cart_items
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can manage their own cart items."
ON public.cart_items FOR ALL
USING (EXISTS (SELECT 1 FROM public.carts WHERE id = cart_id AND user_id = auth.uid() AND public.get_employee_id() = employee_id))
WITH CHECK (EXISTS (SELECT 1 FROM public.carts WHERE id = cart_id AND user_id = auth.uid() AND public.get_employee_id() = employee_id));

CREATE POLICY "Admins can manage all cart items."
ON public.cart_items FOR ALL
USING (public.get_user_role() = 'admin')
WITH CHECK (public.get_user_role() = 'admin');