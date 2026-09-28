-- 20260928093038_talent_offered_event_types_view.sql
--
-- Which event types a public talent takes bookings for. NO AMOUNTS.
--
-- WHY THIS HAS TO EXIST
-- ---------------------
-- The client-facing picker must exclude talent who have no rate for the chosen
-- event type. The backstop in set_talent_rate_at_request - "This performer is
-- not available for wedding bookings" - is meant to catch a hand-crafted insert
-- through PostgREST, not to be the path a real client walks.
--
-- But talent_rates grants nothing to anon or authenticated beyond a talent's own
-- rows (D-046), so the frontend has no way to know who offers weddings. Without
-- a deliberate disclosure the picker cannot be built at all.
--
-- WHAT IT DISCLOSES, AND WHAT IT MUST NOT
-- ---------------------------------------
-- THAT a performer takes wedding bookings. Never WHAT they charge. That is
-- something the platform advertises anyway, and a client needs it to browse.
--
-- A plain view runs with the OWNER's privileges, so this reads talent_rates past
-- RLS. That is the point - and it is also why the view must expose exactly two
-- columns and filter is_public itself, because nothing else is filtering for it.
-- NEVER add an amount column here.
--
-- EXPOSES EVENT TYPES, NOT RATE CATEGORIES
-- ----------------------------------------
-- So the frontend never needs the mapping. A talent with a single
-- special_events rate correctly appears under corporate, birthday AND private.
-- Verified: three rates (special_events, wedding, club_pub) produce five offered
-- event types.
--
-- The artist profile page shows this list too, so a client sees what a performer
-- takes before clicking through - preventing the mismatch rather than
-- explaining it afterwards.

begin;

create view public.talent_offered_event_types as
select distinct
       tr.talent_id,
       e.event_type
  from public.talent_rates tr
  join public.profiles_talent pt on pt.id = tr.talent_id
 cross join lateral (
       select v::public.events_type as event_type
         from unnest(enum_range(null::public.events_type)) v
 ) e
 where tr.amount is not null
   and pt.is_public = true
   and public.rate_category_for_event_type(e.event_type) = tr.category;

revoke all on public.talent_offered_event_types from public, anon, authenticated;
grant select on public.talent_offered_event_types to anon, authenticated;

comment on view public.talent_offered_event_types is
  'Which event types each PUBLIC talent takes bookings for. Deliberately exposes no amount - D-046 holds. Runs with owner privileges so it reads talent_rates past RLS, which is why it exposes exactly two columns and filters is_public itself. Never add a rate column here.';

commit;