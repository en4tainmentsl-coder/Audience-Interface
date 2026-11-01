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

drop index if exists public.talent_favourites_visitor_talent_unique;

alter table public.talent_favourites
  drop column if exists visitor_id;
