-- supabase/migrations/20260211130000_add_employee_id_to_carts_tables.sql

ALTER TABLE public.carts
ADD COLUMN employee_id TEXT NULL;

COMMENT ON COLUMN public.carts.employee_id IS 'Employee ID associated with the cart, for role-based access control.';

ALTER TABLE public.cart_items
ADD COLUMN employee_id TEXT NULL;

COMMENT ON COLUMN public.cart_items.employee_id IS 'Employee ID associated with the cart item, inherited from the parent cart.';