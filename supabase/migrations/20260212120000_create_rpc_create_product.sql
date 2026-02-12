-- Migration: Create rpc_create_product function
-- Timestamp: 20260212120000

CREATE OR REPLACE FUNCTION public.rpc_create_product(product_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER -- Use SECURITY DEFINER to enforce role checks inside function
SET search_path = public -- Secure search_path
AS $$
DECLARE
  v_role text;
  new_product_record jsonb;
  v_details jsonb;
  v_barcode text[];
BEGIN
  -- 1. Check permissions (RBAC)
  -- Allow 'admin' and 'manager' roles to create products
  v_role := auth.jwt() ->> 'user_role';
  IF v_role NOT IN ('admin', 'manager') THEN
    RAISE EXCEPTION 'Access denied: User must be admin or manager. Current role: %', v_role;
  END IF;

  -- 2. Prepare data
  -- Extract details by removing known columns to avoid duplication in details column
  v_details := product_data - 'sku' - 'name' - 'category_id' - 'price' - 'is_active' - 'barcode' - 'category';

  -- Handle barcode: convert JSON array to text array
  IF jsonb_typeof(product_data->'barcode') = 'array' THEN
    SELECT array_agg(x) INTO v_barcode
    FROM jsonb_array_elements_text(product_data->'barcode') t(x);
  ELSE
    v_barcode := NULL;
  END IF;

  -- 3. Insert into products table
  INSERT INTO public.products (
    sku,
    name,
    category_id,
    price,
    is_active,
    barcode,
    details,
    category
  )
  VALUES (
    product_data->>'sku',
    product_data->>'name',
    (NULLIF(product_data->>'category_id', ''))::uuid,
    COALESCE((NULLIF(product_data->>'price', ''))::numeric, 0),
    COALESCE((NULLIF(product_data->>'is_active', ''))::boolean, true),
    v_barcode,
    v_details,
    product_data->>'category'
  )
  RETURNING to_jsonb(products.*) INTO new_product_record;

  RETURN new_product_record;
END;
$$;

-- Grant execute permission to authenticated users (role check is inside)
GRANT EXECUTE ON FUNCTION public.rpc_create_product(jsonb) TO authenticated;
