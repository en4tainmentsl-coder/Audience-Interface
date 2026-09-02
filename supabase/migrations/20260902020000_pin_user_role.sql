-- Close privilege escalation on profiles_users.role.
--
-- Found 2026-09-02 during the full RLS audit, confirmed by live test:
--   role before=client ; after self-update=admin
--
-- Three things lined up to make this reachable through PostgREST:
--   1. users_update_own permits UPDATE on your own row, no column limit
--   2. `authenticated` holds the UPDATE privilege on profiles_users.role
--   3. the only trigger, check_client_age, validates DOB and pins nothing
--
-- A single PATCH /profiles_users?id=eq.<self> {"role":"admin"} escalated.
--
-- get_my_role() reads this column, and it gates profiles_admin,
-- genres_admin_write, rs_admin_all and rh_admin_all - but worse, it is the
-- admin bypass inside enforce_talent_trust_fields, enforce_quote_request_writes
-- and enforce_quote_writes. Every control shipped on 2026-09-01/02 assumed
-- this column was trustworthy.
--
-- Not fixed by REVOKE: table-level UPDATE covers all columns, so a
-- column-level revoke is inert unless table UPDATE is revoked and re-granted
-- per column. The trigger is the correct instrument.

CREATE OR REPLACE FUNCTION public.enforce_user_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- service_role (null auth.uid()) and admin write freely.
  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- There is no INSERT policy for authenticated today, so this is a
    -- backstop rather than an active path. Self-registration as admin must
    -- never become possible by adding a policy later.
    IF NEW.role = 'admin' THEN
      RAISE EXCEPTION 'The admin role cannot be self-assigned.'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- role is assigned at registration and changed only by an admin or the
  -- service role. get_my_role() reads the pre-update snapshot here, so a
  -- client updating their own row still evaluates as 'client'.
  NEW.id   := OLD.id;
  NEW.role := OLD.role;

  RETURN NEW;
END;
$function$;

-- Sorts before trg_check_client_age, so the age check sees the restored
-- role rather than an attacker-supplied one.
DROP TRIGGER IF EXISTS a_enforce_user_trust_fields ON public.profiles_users;
CREATE TRIGGER a_enforce_user_trust_fields
  BEFORE INSERT OR UPDATE ON public.profiles_users
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_trust_fields();

COMMENT ON FUNCTION public.enforce_user_trust_fields() IS
  'Pins profiles_users.role and id against non-admin writes, and refuses '
  'self-assignment of the admin role on insert. role gates get_my_role(), '
  'which is the admin bypass in every write-control trigger on this schema.';

COMMENT ON COLUMN public.profiles_users.role IS
  'Authorisation-critical. Read by get_my_role(), which gates admin policies '
  'and the admin bypass in every write-control trigger. Writable only by '
  'admin or service_role, enforced by enforce_user_trust_fields().';
