import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

// Helper function to validate UUID
const isUUID = (uuid: string) => {
    const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return regex.test(uuid);
};

serve(async (req) => {
    // CORS headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    };

    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { category_id, search_term, limit = 10, offset = 0, is_active } = await req.json();

        // Validate input
        if (category_id && (!isUUID(category_id))) {
            return new Response(JSON.stringify({ error: 'Invalid category_id format (must be a UUID).' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }
        if (search_term && typeof search_term !== 'string') {
            return new Response(JSON.stringify({ error: 'Search term must be a string if provided.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }

        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            {
                global: {
                    headers: { Authorization: req.headers.get('Authorization')! },
                },
            }
        );

        // Check user role for authorization
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
            return new Response(JSON.stringify({ error: 'Unauthorized: User not found.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 401,
            });
        }

        const { data: roleData, error: roleError } = await supabase.rpc('get_user_role');
        if (roleError) {
            console.error('Error getting user role:', roleError);
            return new Response(JSON.stringify({ error: 'Error getting user role.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            });
        }

        const userRole = roleData;
        if (!['admin', 'manager', 'staff', 'analyst'].includes(userRole)) {
            return new Response(JSON.stringify({ error: 'Forbidden: Insufficient permissions.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 403,
            });
        }

        let query = supabase
            .from('products')
            .select('*, product_images(id, image_url, is_thumbnail)', { count: 'exact' });

        if (category_id) {
            query = query.eq('category_id', category_id);
        }
        if (is_active !== undefined) {
            query = query.eq('is_active', is_active);
        }
        if (search_term) {
            query = query.or(`name.ilike.%${search_term}%,description.ilike.%${search_term}%,sku.ilike.%${search_term}%,brand.ilike.%${search_term}%`);
        }

        query = query.range(offset, offset + limit - 1);

        const { data, error, count } = await query;

        if (error) {
            console.error('Error listing products:', error);
            return new Response(JSON.stringify({ error: error.message }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            });
        }

        return new Response(JSON.stringify({ products: data, total_count: count }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });
    } catch (error) {
        console.error('Unhandled error:', error);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
