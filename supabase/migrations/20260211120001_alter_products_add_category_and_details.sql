alter table public.products
add column category_id uuid references public.categories(id),
add column details jsonb;

-- Optionally, add an index to category_id for performance
create index on public.products (category_id);
