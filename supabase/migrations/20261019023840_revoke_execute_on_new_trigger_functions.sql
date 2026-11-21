-- Revoke EXECUTE on every trigger function in public from PUBLIC, anon and authenticated.
--
-- Why this exists a second time:
--   20261014032743_replay_revoke_execute_on_trigger_functions.sql applies the same rule,
--   but a migration only runs at its own timestamp position. Trigger functions created by
--   LATER migrations come up carrying the default PUBLIC EXECUTE grant that CREATE FUNCTION
--   hands out. That migration documented the limitation; this is the limitation arriving.
--
--   2026-10-18: set_request_matched_on_quote (20261018115132) and set_request_responds_by
--   (20261018125114) are SECURITY DEFINER trigger functions and were callable over REST at
--   /rest/v1/rpc/<name> by both anon and authenticated.
--
-- Safe: EXECUTE is checked when a trigger is CREATED, not when it fires. Revoking does not
-- disable or break any attached trigger.
--
-- Idempotent: revoking an absent grant is a no-op.

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prorettype = 'trigger'::regtype
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      r.sig
    );
  END LOOP;
END
$$;

-- Post-condition. Fails the migration rather than leaving a rebuilt database quietly wrong.
-- NULL proacl is treated as exposed: it means default privileges, which include PUBLIC.
-- The acl test unnests and looks for an element beginning with '=' (empty grantee) rather
-- than pattern-matching the formatted string, which also matches 'postgres=X/postgres'.
DO $$
DECLARE
  n_exposed int;
BEGIN
  SELECT count(*) INTO n_exposed
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prorettype = 'trigger'::regtype
    AND (
      p.proacl IS NULL
      OR EXISTS (
        SELECT 1 FROM unnest(p.proacl::text[]) a
        WHERE a LIKE '=%' OR split_part(a, '=', 1) IN ('anon', 'authenticated')
      )
    );

  IF n_exposed > 0 THEN
    RAISE EXCEPTION
      'REVOKE incomplete: % trigger function(s) in public still executable by PUBLIC, anon or authenticated',
      n_exposed;
  END IF;
END
$$;