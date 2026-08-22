-- Applied via Supabase SQL Editor 2026-08-22.
--
-- Starting Rate: pricing_per_session becomes public-facing, displayed as
-- "Starting Rate" / "From LKR X".
--
-- Session unit: 4 hours of performance plus a 30-minute break (4.5 hours
-- on site). Setup and soundcheck sit outside this; talent must be ready
-- 60-90 minutes before start time. Bookings under 4 hours pay the full
-- base rate (hard floor); over 4 hours scales proportionally.
--
-- Ceiling of 10,000,000 LKR is roughly double a realistic top act (3-5m),
-- so it catches a fat-fingered extra zero without rejecting a legitimate rate.
--
-- Requirement enforced at submission rather than via NOT NULL, mirroring
-- check_talent_dob_before_submission, so progressive profile building
-- still works.
--
-- Cooldown applies ONLY to talent editing their own rate. Admins, Directus
-- (nocobase_admin) and service_role bypass, because get_my_role() returns
-- NULL without an end-user JWT. Stated explicitly rather than relying on
-- NULL propagation through the comparison.
--
-- An admin correction does not reset the talent's clock -- a support typo
-- fix should not cost them their next 30 days.

-- 1. Constrain the column
ALTER TABLE public.profiles_talent
  ALTER COLUMN pricing_per_session TYPE numeric(12,2);

ALTER TABLE public.profiles_talent
  ADD CONSTRAINT profiles_talent_pricing_range
  CHECK (pricing_per_session IS NULL
         OR (pricing_per_session > 0 AND pricing_per_session <= 10000000));

-- 2. Track when the rate last changed
ALTER TABLE public.profiles_talent
  ADD COLUMN pricing_updated_at timestamptz;

-- 3. Rate required before submission or approval.
--    Mirrors check_talent_dob_before_submission.
CREATE OR REPLACE FUNCTION public.check_talent_pricing_before_submission()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.approval_status IN ('pending_approval', 'approved')
     AND NEW.pricing_per_session IS NULL THEN
    RAISE EXCEPTION 'A starting rate is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER talent_pricing_required_before_submission
  BEFORE INSERT OR UPDATE ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.check_talent_pricing_before_submission();

-- 4. 30-day cooldown, enforced only against the talent's own edits.
--    Admins, Directus (nocobase_admin) and service_role bypass, because
--    get_my_role() returns NULL with no end-user JWT. Stated explicitly
--    rather than relying on NULL propagation.
CREATE OR REPLACE FUNCTION public.enforce_pricing_cooldown()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  caller_role text := public.get_my_role();
BEGIN
  IF NEW.pricing_per_session IS DISTINCT FROM OLD.pricing_per_session THEN

    IF caller_role = 'talent' THEN
      IF OLD.pricing_updated_at IS NOT NULL
         AND OLD.pricing_updated_at > now() - interval '30 days' THEN
        RAISE EXCEPTION 'Your starting rate can only be changed once every 30 days. Next change available %.',
          to_char(OLD.pricing_updated_at + interval '30 days', 'DD Mon YYYY')
          USING ERRCODE = '23514';
      END IF;
      -- Only a talent's own change starts their clock. An admin correction
      -- should not cost the talent their next 30 days.
      NEW.pricing_updated_at := now();
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER talent_pricing_cooldown
  BEFORE UPDATE ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.enforce_pricing_cooldown();
