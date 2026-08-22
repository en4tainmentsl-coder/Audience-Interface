-- Applied via Supabase SQL Editor 2026-08-22. Recorded here for version control.
-- Clears 4 of 8 remaining advisor lints (anon/authenticated SECURITY DEFINER executable).

-- Both are trigger functions: no arguments, return `trigger`. Calling them over
-- /rest/v1/rpc/ achieves nothing, but they were publicly executable. Verified no
-- callers in either frontend repo and no RLS policy references.
--
-- NOTE: revoking from anon/authenticated alone had NO effect. Postgres grants
-- EXECUTE to PUBLIC on every function by default (ACL entry `=X/postgres`), and
-- both roles inherited through it. PUBLIC must be revoked first.

REVOKE EXECUTE ON FUNCTION public.enforce_featured_requires_admin() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_talent_approval()          FROM PUBLIC, anon, authenticated;

-- get_my_role() deliberately NOT revoked: 7 RLS policies call it. Removing
-- EXECUTE from authenticated would break all seven, and the symptom would be
-- rows silently disappearing rather than a permission error.
