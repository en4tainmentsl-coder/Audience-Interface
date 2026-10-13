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

// PKCE, not the default implicit flow. This app uses hash routing
// (/#/request-quote?...), and the implicit flow returns the session as a
// URL fragment (#access_token=...). A URL has only one fragment, so the
// token landed behind the route hash and was never read — sign-in appeared
// to silently fail and each retry stacked another #access_token on the URL.
// PKCE returns ?code= as a query parameter, which coexists with hash routes.
export const supabase: SupabaseClient<Database> = createClient<Database>(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      flowType: 'pkce',
      detectSessionInUrl: true,
      persistSession: true,
      autoRefreshToken: true,
    },
  }
);