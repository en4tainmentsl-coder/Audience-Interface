-- handle_talent_approval sets is_public = true whenever profile_status becomes
-- 'active'. It knew nothing about deletion requests, so an admin flipping
-- profile_status on a talent awaiting erasure silently put their profile back
-- on the public site: the trust guard exempts admins, and check_talent_deletion_gate
-- does not fire because deletion_requested_at is not changing.
-- Verified behaviourally 2026-09-26 before this fix: is_public went false -> true
-- with the deletion flag still set.
--
-- A pending deletion outranks any reinstatement. To bring someone back, an admin
-- must clear deletion_requested_at first, which is the deliberate withdrawal step.

create or replace function public.handle_talent_approval()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF NEW.profile_status = 'active' AND OLD.profile_status != 'active' THEN
    NEW.is_public := true;
  END IF;

  IF NEW.profile_status IN ('suspended', 'inactive') THEN
    NEW.is_public := false;
  END IF;

  -- Never publish a profile that has asked to be erased, whatever else happened above.
  IF NEW.deletion_requested_at IS NOT NULL THEN
    NEW.is_public := false;
  END IF;

  RETURN NEW;
END;
$function$;