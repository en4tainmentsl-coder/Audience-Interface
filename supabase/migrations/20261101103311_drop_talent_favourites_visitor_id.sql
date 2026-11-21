-- Drop the dead visitor_id column from talent_favourites.
-- Task 6hpcFGMQRVRH6jHX.
--
-- visitor_id is residue from the anonymous-heart era. Anonymous hearting was
-- removed by decision on 2026-10-04 and its INSERT policy dropped with it; the
-- column was left behind.
--
-- Verified live 2026-11-01: 0 rows in the table; no policy, constraint, function
-- or view references visitor_id. The ONLY remaining reference is the partial
-- unique index talent_favourites_visitor_talent_unique, dropped explicitly below.
--
-- DECIDED by Praveen 2026-11-01: notes stay NON-EDITABLE. No owner-scoped UPDATE
-- policy is added here. A client who wants to change a note deletes the favourite
-- and re-adds it, accepting that created_at resets. Do not read the absence of an
-- UPDATE policy on this table as an oversight -- it is the decision.

do $$
begin
  if exists (select 1 from public.talent_favourites where visitor_id is not null) then
    raise exception
      'talent_favourites still holds rows with a non-null visitor_id. Resolve those before dropping the column.'
      using errcode = '23514';
  end if;
end $$;

-- The baseline's anon INSERT policy fav_anon_insert depends on visitor_id.
-- It was removed from the live database on 2026-10-04 when anonymous hearting
-- was dropped by decision, but that removal was never written as a migration,
-- so replaying this history recreates it and the column drop below fails.
-- Caught by CI 2026-11-01. No-op against live, where the policy is absent.
-- Wider repo/live policy drift is tracked separately.
drop policy if exists fav_anon_insert on public.talent_favourites;

drop index if exists public.talent_favourites_visitor_talent_unique;

alter table public.talent_favourites
  drop column if exists visitor_id;
