-- 1. DOB / pricing checks fire only on an approval_status TRANSITION.
-- 2. Talent trust trigger renamed to sort first, so all later triggers
--    see the authoritative values.
-- 3. profiles_venues gets the same trust-field guard as profiles_talent.

-- ── 1. Transition-scoped submission validations ────────────────────────
-- Previously these tested NEW.approval_status alone, so they raised on
-- ANY update to a row already sitting at pending_approval -- including an
-- admin's. They are submission-time validations, not row invariants.

CREATE OR REPLACE FUNCTION public.check_talent_dob_before_submission()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  transitioning boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    transitioning := true;
  ELSE
    transitioning := NEW.approval_status IS DISTINCT FROM OLD.approval_status;
  END IF;

  IF transitioning
     AND NEW.approval_status IN ('pending_approval', 'approved')
     AND NEW.date_of_birth IS NULL THEN
    RAISE EXCEPTION 'Date of birth is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_talent_pricing_before_submission()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  transitioning boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    transitioning := true;
  ELSE
    transitioning := NEW.approval_status IS DISTINCT FROM OLD.approval_status;
  END IF;

  IF transitioning
     AND NEW.approval_status IN ('pending_approval', 'approved')
     AND NEW.pricing_per_session IS NULL THEN
    RAISE EXCEPTION 'A starting rate is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

-- ── 2. Talent trust fields: allow self-submission, block self-approval ──
-- Renamed with a leading 'a_' so it fires FIRST. Postgres runs BEFORE
-- triggers in name order; previously this sat between the pricing check
-- and the DOB check, so the two validations saw different values for the
-- same write. Do not rename without re-checking that ordering.

CREATE OR REPLACE FUNCTION public.enforce_talent_trust_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified    := false;
      NEW.is_public      := false;
      NEW.profile_status := 'pending'::talent_status;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified    := OLD.is_verified;
      NEW.is_public      := OLD.is_public;
      NEW.profile_status := OLD.profile_status;
      -- Submitting yourself for review is legitimate. Approving yourself
      -- is not. Only draft -> pending_approval passes.
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_talent_trust_fields ON public.profiles_talent;
DROP TRIGGER IF EXISTS a_enforce_talent_trust_fields ON public.profiles_talent;

CREATE TRIGGER a_enforce_talent_trust_fields
  BEFORE INSERT OR UPDATE ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.enforce_talent_trust_fields();

-- ── 3. Same guard for profiles_venues ──────────────────────────────────
-- venue_profile_manage_own is ALL for the row owner, and the table has no
-- triggers, so a venue could set is_verified / approval_status on itself.
-- VenuePortal.tsx inserts approval_status = 'pending_approval' at signup,
-- which stays permitted.

CREATE OR REPLACE FUNCTION public.enforce_venue_trust_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified := false;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified := OLD.is_verified;
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS a_enforce_venue_trust_fields ON public.profiles_venues;

CREATE TRIGGER a_enforce_venue_trust_fields
  BEFORE INSERT OR UPDATE ON public.profiles_venues
  FOR EACH ROW EXECUTE FUNCTION public.enforce_venue_trust_fields();

SELECT 1;
