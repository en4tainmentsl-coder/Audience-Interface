-- Inputs the pricing function needs. Decisions in Todoist 6hQpgHxVX8GMh3fX,
-- settled with Praveen 2026-09-05.
--
-- 1. Equipment fee is a percentage of the PERFORMANCE FEE ONLY, set per
--    talent, defaulting to 5% and capped at 10%. There was previously
--    nowhere to store a talent's override.
--
-- 2. Equipment fee applies ONLY when the talent provides sound. The
--    'shared' enum member is removed: sound is either provided or it is
--    not, with no middle case.
--
-- 3. travel_radius_km is dropped. It predates the current travel model
--    and nothing reads it in either repo (checked 2026-09-05; the only
--    hits were in generated database.types.ts, which regenerates).
--    The free radius is a global 10km, not a per-talent value.

-- ---------------------------------------------------------------
-- equipment fee percentage, per talent
-- ---------------------------------------------------------------

ALTER TABLE public.profiles_talent
  ADD COLUMN equipment_fee_percent numeric(5,2) NOT NULL DEFAULT 5.00;

ALTER TABLE public.profiles_talent
  ADD CONSTRAINT chk_talent_equipment_fee_percent
  CHECK (equipment_fee_percent >= 0 AND equipment_fee_percent <= 10);

COMMENT ON COLUMN public.profiles_talent.equipment_fee_percent IS
  'Percentage of the performance fee charged when the talent provides sound. Default 5%, talent may override up to a 10% ceiling.';

-- ---------------------------------------------------------------
-- drop the obsolete travel radius
-- ---------------------------------------------------------------

ALTER TABLE public.profiles_talent
  DROP COLUMN IF EXISTS travel_radius_km;

-- ---------------------------------------------------------------
-- equipment_responsibility: remove 'shared'
-- ---------------------------------------------------------------
-- Postgres cannot drop a value from an enum, so the type is recreated.
-- Safe here: quotes.equipment_provided_by is the only column using it,
-- and quotes is at 0 rows.

CREATE TYPE public.equipment_responsibility_new AS ENUM ('talent', 'venue');

ALTER TABLE public.quotes
  ALTER COLUMN equipment_provided_by DROP DEFAULT;

ALTER TABLE public.quotes
  ALTER COLUMN equipment_provided_by
  TYPE public.equipment_responsibility_new
  USING equipment_provided_by::text::public.equipment_responsibility_new;

DROP TYPE public.equipment_responsibility;

ALTER TYPE public.equipment_responsibility_new
  RENAME TO equipment_responsibility;

ALTER TABLE public.quotes
  ALTER COLUMN equipment_provided_by
  SET DEFAULT 'talent'::public.equipment_responsibility;

COMMENT ON COLUMN public.quotes.equipment_provided_by IS
  'Who provides sound. The equipment fee is charged only when this is talent.';
