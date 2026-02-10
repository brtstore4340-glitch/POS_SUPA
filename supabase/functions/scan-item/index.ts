// supabase/functions/scan-item/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const { barcode } = await req.json()
    if (!barcode) throw new Error('Barcode is required')

    // First try exact SKU match
    let { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('is_active', true)
      .eq('sku', barcode)
      .single()

    // If not found, try finding in barcode array
    if (!data) {
       const result = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .contains('barcode', [barcode])
        .limit(1)
        .single()
        
       if (result.data) data = result.data;
    }

    if (!data) {
        return new Response(JSON.stringify(null), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
