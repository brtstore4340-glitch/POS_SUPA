
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  // This error will now correctly point to the Vercel environment variables.
  throw new Error("Supabase URL and Anon Key are required. Please ensure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set in your Vercel project environment.");
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
