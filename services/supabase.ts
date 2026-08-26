import { createClient, SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../database.types';

const supabaseUrl: string | undefined = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey: string | undefined = import.meta.env.VITE_SUPABASE_ANON_KEY;

// Only initialize if credentials are provided to prevent crash on startup
export const supabase: SupabaseClient<Database> = (supabaseUrl && supabaseAnonKey)
  ? createClient<Database>(supabaseUrl, supabaseAnonKey)
  : new Proxy({}, {
      get: () => {
        return () => {
          throw new Error("Supabase URL and Anon Key are required. Please configure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in your environment variables.");
        };
      }
    }) as unknown as SupabaseClient<Database>;
