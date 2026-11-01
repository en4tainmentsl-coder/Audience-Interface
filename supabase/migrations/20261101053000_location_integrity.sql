-- Stage 2C-3a: make a computable distance structurally guaranteed.
--
-- calc_travel_fee needs coordinates at BOTH ends. Either end missing and
-- distance is NULL and travel falls back to a percentage of the fee. Both
-- apps already prevent that -- the talent form requires a town and a trigger
-- derives the coordinates, and the client form always writes a district
-- centroid as a floor. Neither rule was enforced in the database, so any
-- write bypassing the forms could still produce an unpriceable booking.
--
-- With both constraints below, distance is computable for every quote. The
-- percentage fallback in calc_travel_fee becomes unreachable in practice --
-- it is left in place as a backstop rather than removed.

-- ---------------------------------------------------------------------
-- 1. Test fixture repair.
--
-- profiles_talent "Test Talent" (02bee6de) has no base_town_id, so the
-- derivation trigger never populated its coordinates. It is a live test
-- account -- a real auth user with 7 talent_rates rows, no quote requests,
-- quotes or bookings -- so it is repaired rather than deleted.
--
-- Colombo is chosen arbitrarily as a central, unremarkable location. It is
-- fixture data, not a claim about anyone's whereabouts.
-- ---------------------------------------------------------------------

update public.profiles_talent
   set base_town_id = 1248991            -- Colombo, Colombo district
 where id = '02bee6de-7c54-4903-a56f-9d24b747930f'
   and base_town_id is null;

-- The trigger fires on UPDATE OF base_town_id and fills the coordinates.
-- Verify rather than assume -- a NOT NULL added over a row the trigger
-- missed would fail the migration here rather than in production.
do $$
begin
  if exists (
    select 1 from public.profiles_talent
     where base_town_id is null or base_latitude is null or base_longitude is null
  ) then
    raise exception
      'A talent profile still lacks a base town or derived coordinates. Fix the data before adding the constraint.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Every talent must have a base town.
--
-- The coordinates themselves stay nullable: they are derived, and making
-- them NOT NULL would assert the trigger's behaviour in two places.
-- base_town_id is the real input, so that is what is required.
-- ---------------------------------------------------------------------

alter table public.profiles_talent
  alter column base_town_id set not null;

comment on column public.profiles_talent.base_town_id is
  'The talent''s base town. REQUIRED -- base_latitude/base_longitude are derived from it by set_talent_base_coordinates, and travel pricing needs a computable distance. Chosen through the town picker; never free text.';

-- ---------------------------------------------------------------------
-- 3. Every quote request must carry coordinates.
--
-- The old constraint accepted venue_id ALONE. Venue coordinates are
-- nullable, so a request naming a coordinate-less venue satisfied the
-- check while leaving distance uncomputable -- the exact case the client
-- code comments warn about. Coordinates are now required unconditionally;
-- a venue's own coordinates remain a precision upgrade over the district
-- centroid, not a substitute for having any.
-- ---------------------------------------------------------------------

alter table public.quote_requests
  drop constraint quote_requests_has_location;

alter table public.quote_requests
  add constraint quote_requests_has_location
  check (event_latitude is not null and event_longitude is not null);

comment on constraint quote_requests_has_location on public.quote_requests is
  'Coordinates are mandatory. A district centroid is an acceptable floor; venue coordinates override it when present. venue_id alone is NOT sufficient -- venue coordinates are nullable.';
