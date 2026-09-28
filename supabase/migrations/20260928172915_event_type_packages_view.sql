-- 20260928172915_event_type_packages_view.sql
--
-- The currently effective package for each event type.
--
-- Same fan-out as talent_offered_event_types, for the same reason: the frontend
-- holds an event type, packages are keyed by rate category, and the frontend
-- must never carry the event-type-to-rate-category mapping. A copy of
-- rate_category_for_event_type in TypeScript is a second truth free to drift -
-- which is exactly how the quote form ended up offering 'other' after the enum
-- dropped it, and missing club_pub and spot_performance after the enum gained
-- them.
--
-- Shown beside the time pickers so a client choosing a window shorter than the
-- package does so knowingly. Settled 2026-09-28: the shorter window is their
-- informed choice and the talent's gain, and nothing validates one against the
-- other.
--
-- Carries no rate. Packages are what the platform advertises, so this is
-- readable by anyone.
--
-- Verified after applying: all 9 event types resolve to a package.

begin;

create view public.event_type_packages as
select e.event_type,
       p.label,
       p.min_minutes,
       p.max_minutes
  from (select v::public.events_type as event_type
          from unnest(enum_range(null::public.events_type)) v) e
  join public.packages p
    on p.id = public.package_for_category(
                public.rate_category_for_event_type(e.event_type), now());

revoke all on public.event_type_packages from public, anon, authenticated;
grant select on public.event_type_packages to anon, authenticated;

comment on view public.event_type_packages is
  'The currently effective package for each event type. Exists so the frontend never carries the event-type-to-rate-category mapping. Carries no rate: packages are what the platform advertises.';

commit;