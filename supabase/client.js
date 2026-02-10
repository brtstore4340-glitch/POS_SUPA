
import { createClient } from '@supabase/supabase-js';

// Use process.env which is now defined by vite.config.js
const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("Supabase URL and Anon Key are required. Check Vercel environment variables and vite.config.js.");
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
