-- 20260928181029_fix_talent_offered_event_types_inline_range.sql
--
-- Fixes a permission error in the view as defined by 20260928181002.
--
-- THE BUG
-- -------
-- That version computed the range by calling price_range_for_amount, on the
-- assumption that a view runs everything with its owner's privileges.
--
-- That is only true for TABLE permissions. Function EXECUTE is checked against
-- the CALLING role, even inside a view. price_range_for_amount is revoked from
-- anon and authenticated, so every anonymous read of the view failed:
--
--   permission denied for function price_range_for_amount
--
-- It applied cleanly and passed every check that did not read the view as anon.
-- Caught by a SET ROLE anon test; without it this would have merged and failed
-- only in a browser, on the artists listing.
--
-- WHY NOT JUST GRANT EXECUTE
-- --------------------------
-- Granting anon EXECUTE on price_range_for_amount would fix the error and hand
-- out a boundary-probing oracle: call it repeatedly and binary-search the range
-- edges. That is precisely what keeping price_ranges unreadable prevents, and it
-- would make D-039's three-checks limit pointless.
--
-- The lookup is inlined as a correlated subquery instead. No function call
-- happens, so no EXECUTE is needed, and the boundaries stay unreachable.
--
-- VERIFIED as anon: 5 rows readable, wedding at 250,000 resolving to Range 6 and
-- the 5,000/6,000 rates to Range 1, and price_ranges itself still unreadable.

begin;

create or replace view public.talent_offered_event_types as
select distinct
       tr.talent_id,
       e.event_type,
       (select r.ordinal
          from public.price_ranges r
          join public.price_range_sets s on s.id = r.set_id
         where s.effective_from <= now()
           and s.effective_from = (select max(s2.effective_from)
                                     from public.price_range_sets s2
                                    where s2.effective_from <= now())
           and r.min_amount <= tr.amount
         order by r.min_amount desc
         limit 1) as price_range_ordinal
  from public.talent_rates tr
  join public.profiles_talent pt on pt.id = tr.talent_id
 cross join lateral (
       select v::public.events_type as event_type
         from unnest(enum_range(null::public.events_type)) v
 ) e
 where tr.amount is not null
   and pt.is_public = true
   and public.rate_category_for_event_type(e.event_type) = tr.category;

comment on view public.talent_offered_event_types is
  'Which event types each PUBLIC talent takes bookings for, and the price range ordinal for each. Exposes no amount and no range boundaries - D-046 holds. The range lookup is inlined rather than calling price_range_for_amount, because function EXECUTE is checked against the calling role even inside a view, and granting anon that function would hand out a boundary-probing oracle. Never add an amount column here.';

commit;