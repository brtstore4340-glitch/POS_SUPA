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
        const { id } = await req.json();

        // Validate input
        if (!id || typeof id !== 'string' || !isUUID(id)) {
            return new Response(JSON.stringify({ error: 'Valid category ID (UUID) is required.' }), {
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
        if (userRole !== 'admin') {
            return new Response(JSON.stringify({ error: 'Forbidden: Insufficient permissions. Only admins can delete categories.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 403,
            });
        }

        const { error, count } = await supabase
            .from('categories')
            .delete()
            .eq('id', id)
            .select(); // Use select() to get data, count is a property if it was a stored procedure

        if (error) {
            console.error('Error deleting category:', error);
            return new Response(JSON.stringify({ error: error.message }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            });
        }

        if (count === 0) {
            return new Response(JSON.stringify({ error: 'Category not found or already deleted.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 404,
            });
        }

        return new Response(JSON.stringify({ message: 'Category deleted successfully.' }), {
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
