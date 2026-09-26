-- chk_rejection_reason_presence requires rejection_reason to be NULL whenever
-- approval_status is not 'rejected'. The trust guard cleared it on resubmission,
-- but the trust guard is skipped for admins and under service_role (auth.uid()
-- is NULL there) - so an admin or the review RPC moving a profile out of
-- 'rejected' hit a constraint violation instead.
--
-- Clearing belongs in a trigger with no role condition, so it holds for every
-- path: talent resubmission, admin re-open, or service_role.

create or replace function public.clear_rejection_on_status_change()
returns trigger
language plpgsql
as $function$
BEGIN
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status
     AND NEW.approval_status <> 'rejected' THEN
    NEW.rejection_reason := NULL;
    NEW.rejection_note   := NULL;
  END IF;
  RETURN NEW;
END;
$function$;

drop trigger if exists c_clear_rejection_on_status_change on public.profiles_talent;
create trigger c_clear_rejection_on_status_change
  before update on public.profiles_talent
  for each row
  execute function public.clear_rejection_on_status_change();
