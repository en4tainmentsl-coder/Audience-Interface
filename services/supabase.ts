import { createClient, SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../database.types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// Fail at module load, not at first use. A deploy with missing env vars must
// refuse to start rather than render an app whose every data call throws
// inside a caller's catch block and shows an empty page instead.
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing Supabase configuration. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY ' +
    'in the environment (Cloudflare Pages > Settings > Environment variables, or .env for local dev).'
  );
}

export const supabase: SupabaseClient<Database> = createClient<Database>(
  supabaseUrl,
  supabaseAnonKey
);