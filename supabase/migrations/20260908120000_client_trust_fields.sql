-- profiles_clients had no trust-field guard: client_profile_manage_own is ALL
-- for authenticated on auth.uid() = user_id, so a client could PATCH their own
-- approval_status to 'approved'. Third instance of the pattern already fixed on
-- profiles_talent and profiles_venues (20260829030000).
--
-- profiles_clients has NO is_verified column, so this guard covers
-- approval_status only.

CREATE OR REPLACE FUNCTION public.enforce_client_trust_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$fn$;

-- 'a_' prefix is load-bearing: BEFORE triggers fire in NAME ORDER, and this
-- must run before trg_require_client_dob. See D-023.
DROP TRIGGER IF EXISTS a_enforce_client_trust_fields ON public.profiles_clients;

CREATE TRIGGER a_enforce_client_trust_fields
  BEFORE INSERT OR UPDATE ON public.profiles_clients
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_trust_fields();
