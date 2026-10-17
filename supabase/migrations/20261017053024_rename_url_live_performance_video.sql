-- url_live_performace_video -> url_live_performance_video (missing 'n').
--
-- ALTER TABLE RENAME COLUMN updates views and constraints, but NOT plpgsql
-- function bodies — those are stored as text and resolved at call time. The
-- completeness gate reads this column, so it is replaced in the same migration.
-- Shipping the rename alone would break submission silently, which is exactly
-- what 20261017033953 did to the contact columns earlier today.
--
-- Verified live 2026-10-17 before writing: 1 function, 0 views, 0 constraints,
-- 0 indexes, 0 policies, 2 non-null rows.

alter table public.profiles_talent
  rename column url_live_performace_video to url_live_performance_video;

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
  v_email       text;
  v_mobile      text;
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

  -- Contact details live on talent_contact since 2026-10-17. The profile form
  -- writes them in a separate statement from the profile row, so a missing
  -- contact row is a real possibility rather than an impossible state.
  SELECT c.email, c.mobile INTO v_email, v_mobile
    FROM public.talent_contact c WHERE c.talent_id = NEW.id;

  -- Text fields: NULL and whitespace-only both count as missing, because the
  -- profile form writes '' rather than NULL for untouched fields.
  IF NEW.stage_name       IS NULL OR NEW.stage_name       ~ blank THEN missing := array_append(missing, 'stage name');    END IF;
  IF NEW.full_name        IS NULL OR NEW.full_name        ~ blank THEN missing := array_append(missing, 'full name');     END IF;
  IF v_email              IS NULL OR v_email              ~ blank THEN missing := array_append(missing, 'email');         END IF;
  IF v_mobile             IS NULL OR v_mobile             ~ blank THEN missing := array_append(missing, 'mobile number'); END IF;
  IF NEW.short_bio        IS NULL OR NEW.short_bio        ~ blank THEN missing := array_append(missing, 'short bio');     END IF;
  IF NEW.bio              IS NULL OR NEW.bio              ~ blank THEN missing := array_append(missing, 'bio');           END IF;
  IF NEW.languages        IS NULL OR NEW.languages        ~ blank THEN missing := array_append(missing, 'languages');     END IF;
  IF NEW.type_of_ensemble IS NULL OR NEW.type_of_ensemble ~ blank THEN missing := array_append(missing, 'ensemble type'); END IF;

  IF NEW.url_trailer_video          IS NULL OR NEW.url_trailer_video          ~ blank THEN missing := array_append(missing, 'trailer video');          END IF;
  IF NEW.url_live_performance_video IS NULL OR NEW.url_live_performance_video ~ blank THEN missing := array_append(missing, 'live performance video'); END IF;
  IF NEW.profile_photo_url          IS NULL OR NEW.profile_photo_url          ~ blank THEN missing := array_append(missing, 'profile photo');          END IF;
  IF NEW.cover_photo_url            IS NULL OR NEW.cover_photo_url            ~ blank THEN missing := array_append(missing, 'cover photo');            END IF;

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
