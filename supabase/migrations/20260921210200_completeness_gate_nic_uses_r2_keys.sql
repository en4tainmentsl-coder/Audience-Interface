-- 20260921210200_completeness_gate_nic_uses_r2_keys.sql
--
-- Fixes the completeness gate's NIC check: it looked at two dead columns.
--
-- WHAT WENT WRONG
-- ---------------
-- 20260921210000 required talent_identity.nic_front_url and nic_back_url. Nothing
-- populates those columns. The KYC upload path writes:
--
--   nic_storage_bucket   'en4tainment-sensitive'
--   nic_front_public_id  'en410/kyc/<talent_id>/<uuid>.png'
--   nic_back_public_id   'en410/kyc/<talent_id>/<uuid>.png'
--   kyc_status           'submitted'
--
-- ...and leaves nic_front_url / nic_back_url NULL. They are the legacy pair, already
-- flagged for removal in Todoist 6hPG9FqHCFx3P6V5.
--
-- Consequence: every talent would have been blocked from submitting FOREVER, however
-- many documents they uploaded, with the message insisting on NIC images they had
-- already provided. The worst kind of gate - one that cannot be satisfied.
--
-- Storing an object key rather than a URL is the correct design: KYC documents are in
-- a private R2 bucket and are served through 120-second presigned URLs, so a stored
-- URL would be meaningless by the time anyone used it.
--
-- HOW IT WAS FOUND
-- ----------------
-- By uploading real NIC images through the app and then reading the row, rather than
-- trusting the column names. `upload-document` returned 200 twice, the UI showed
-- "Uploaded" for both sides (it reads kyc_status, not the URLs), and the gate still
-- refused. Second bug in this function found the same way; the first was
-- 20260921210100.
--
-- THE FIX
-- -------
-- Check nic_front_public_id / nic_back_public_id. Only those two conditions change;
-- everything else in the function is unchanged.
--
-- NOT CHANGED, deliberately: kyc_status is NOT part of the completeness test. The
-- talent's job is to supply the documents; reviewing them is the admin's, and
-- requiring 'verified' here would make submission depend on an approval step that
-- happens after submission.

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

  -- NIC: the number, plus both document images in R2. nic_front_public_id /
  -- nic_back_public_id are the object keys the upload path actually writes;
  -- nic_front_url / nic_back_url are the legacy pair and are always NULL.
  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_hash IS NOT NULL
  ) THEN
    missing := array_append(missing, 'NIC number');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_front_public_id IS NOT NULL
  ) THEN
    missing := array_append(missing, 'NIC front image');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.talent_identity ti
     WHERE ti.talent_id = NEW.id AND ti.nic_back_public_id IS NOT NULL
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
--
-- FOLLOW-UP: nic_front_url and nic_back_url are now referenced by nothing. Drop them
-- with the rest of that cleanup (6hPG9FqHCFx3P6V5) rather than here, so this stays a
-- one-purpose fix.
