-- Contract phase. profiles_talent carries a public SELECT policy covering the
-- anon role, and RLS filters rows, not columns — so email and mobile on that
-- row were readable by any visitor with the publishable key for every approved
-- talent. They now live on talent_contact, which anon has no grant on at all.
--
-- Everything that read these columns has already moved:
--   review_talent, request_profile_deletion   20261017015606
--   Talent_Interface ProfileEditor.tsx        merged 2026-10-17
--   Audience-Interface VenueDashboard.tsx     merged 2026-10-17
--
-- Backfill verified before this ran: 2 rows in, 2 rows out, zero mismatches.

alter table public.profiles_talent
  drop column email,
  drop column mobile;
