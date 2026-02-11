create table public.product_images (
  id bigint NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  product_id bigint not null references public.products(id) ON DELETE CASCADE,
  image_url text not null,
  is_thumbnail boolean default false,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.product_images enable row level security;
