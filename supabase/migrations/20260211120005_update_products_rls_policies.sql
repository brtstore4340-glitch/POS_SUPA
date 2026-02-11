-- Policies for products table
-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "Products read access by authenticated roles" ON public.products;
DROP POLICY IF EXISTS "Products admin full access" ON public.products;

-- Re-create/update policies based on the contract
create policy "Enable ALL access for admin users for products"
on public.products
for all
to authenticated
using (get_user_role() = 'admin')
with check (get_user_role() = 'admin');

create policy "Enable SELECT for manager users for products"
on public.products
for select
to authenticated
using (get_user_role() in ('manager', 'admin', 'staff', 'analyst'));

create policy "Enable INSERT for manager users for products"
on public.products
for insert
to authenticated
with check (get_user_role() in ('manager', 'admin'));

create policy "Enable UPDATE for manager users for products"
on public.products
for update
to authenticated
using (get_user_role() in ('manager', 'admin'))
with check (get_user_role() in ('manager', 'admin'));

create policy "Enable SELECT access for staff users for products"
on public.products
for select
to authenticated
using (get_user_role() = 'staff');

create policy "Enable SELECT access for analyst users for products"
on public.products
for select
to authenticated
using (get_user_role() = 'analyst');
