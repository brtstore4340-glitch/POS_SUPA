-- supabase/migrations/20260210000004_create_daily_sales_fn.sql

CREATE OR REPLACE FUNCTION public.get_daily_sales_summary(p_date date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Ensure the user is an admin to access this report
    IF (auth.jwt() ->> 'user_role') <> 'admin' THEN
        RAISE EXCEPTION 'Permission denied: Admin role required.';
    END IF;

    RETURN (
        SELECT json_build_object(
            'total_sales', COALESCE(SUM(total_price), 0),
            'transaction_count', COUNT(*)
        )
        FROM public.carts
        WHERE status = 'completed' AND created_at::date = p_date
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_daily_sales_summary(date) TO authenticated;
