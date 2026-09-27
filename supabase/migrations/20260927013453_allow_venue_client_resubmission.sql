-- Same bug fixed for talent in 20260926094547: the guards allowed only
-- draft -> pending_approval, so a REJECTED venue or client could never
-- resubmit. Venues hit this the moment venue approval exists, because
-- VenuePortal already submits and waits on approval.
--
-- Unlike profiles_talent these tables have no rejection_reason column, so
-- there is nothing to clear on resubmission.

create or replace function public.enforce_venue_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified := false;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified := OLD.is_verified;
      IF NOT (OLD.approval_status IN ('draft', 'rejected')
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

create or replace function public.enforce_client_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      IF NOT (OLD.approval_status IN ('draft', 'rejected')
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
