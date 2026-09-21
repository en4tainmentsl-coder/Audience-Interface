-- 20260921100000_towns_reference.sql
--
-- Town reference table for talent base location, and derived base coordinates.
--
-- WHY
-- ---
-- D-005 charges travel on the distance between the talent's base and the venue:
-- nothing under 10 km, the full distance at 10 km or more, and 7.5% of the talent fee
-- when the base has no coordinates. Nothing has ever captured base coordinates -
-- 0 of 3 talent rows have them - so every quote has fallen back to the 7.5% estimate
-- (Todoist 6hX929667RvXHPm5).
--
-- DECIDED 2026-09-21 (Praveen): the talent picks their town from an autocomplete in
-- ProfileEditor; the base coordinates are that town's centre. Chosen over a map pin
-- (stores a home location) and geocoding free text (third-party service, silent wrong
-- matches). Coordinates are required before a profile can be submitted for review.
--
-- WHAT THIS DOES
-- --------------
-- 1. public.towns - read-only reference data, loaded by 20260921100100.
-- 2. profiles_talent.base_town_id - the talent's chosen town.
-- 3. A trigger that DERIVES base_latitude / base_longitude from base_town_id and
--    overwrites any value the client sends.
--
-- Point 3 matters: travel is charged on distance, so client-written coordinates would
-- let a talent place their base far from every venue and inflate every travel charge.
-- Coordinates become a derived value, not a trust field. With no town, they are NULL,
-- which keeps D-005's 7.5% fallback behaviour for incomplete profiles.
--
-- NOT DONE HERE
-- -------------
-- * Pinning base_town_id once a profile is approved. Per the 2026-09-21 decision,
--   edits to an approved profile go to review while the last approved version stays
--   live; that is its own build.
-- * Existing primary_location text is not migrated. The one real value
--   ('athurugiriya') belongs to a talent who will choose a town in the form.
-- * Venue coordinates (6hMv5Jc6jm5M4w85) - a separate decision.

BEGIN;

-- 1. Reference table ---------------------------------------------------------------

CREATE TABLE public.towns (
  id          bigint       PRIMARY KEY,          -- GeoNames geonameid
  name        text         NOT NULL,
  district    text         NOT NULL,
  ds_division text,
  label       text         NOT NULL,             -- what the autocomplete displays
  latitude    numeric(9,6) NOT NULL,
  longitude   numeric(9,6) NOT NULL,
  rank        smallint     NOT NULL DEFAULT 0,   -- higher shows first
  CONSTRAINT towns_latitude_in_sri_lanka  CHECK (latitude  BETWEEN 5.5 AND 10.0),
  CONSTRAINT towns_longitude_in_sri_lanka CHECK (longitude BETWEEN 79.4 AND 82.0)
);

COMMENT ON TABLE public.towns IS
  'Sri Lankan towns for talent base location. Source: GeoNames (CC BY 4.0) - attribution required in the app. See migration 20260921100100 for cleaning.';

-- Read-only to everyone; nobody but service_role writes.
ALTER TABLE public.towns ENABLE ROW LEVEL SECURITY;

CREATE POLICY towns_read_all ON public.towns
  FOR SELECT TO anon, authenticated
  USING (true);

-- Explicit grants rather than relying on schema defaults (see 6hQXJ76vCMVMG79X).
REVOKE ALL ON public.towns FROM anon, authenticated;
GRANT SELECT ON public.towns TO anon, authenticated;

-- 2. Talent's chosen town -----------------------------------------------------------

ALTER TABLE public.profiles_talent
  ADD COLUMN base_town_id bigint REFERENCES public.towns(id);

COMMENT ON COLUMN public.profiles_talent.base_town_id IS
  'Chosen base town. base_latitude / base_longitude are derived from it by trigger and cannot be written directly.';

-- 3. Derived coordinates ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_talent_base_coordinates()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.base_town_id IS NULL THEN
    NEW.base_latitude  := NULL;
    NEW.base_longitude := NULL;
  ELSE
    SELECT t.latitude, t.longitude
      INTO NEW.base_latitude, NEW.base_longitude
      FROM public.towns t
     WHERE t.id = NEW.base_town_id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER set_talent_base_coordinates
  BEFORE INSERT OR UPDATE OF base_town_id, base_latitude, base_longitude
  ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.set_talent_base_coordinates();

COMMIT;
