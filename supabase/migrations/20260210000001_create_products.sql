-- supabase/migrations/20260210000001_create_products.sql

-- 1. Create the products table
CREATE TABLE public.products (
    id bigint NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    sku text UNIQUE,
    name text NOT NULL,
    category text,
    price numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    barcode text[]
);

-- 2. Add comments for clarity
COMMENT ON TABLE public.products IS 'Stores product information for the POS system.';
COMMENT ON COLUMN public.products.sku IS 'Stock Keeping Unit - a unique identifier for each product.';
COMMENT ON COLUMN public.products.barcode IS 'An array of scannable barcode values.';

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 4. Create Read Access Policy for authenticated users
CREATE POLICY "Allow read access to authenticated users"
ON public.products
FOR SELECT
TO authenticated
USING (true);

-- 5. Create Write Access Policy for admins
-- This allows users with the 'admin' role to perform all operations.
CREATE POLICY "Allow full access for admins"
ON public.products
FOR ALL
TO authenticated
USING ( (auth.jwt() ->> 'user_role') = 'admin' )
WITH CHECK ( (auth.jwt() ->> 'user_role') = 'admin' );

-- 6. Ensure the table is owned by the correct role
ALTER TABLE public.products OWNER TO postgres;

