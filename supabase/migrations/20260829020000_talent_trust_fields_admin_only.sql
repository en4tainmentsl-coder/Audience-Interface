-- Trust fields on profiles_talent are admin-only.
--
-- talent_profile_manage_own grants ALL on every column to the row's owner,
-- so a talent could set is_verified / approval_status / is_public / 
-- profile_status on themselves. Only is_featured was protected.
--
-- auth.uid() IS NOT NULL is deliberate: Directus connects as a direct
-- Postgres role with no JWT, so auth.uid() is NULL there and admin writes
-- through the panel pass. Same pattern as enforce_featured_requires_admin.

CREATE OR REPLACE FUNCTION public.enforce_talent_trust_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified     := false;
      NEW.approval_status := 'draft'::approval_status;
      NEW.is_public       := false;
      NEW.profile_status  := 'pending'::talent_status;
    ELSE
      NEW.is_verified     := OLD.is_verified;
      NEW.approval_status := OLD.approval_status;
      NEW.is_public       := OLD.is_public;
      NEW.profile_status  := OLD.profile_status;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_talent_trust_fields ON public.profiles_talent;

CREATE TRIGGER trg_enforce_talent_trust_fields
  BEFORE INSERT OR UPDATE ON public.profiles_talent
  FOR EACH ROW EXECUTE FUNCTION public.enforce_talent_trust_fields();

-- New profiles must not be publicly listed before review.
ALTER TABLE public.profiles_talent ALTER COLUMN is_public SET DEFAULT false;

SELECT 1;
