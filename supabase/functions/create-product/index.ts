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
        const { name, description, price, category_id, sku, brand, cost_price, is_active, barcode } = await req.json();

        // Validate input
        if (!name || typeof name !== 'string' || name.trim() === '') {
            return new Response(JSON.stringify({ error: 'Product name is required and must be a non-empty string.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }
        if (typeof price !== 'number' || price < 0) {
            return new Response(JSON.stringify({ error: 'Product price is required and must be a non-negative number.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }
        if (description && typeof description !== 'string') {
            return new Response(JSON.stringify({ error: 'Product description must be a string if provided.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }
        if (category_id && (!isUUID(category_id))) {
            return new Response(JSON.stringify({ error: 'Invalid category_id format (must be a UUID).' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            });
        }
        if (sku && typeof sku !== 'string') {
             return new Response(JSON.stringify({ error: 'SKU must be a string.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
        }
        if (brand && typeof brand !== 'string') {
             return new Response(JSON.stringify({ error: 'Brand must be a string.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
        }
        if (cost_price && (typeof cost_price !== 'number' || cost_price < 0)) {
             return new Response(JSON.stringify({ error: 'Cost price must be a non-negative number.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
        }
        if (barcode && (!Array.isArray(barcode) || !barcode.every(b => typeof b === 'string'))) {
             return new Response(JSON.stringify({ error: 'Barcode must be an array of strings.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
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
        if (!['admin', 'manager'].includes(userRole)) {
            return new Response(JSON.stringify({ error: 'Forbidden: Insufficient permissions.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 403,
            });
        }

        const { data: productData, error: productError } = await supabase
            .from('products')
            .insert([
                {
                    name,
                    description,
                    price,
                    category_id,
                    sku,
                    brand,
                    cost_price,
                    is_active: is_active ?? true,
                    barcode
                }
            ])
            .select()
            .single();

        if (productError) {
            console.error('Error creating product:', productError);
            return new Response(JSON.stringify({ error: productError.message }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            });
        }

        return new Response(JSON.stringify(productData), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 201,
        });
    } catch (error) {
        console.error('Unhandled error:', error);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
