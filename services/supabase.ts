import { createClient } from '@supabase/supabase-js';
import { Database } from '../types';

const supabaseUrl = (import.meta as any).env.VITE_SUPABASE_URL;
const supabaseAnonKey = (import.meta as any).env.VITE_SUPABASE_ANON_KEY;

// Only initialize if credentials are provided to prevent crash on startup
export const supabase = (supabaseUrl && supabaseAnonKey)
  ? createClient<Database>(supabaseUrl, supabaseAnonKey)
  : new Proxy({} as any, {
      get: () => {
        // This will throw a descriptive error only when the client is actually used
        return () => {
          throw new Error("Supabase URL and Anon Key are required. Please configure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in your environment variables.");
        };
      }
    });
