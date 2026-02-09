-- supabase/migrations/20260210000003_create_cart_tables.sql

-- 1. Create the carts table
CREATE TABLE public.carts (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'active',
    total_price numeric NOT NULL DEFAULT 0
);
COMMENT ON TABLE public.carts IS 'Stores shopping cart information for active and completed transactions.';

-- 2. Create the cart_items table
CREATE TABLE public.cart_items (
    id bigint NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    cart_id uuid NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id bigint NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL CHECK (quantity > 0)
);
COMMENT ON TABLE public.cart_items IS 'Stores individual items associated with a shopping cart.';
CREATE INDEX idx_cart_items_cart_id ON public.cart_items(cart_id);

-- 3. Enable Row Level Security (RLS) on both tables
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies for carts table
CREATE POLICY "Allow users to manage their own carts"
ON public.carts
FOR ALL
USING ( (auth.uid() = user_id) );

CREATE POLICY "Allow admins full access to carts"
ON public.carts
FOR ALL
USING ( (auth.jwt() ->> 'user_role') = 'admin' );

-- 5. Create RLS Policies for cart_items table
CREATE POLICY "Allow users to manage items in their own carts"
ON public.cart_items
FOR ALL
USING ( EXISTS (
    SELECT 1 FROM public.carts
    WHERE carts.id = cart_items.cart_id AND carts.user_id = auth.uid()
));

CREATE POLICY "Allow admins full access to cart_items"
ON public.cart_items
FOR ALL
USING ( (auth.jwt() ->> 'user_role') = 'admin' );

-- 6. Set ownership
ALTER TABLE public.carts OWNER TO postgres;
ALTER TABLE public.cart_items OWNER TO postgres;
