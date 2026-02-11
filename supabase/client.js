
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabaseConfigError = (!supabaseUrl || !supabaseAnonKey)
  ? "Supabase URL and Anon Key are required. Please ensure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set in your Vercel project environment."
  : null;

export const isSupabaseConfigured = !supabaseConfigError;

const missingSupabaseProxy = new Proxy(
  {},
  {
    get(_target, prop) {
      if (prop === 'then') return undefined;
      throw new Error(supabaseConfigError || "Supabase is not configured.");
    }
  }
);

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey)
  : missingSupabaseProxy;
