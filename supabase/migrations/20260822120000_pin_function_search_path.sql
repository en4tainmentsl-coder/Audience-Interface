-- Applied via Supabase SQL Editor 2026-08-22. Recorded here for version control.
-- Clears 13 function_search_path_mutable advisor lints (21 lints -> 8).

ALTER FUNCTION public.is_18_or_over(dob date)              SET search_path TO 'public';
ALTER FUNCTION public.get_my_role()                        SET search_path TO 'public';
ALTER FUNCTION public.check_talent_age()                   SET search_path TO 'public';
ALTER FUNCTION public.check_client_age()                   SET search_path TO 'public';
ALTER FUNCTION public.check_talent_dob_before_submission() SET search_path TO 'public';
ALTER FUNCTION public.check_client_dob_before_submission() SET search_path TO 'public';
ALTER FUNCTION public.check_client_approvals_venue_only()  SET search_path TO 'public';
ALTER FUNCTION public.enforce_featured_requires_admin()    SET search_path TO 'public';
ALTER FUNCTION public.handle_talent_approval()             SET search_path TO 'public';

-- These two call hmac() unqualified; pgcrypto lives in the extensions schema,
-- so pinning to 'public' alone would break both triggers at runtime.
ALTER FUNCTION public.notify_talent_approved()             SET search_path TO 'public', 'extensions';
ALTER FUNCTION public.notify_profile_approved()            SET search_path TO 'public', 'extensions';

-- Drop NocoBase leftovers. Both owned by nocobase_admin, both anon-executable.
-- show_create_table: schema introspection helper, no trigger, pure attack surface.
-- handle_null_id: verified no-op. profiles_talent.id is uuid DEFAULT gen_random_uuid(),
-- so pg_get_serial_sequence returns null and it returned NEW unchanged after three
-- catalog lookups on every talent insert.
GRANT nocobase_admin TO postgres;
DROP TRIGGER IF EXISTS set_default_id ON public.profiles_talent;
DROP FUNCTION IF EXISTS public.handle_null_id();
DROP FUNCTION IF EXISTS public.show_create_table(text, text);
REVOKE nocobase_admin FROM postgres;
