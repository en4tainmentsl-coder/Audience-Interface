-- 20260921210000_talent_completeness_before_submission.sql
--
-- A talent profile cannot be submitted for review until it is complete.
--
-- Third check of an existing shape. check_talent_dob_before_submission and
-- check_talent_pricing_before_submission already guard date_of_birth and
-- pricing_per_session the same way, and are NOT duplicated here.
--
-- REQUIRED, per Praveen 2026-09-21 (D-033)
--   profiles_talent : stage_name, full_name, email, mobile, short_bio, bio,
--                     languages, type_of_ensemble, both video links,
--                     profile photo, cover photo, base_town_id
--   talent_media    : at least one gallery image
--   talent_identity : nic_hash AND nic_front_url AND nic_back_url
--
-- NOT required: optional_location_1..4, secondary_genre_id, tertiary_genre_id.
--
-- ONE MESSAGE, EVERYTHING MISSING
-- -------------------------------
-- The check collects every missing item and raises once:
--   'Your profile is not complete. Still needed: cover photo, NIC back image.'
-- Failing on the first missing field would make a talent fix one thing, resubmit,
-- and discover the next. The Submit button's checklist can show the same list.
--
-- THE GALLERY MEDIA TYPE IS NOT WHAT IT LOOKS LIKE
-- ------------------------------------------------
-- Gallery images are stored in talent_media with media_type = 'profile_photo'
-- (ProfileEditor.tsx: FEATURE_MEDIA_TYPE = 'profile_photo'), while the actual
-- profile photo is profiles_talent.profile_photo_url. The enum's own 'gallery'
-- value is unused. This check matches what the app writes, not what the enum
-- implies - checking 'gallery' would mean no profile could ever be submitted.
-- The naming is worth fixing separately; changing it here would break uploads.
--
-- WHEN IT FIRES
-- -------------
-- Only on a transition into 'pending_approval' or 'approved' - not on ordinary
-- edits, and not on the INSERT of a new draft. Runs after
-- a_enforce_talent_trust_fields (alphabetical trigger order), so it sees the
-- approval_status that guard actually allows, not what the client asked for.
--
-- SECURITY DEFINER because it reads talent_media and talent_identity. Under the
-- caller's own rights, a missing SELECT policy on either table would return zero
-- rows and block a complete profile - failing closed for the wrong reason.

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
  IF NEW.stage_name        IS NULL OR NEW.stage_name        ~ blank THEN missing := missing || 'stage name';            END IF;
  IF NEW.full_name         IS NULL OR NEW.full_name         ~ blank THEN missing := missing || 'full name';             END IF;
  IF NEW.email             IS NULL OR NEW.email             ~ blank THEN missing := missing || 'email';                 END IF;
  IF NEW.mobile            IS NULL OR NEW.mobile            ~ blank THEN missing := missing || 'mobile number';         END IF;
  IF NEW.short_bio         IS NULL OR NEW.short_bio         ~ blank THEN missing := missing || 'short bio';             END IF;
  IF NEW.bio               IS NULL OR NEW.bio               ~ blank THEN missing := missing || 'bio';                   END IF;
  IF NEW.languages         IS NULL OR NEW.languages         ~ blank THEN missing := missing || 'languages';             END IF;
  IF NEW.type_of_ensemble  IS NULL OR NEW.type_of_ensemble  ~ blank THEN missing := missing || 'ensemble type';         END IF;

  IF NEW.url_trailer_video          IS NULL OR NEW.url_trailer_video          ~ blank THEN missing := missing || 'trailer video';          END IF;
  IF NEW.url_live_performace_video  IS NULL OR NEW.url_live_performace_video  ~ blank THEN missing := missing || 'live performance video'; END IF;
  IF NEW.profile_photo_url          IS NULL OR NEW.profile_photo_url          ~ blank THEN missing := missing || 'profile photo';          END IF;
  IF NEW.cover_photo_url            IS NULL OR NEW.cover_photo_url            ~ blank THEN missing := missing || 'cover photo';            END IF;

  -- Base town. base_latitude / base_longitude are derived from it (D-032), so the
  -- town is the thing to check.
  IF NEW.base_town_id IS NULL THEN
    missing := missing || 'base town';
  END IF;

  -- At least one gallery image. See the note above on the media type.
  IF NOT EXISTS (
    SELECT 1 FROM public.talent_media m
     WHERE m.talent_id = NEW.id
       AND m.media_type = 'profile_photo'
  ) THEN
    missing := missing || 'at least one gallery photo';
  END IF;

  -- NIC: the number and both document images. Without all three, KYC cannot be
  -- reviewed, so the profile is not complete (D-033).
  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_hash IS NOT NULL
  ) THEN
    missing := missing || 'NIC number';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_front_url IS NOT NULL
  ) THEN
    missing := missing || 'NIC front image';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_back_url IS NOT NULL
  ) THEN
    missing := missing || 'NIC back image';
  END IF;

  IF array_length(missing, 1) > 0 THEN
    RAISE EXCEPTION 'Your profile is not complete. Still needed: %.',
      array_to_string(missing, ', ')
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER check_talent_completeness_before_submission
  BEFORE INSERT OR UPDATE ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.check_talent_completeness_before_submission();

COMMIT;

-- NOT DONE HERE
--
-- 1. The "at most 3 gallery photos" limit. That is an upload-time rule belonging on
--    talent_media or in the form, not in a submission gate - by the time a profile is
--    submitted, a fourth photo would already have been uploaded and paid for at
--    Cloudinary. Tracked separately.
--
-- 2. date_of_birth and pricing_per_session - already guarded by their own triggers.
--
-- 3. Nothing has ever written to talent_media: it is empty for every talent. The
--    gallery requirement is therefore enforced against a path that has never run
--    end to end. Test uploads before relying on it.
