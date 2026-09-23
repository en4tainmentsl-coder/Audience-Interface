-- 20260921210100_fix_completeness_gate_array_append.sql
--
-- Fixes a bug in 20260921210000: the completeness gate raised the wrong error.
--
-- WHAT WENT WRONG
-- ---------------
-- The function collected missing items with
--     missing := missing || 'short bio';
-- With an UNTYPED literal on the right, Postgres can resolve `anyarray || anyarray`
-- rather than `anyarray || anyelement`, and then tries to read 'short bio' as an
-- array literal:
--     22P02  malformed array literal: "short bio"
--     DETAIL: Array value must start with "{" or dimension information.
--
-- So instead of listing what was missing, submission failed with a type error.
--
-- The migration applied cleanly, and the function was broken: CREATE FUNCTION does not
-- execute the body. Found immediately afterwards by attempting a real submission
-- through an authenticated session (D-022), which is the only reason it did not ship.
--
-- Note the first four checks never tripped it, because that talent's stage name, full
-- name, email and mobile are filled in; short_bio was simply the first empty field. A
-- more complete test profile would have hidden this for longer.
--
-- THE FIX
-- -------
-- array_append(missing, '...') throughout - unambiguous, no cast needed. Everything
-- else in the function is unchanged.

BEGIN;

CREATE OR REPLACE FUNCTION public.check_talent_completeness_before_submission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  transitioning boolean;
  missing       text[] := '{}';
  blank         constant text := '^\s*$';
BEGIN
  IF TG_OP = 'INSERT' THEN
    transitioning := true;
  ELSE
    transitioning := NEW.approval_status IS DISTINCT FROM OLD.approval_status;
  END IF;

  IF NOT (transitioning
          AND NEW.approval_status IN ('pending_approval', 'approved')) THEN
    RETURN NEW;
  END IF;

  -- Text fields: NULL and whitespace-only both count as missing, because the
  -- profile form writes '' rather than NULL for untouched fields.
  IF NEW.stage_name       IS NULL OR NEW.stage_name       ~ blank THEN missing := array_append(missing, 'stage name');    END IF;
  IF NEW.full_name        IS NULL OR NEW.full_name        ~ blank THEN missing := array_append(missing, 'full name');     END IF;
  IF NEW.email            IS NULL OR NEW.email            ~ blank THEN missing := array_append(missing, 'email');         END IF;
  IF NEW.mobile           IS NULL OR NEW.mobile           ~ blank THEN missing := array_append(missing, 'mobile number'); END IF;
  IF NEW.short_bio        IS NULL OR NEW.short_bio        ~ blank THEN missing := array_append(missing, 'short bio');     END IF;
  IF NEW.bio              IS NULL OR NEW.bio              ~ blank THEN missing := array_append(missing, 'bio');           END IF;
  IF NEW.languages        IS NULL OR NEW.languages        ~ blank THEN missing := array_append(missing, 'languages');     END IF;
  IF NEW.type_of_ensemble IS NULL OR NEW.type_of_ensemble ~ blank THEN missing := array_append(missing, 'ensemble type'); END IF;

  IF NEW.url_trailer_video         IS NULL OR NEW.url_trailer_video         ~ blank THEN missing := array_append(missing, 'trailer video');          END IF;
  IF NEW.url_live_performace_video IS NULL OR NEW.url_live_performace_video ~ blank THEN missing := array_append(missing, 'live performance video'); END IF;
  IF NEW.profile_photo_url         IS NULL OR NEW.profile_photo_url         ~ blank THEN missing := array_append(missing, 'profile photo');          END IF;
  IF NEW.cover_photo_url           IS NULL OR NEW.cover_photo_url           ~ blank THEN missing := array_append(missing, 'cover photo');            END IF;

  -- Base town. base_latitude / base_longitude are derived from it (D-032).
  IF NEW.base_town_id IS NULL THEN
    missing := array_append(missing, 'base town');
  END IF;

  -- At least one gallery image. Gallery images are stored with
  -- media_type = 'profile_photo' - see the note in 20260921210000.
  IF NOT EXISTS (
    SELECT 1 FROM public.talent_media m
     WHERE m.talent_id = NEW.id
       AND m.media_type = 'profile_photo'
  ) THEN
    missing := array_append(missing, 'at least one gallery photo');
  END IF;

  -- NIC: the number and both document images (D-033).
  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_hash IS NOT NULL
  ) THEN
    missing := array_append(missing, 'NIC number');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_front_url IS NOT NULL
  ) THEN
    missing := array_append(missing, 'NIC front image');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_back_url IS NOT NULL
  ) THEN
    missing := array_append(missing, 'NIC back image');
  END IF;

  IF array_length(missing, 1) > 0 THEN
    RAISE EXCEPTION 'Your profile is not complete. Still needed: %.',
      array_to_string(missing, ', ')
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

COMMIT;

-- No trigger changes: CREATE OR REPLACE FUNCTION keeps the existing binding.
