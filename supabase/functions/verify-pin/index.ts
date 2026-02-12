import { serve } from "npm:@supabase/functions-js";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "../_shared/cors.ts";

// Note: Deno bcrypt library for secure PIN hashing.
// You might need to adjust the import based on the latest version.
import bcrypt from "npm:bcryptjs";

console.log("Edge Function 'verify-pin' is up and running!");

serve(async (req) => {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { accountId, pin } = await req.json();
    if (!accountId || !pin) {
      throw new Error("accountId and pin are required.");
    }

    // Create a Supabase client with the SERVICE_ROLE_KEY to bypass RLS.
    // Ensure you have set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your function's environment variables.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Fetch the account details from the database.
    const { data: account, error: dbError } = await supabaseAdmin
      .from("account")
      .select("pinhash, pinsalt")
      .eq("account_id", accountId)
      .single();

    if (dbError) throw dbError;

    if (!account) {
      return new Response(JSON.stringify({ isValid: false, message: "Account not found." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404,
      });
    }

    // Securely verify the provided PIN against the stored hash.
    const isPinValid = await bcrypt.compare(pin, account.pinhash);

    if (!isPinValid) {
       return new Response(JSON.stringify({ isValid: false, message: "Invalid PIN." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    // If the PIN is valid, return a success response.
    return new Response(JSON.stringify({ isValid: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
