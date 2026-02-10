// supabase/functions/calculate-order/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { items, adjustments } = await req.json()
    
    // In a real app, we would fetch fresh prices from DB here to ensure validity.
    // For this phase, we accept the passed prices but validate structure.

    let subtotal = 0;
    let totalItems = 0;

    const calculatedItems = items.map((item: any) => {
        const lineTotal = (item.price || 0) * (item.qty || 1);
        subtotal += lineTotal;
        totalItems += (item.qty || 1);
        return { ...item, calculatedTotal: lineTotal };
    });

    // Apply bill discount (e.g. 10%)
    const billDiscountPercent = adjustments?.billDiscount?.percent || 0;
    const billDiscountAmount = subtotal * (billDiscountPercent / 100);

    // Apply coupon (fixed amount)
    const couponTotal = (adjustments?.coupons || []).reduce((acc: number, c: any) => acc + (c.couponValue || 0), 0);

    // Apply allowance
    const allowance = adjustments?.allowance || 0;

    const totalDiscount = billDiscountAmount + couponTotal + allowance;
    const grandTotal = Math.max(0, subtotal - totalDiscount);

    const summary = {
        subtotal,
        totalItems,
        billDiscountAmount: -billDiscountAmount,
        couponTotal: -couponTotal,
        allowance: -allowance,
        totalDiscount: -totalDiscount,
        grandTotal,
        netTotal: grandTotal // Same for now
    };

    return new Response(JSON.stringify({ items: calculatedItems, summary }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
