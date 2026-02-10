-- Fixes the mutable search path vulnerability in the get_distinct_categories function.

CREATE OR REPLACE FUNCTION public.get_distinct_categories()
RETURNS text[]
LANGUAGE sql
STABLE
SET search_path = public -- Explicitly set the search path for security and stability
AS $$
    SELECT array_agg(DISTINCT category ORDER BY category)
    FROM public.products
    WHERE is_active = true AND category IS NOT NULL;
$$;

-- Re-grant permissions to be safe, although it should persist from the original creation.
GRANT EXECUTE ON FUNCTION public.get_distinct_categories() TO authenticated;
