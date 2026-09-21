-- 20260921100200_talent_visibility_requires_approval.sql
--
-- A talent profile is publicly readable only if it is public AND approved.
--
-- BEFORE
--   talent_select_public  FOR SELECT TO public  USING (is_public = true)
--
-- The policy never checked approval. Verified live 2026-09-21: 1 of 3 talent rows was
-- is_public = true with approval_status = 'pending_approval' (the hand-made
-- "Test Talent" fixture), and so was readable by anon over PostgREST despite never
-- having been approved. Approval was enforced only by frontend query filters.
--
-- The trust guard (enforce_talent_trust_fields, D-023 / D-030) already stops a
-- talent setting is_public themselves, so this was not self-exploitable. But
-- "approved" is what should make a profile visible, and the database should say so
-- rather than relying on every query to remember.
--
-- DECIDED 2026-09-21 (Praveen). Safe alongside the decision that editing an approved
-- profile sends the edit to review while the last approved version stays live: an
-- approved talent stays approved during review, so this rule never drops them out of
-- listings on edit.
--
-- EFFECT ON EXISTING DATA
-- Test Talent disappears from Artists and Home until it is completed and approved
-- (decided 2026-09-21: complete it first, then approve). With no real users this is
-- expected; the listing pages will show no talent in the meantime.
--
-- NOT CHANGED: talent_profile_read_own - a talent still reads their own row in any
-- state.
--
-- DIRECTUS IS UNAFFECTED - verified, not assumed. This policy is granted TO public,
-- which covers every role. Directus connects as nocobase_admin (D-016/D-017), which
-- has rolbypassrls = true (checked 2026-09-21), so it still sees unapproved profiles
-- and can approve them. If that role ever loses BYPASSRLS, this policy would hide
-- every pending profile from the admin tool that reviews them.

BEGIN;

DROP POLICY talent_select_public ON public.profiles_talent;

CREATE POLICY talent_select_public ON public.profiles_talent
  FOR SELECT TO public
  USING (is_public = true AND approval_status = 'approved'::approval_status);

COMMIT;
