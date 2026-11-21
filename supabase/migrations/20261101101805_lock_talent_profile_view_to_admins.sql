-- Lock talent_profile_view reads to admins only.
-- Task 6hpJg4VHwqpfCF7X. Settled by Praveen 2026-10-19:
--   "don't let talent see this. allow only admins to see it."
--
-- profile_view_read_own granted SELECT to authenticated where the viewed talent
-- belonged to the caller, so a talent could read viewer_user_id for every client
-- who opened their profile. That is the client's personal data, handed to a third
-- party with no disclosure anywhere in the client-facing documents.
--
-- Verified live 2026-11-01:
--   * nothing in either repo reads talent_profile_view outside generated types,
--     so this breaks no visible feature;
--   * there is no INSERT policy for authenticated -- service_role_full_access is
--     the only writer -- so view logging is unaffected;
--   * RLS is enabled and forced on the table.
--
-- Uses get_my_role(), matching sensitive_asset_access_log and
-- talent_profile_sync_logs, rather than the older inline EXISTS form.

drop policy if exists profile_view_read_own on public.talent_profile_view;

create policy profile_view_admin_select
  on public.talent_profile_view
  for select
  to authenticated
  using (public.get_my_role() = 'admin'::text);
