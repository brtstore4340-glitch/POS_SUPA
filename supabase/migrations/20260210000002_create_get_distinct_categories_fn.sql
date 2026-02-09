-- supabase/migrations/20260210000002_create_get_distinct_categories_fn.sql

CREATE OR REPLACE FUNCTION public.get_distinct_categories()
RETURNS text[]
LANGUAGE sql
STABLE
AS $$
    SELECT array_agg(DISTINCT category ORDER BY category)
    FROM public.products
    WHERE is_active = true AND category IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.get_distinct_categories() TO authenticated;
