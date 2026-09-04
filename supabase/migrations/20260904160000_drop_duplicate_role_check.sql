-- profiles_users carried two byte-identical CHECK constraints on `role`:
--   chk_users_role
--   profiles_users_role_valid
--
-- Both: CHECK (role = ANY (ARRAY['talent','client','venue','admin']))
--
-- Keep chk_users_role — it matches the naming of its sibling chk_users_status
-- on the same table. Drop the duplicate.
--
-- No functional change. The duplicate cost a redundant check on every write.
-- Verified 2026-09-04: no application code references either name; the only
-- occurrences are in the baseline migration, which is historical record.

ALTER TABLE public.profiles_users
  DROP CONSTRAINT IF EXISTS profiles_users_role_valid;
