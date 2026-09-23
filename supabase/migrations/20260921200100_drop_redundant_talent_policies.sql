-- 20260921200100_drop_redundant_talent_policies.sql
--
-- Removes two policies on profiles_talent that grant nothing talent_profile_manage_own
-- does not already grant.
--
-- READ LIVE 2026-09-21
-- --------------------
--   talent_profile_manage_own  ALL     authenticated  USING (auth.uid() = user_id)
--                                                     WITH CHECK (auth.uid() = user_id)
--   talent_profile_read_own    SELECT  authenticated  USING (auth.uid() = user_id)
--   talent_update_own          UPDATE  authenticated  USING (auth.uid() = user_id)
--                                                     WITH CHECK (auth.uid() = user_id)
--
-- The predicates are IDENTICAL, and ALL covers SELECT and UPDATE. Policies combine
-- with OR, so a strictly-covered policy can never widen or narrow access. Dropping
-- these two changes nothing a talent can do.
--
-- WHY BOTHER
-- ----------
-- Three overlapping policies on one table make an audit read as more restrictive than
-- it is: a reviewer seeing talent_profile_read_own as SELECT-only may not notice the
-- ALL policy beside it. The same misreading is what let talent_select_public sit
-- unnoticed without an approval check until 2026-09-21 (D-023 / 6hX95jpJQ8pQG8r5).
-- Fewer policies, each doing one job.
--
-- NOT TOUCHED
--   talent_select_public      - public reads, now requires approval (20260921100200)
--   talent_profile_manage_own - the one that actually grants a talent access
--   service_role_full_access  - server-side access
--
-- AFTER THIS, profiles_talent should have exactly three policies. Verify with:
--   select policyname, cmd, roles from pg_policies
--    where tablename = 'profiles_talent';

BEGIN;

DROP POLICY IF EXISTS talent_profile_read_own ON public.profiles_talent;
DROP POLICY IF EXISTS talent_update_own       ON public.profiles_talent;

COMMIT;
