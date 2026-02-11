-- Policies for categories table

-- Enable ALL access for admin and manager users
create policy "Enable ALL access for admin and manager users"
on public.categories
for all
to authenticated
using (get_user_role() in ('admin', 'manager'))
with check (get_user_role() in ('admin', 'manager'));

-- Enable SELECT access for staff and analyst users
create policy "Enable SELECT access for staff and analyst users"
on public.categories
for select
to authenticated
using (get_user_role() in ('staff', 'analyst'));

