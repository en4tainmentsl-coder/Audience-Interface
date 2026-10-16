-- Replay of the 2026-10-06 hardening, which was applied via execute_sql and
-- never recorded in the migration ledger. Idempotent against production:
-- revoking an absent grant is a no-op. Exists so a rebuild from migrations
-- (staging / DR restore) does not come up with trigger functions executable
-- by PUBLIC, anon and authenticated.
--
-- Covers SECURITY INVOKER trigger functions too, which the Supabase advisor
-- does not report.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prorettype = 'pg_catalog.trigger'::regtype
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
  END LOOP;
END $$;
