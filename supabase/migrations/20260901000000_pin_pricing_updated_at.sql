-- Close the talent rate-cooldown bypass.
--
-- enforce_pricing_cooldown() gates changes to pricing_per_session on
-- OLD.pricing_updated_at, but nothing pinned that column. `authenticated`
-- holds UPDATE on it, so a talent could defeat the 30-day cooldown in two
-- statements:
--
--   1. update profiles_talent set pricing_updated_at = '2020-01-01' ...
--      (no price change, so the cooldown trigger never engages)
--   2. update profiles_talent set pricing_per_session = <new> ...
--      (the check now passes)
--
-- pricing_updated_at is a system clock, not user data. It must only ever be
-- written by enforce_pricing_cooldown() or by an admin.
--
-- Trigger order matters and is already correct: a_enforce_talent_trust_fields
-- sorts before talent_pricing_cooldown, so the pin lands first and the
-- cooldown trigger still overwrites it with now() on a legitimate change.

CREATE OR REPLACE FUNCTION public.enforce_talent_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified        := false;
      NEW.is_public          := false;
      NEW.profile_status     := 'pending'::talent_status;
      NEW.rating             := 0.00;
      NEW.pricing_updated_at := NULL;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified        := OLD.is_verified;
      NEW.is_public          := OLD.is_public;
      NEW.profile_status     := OLD.profile_status;
      NEW.rating             := OLD.rating;
      NEW.pricing_updated_at := OLD.pricing_updated_at;
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

COMMENT ON COLUMN public.profiles_talent.pricing_updated_at IS
  'System-maintained. Set only by enforce_pricing_cooldown() when a talent '
  'changes their own rate. Pinned against non-admin writes by '
  'enforce_talent_trust_fields(). Admin corrections deliberately do not '
  'restart the talent''s 30-day clock.';
