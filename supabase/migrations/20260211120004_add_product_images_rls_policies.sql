-- Policies for product_images table

-- Enable ALL access for admin and manager users
create policy "Enable ALL access for admin and manager users"
on public.product_images
for all
to authenticated
using (get_user_role() in ('admin', 'manager'))
with check (get_user_role() in ('admin', 'manager'));

-- Enable SELECT access for staff and analyst users
create policy "Enable SELECT access for staff and analyst users"
on public.product_images
for select
to authenticated
using (get_user_role() in ('staff', 'analyst'));

