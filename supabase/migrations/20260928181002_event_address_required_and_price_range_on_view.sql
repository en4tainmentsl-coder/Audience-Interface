-- 20260928181002_event_address_required_and_price_range_on_view.sql
--
-- NOTE: the view definition here is SUPERSEDED by 20260928181029, which fixes a
-- permission error this version shipped with. Both files exist because both
-- versions are in the ledger. Read the later one for the working definition.
--
-- 1. event_address required for non-venue bookings. The form collects it as of
--    #142, deployed before this ran - with the constraint first, every quote
--    request from the live form would have failed. A venue booking is exempt:
--    the venue record carries its own address, and a second copy invites
--    disagreement. btrim rejects a whitespace-only value, which is how a
--    required field otherwise gets bypassed.
--
-- 2. price_range_ordinal on talent_offered_event_types, so the artists listing
--    can show the fee category once the client applies the event-type filter.
--    One view serves both pages rather than a second view drifting from this.
--
--    The ORDINAL only - never the amount, never the boundaries. "Range 6" places
--    a talent between two numbers the client cannot see, because price_ranges is
--    readable by no browser role. D-046 holds.

begin;

alter table public.quote_requests
  add constraint quote_requests_address_for_non_venue
  check (venue_id is not null
         or (event_address is not null and btrim(event_address) <> ''));

create or replace view public.talent_offered_event_types as
select distinct
       tr.talent_id,
       e.event_type,
       r.ordinal as price_range_ordinal
  from public.talent_rates tr
  join public.profiles_talent pt on pt.id = tr.talent_id
 cross join lateral (
       select v::public.events_type as event_type
         from unnest(enum_range(null::public.events_type)) v
 ) e
  left join public.price_ranges r
    on r.id = public.price_range_for_amount(tr.amount)
 where tr.amount is not null
   and pt.is_public = true
   and public.rate_category_for_event_type(e.event_type) = tr.category;

commit;