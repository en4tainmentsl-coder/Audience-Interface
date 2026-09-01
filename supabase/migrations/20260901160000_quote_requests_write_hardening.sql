-- Harden client writes on quote_requests.
--
-- quote_requests_client_manage was FOR ALL: correctly ownership-scoped, but
-- it granted UPDATE and DELETE over every column in every lifecycle state.
-- A client could move event times after a talent had quoted against them,
-- swap talent_id, set status directly to 'converted', fabricate a talent's
-- decline_reason, or DELETE a request with quotes hanging off it.
--
-- Decisions settled 2026-09-01:
--   - starts_at/ends_at are frozen at insert. Never client-editable.
--   - Clients never DELETE. Cancellation is a status transition.
--   - Only 'client' and 'venue' roles may create requests.
--
-- RLS is row-level, so column-level immutability is enforced by trigger.
-- Policies decide which ROWS are reachable; the trigger decides which
-- COLUMNS may move.

-- 1. status had no default and was nullable. chk_qreq_status did not catch
--    this: a CHECK evaluates to NULL against a NULL input and passes. A
--    request could exist in no lifecycle state at all.
ALTER TABLE public.quote_requests
  ALTER COLUMN status SET DEFAULT 'open'::quotation_request_status;

UPDATE public.quote_requests SET status = 'open'::quotation_request_status
  WHERE status IS NULL;

ALTER TABLE public.quote_requests
  ALTER COLUMN status SET NOT NULL;

-- 2. Column-level write control.
CREATE OR REPLACE FUNCTION public.enforce_quote_request_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  caller_role text;
BEGIN
  -- service_role and internal callers have no auth.uid(). The orchestration
  -- layer is expected to write through this path.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  caller_role := get_my_role();

  IF caller_role = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.status         := 'open'::quotation_request_status;
    NEW.decline_reason := NULL;
    NEW.created_at     := now();
    NEW.updated_at     := now();
    RETURN NEW;
  END IF;

  -- Immutable for the whole life of the row.
  NEW.id                     := OLD.id;
  NEW.client_user_id         := OLD.client_user_id;
  NEW.talent_id              := OLD.talent_id;
  NEW.venue_id               := OLD.venue_id;
  NEW.event_type             := OLD.event_type;
  NEW.starts_at              := OLD.starts_at;
  NEW.ends_at                := OLD.ends_at;
  NEW.created_at             := OLD.created_at;
  NEW.talent_rate_at_request := OLD.talent_rate_at_request;

  -- decline_reason describes the TALENT's refusal. A client writing it
  -- would be fabricating reputational data about the counterparty.
  NEW.decline_reason         := OLD.decline_reason;

  -- Once a quote exists the request is a commercial term. Travel and
  -- equipment fees were priced against this location and budget.
  IF OLD.status <> 'open'::quotation_request_status THEN
    NEW.location             := OLD.location;
    NEW.event_address        := OLD.event_address;
    NEW.event_latitude       := OLD.event_latitude;
    NEW.event_longitude      := OLD.event_longitude;
    NEW.budget_min           := OLD.budget_min;
    NEW.budget_max           := OLD.budget_max;
    NEW.special_requirements := OLD.special_requirements;
  END IF;

  -- Pinned columns are restored silently, matching enforce_talent_trust_fields.
  -- An illegal status transition raises instead: a client who believes they
  -- cancelled and silently did not is a worse outcome than an error.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (OLD.status IN ('open', 'matched') AND NEW.status = 'cancelled') THEN
      RAISE EXCEPTION
        'A quote request owner may only cancel, and only while open or matched (attempted % -> %).',
        OLD.status, NEW.status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

-- Sorts before trg_quote_requests_rate_snapshot, so the snapshot trigger
-- keeps the final word on talent_rate_at_request.
DROP TRIGGER IF EXISTS enforce_quote_request_writes ON public.quote_requests;
CREATE TRIGGER enforce_quote_request_writes
  BEFORE INSERT OR UPDATE ON public.quote_requests
  FOR EACH ROW EXECUTE FUNCTION public.enforce_quote_request_writes();

-- 3. Split FOR ALL into explicit policies. No DELETE policy is created,
--    so DELETE is denied to authenticated by absence.
DROP POLICY IF EXISTS quote_requests_client_manage ON public.quote_requests;

CREATE POLICY quote_requests_owner_select ON public.quote_requests
  FOR SELECT TO authenticated
  USING (auth.uid() = client_user_id);

CREATE POLICY quote_requests_owner_insert ON public.quote_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = client_user_id
    AND get_my_role() = ANY (ARRAY['client', 'venue'])
  );

CREATE POLICY quote_requests_owner_update ON public.quote_requests
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = client_user_id
    AND status IN ('open'::quotation_request_status,
                   'matched'::quotation_request_status)
  )
  WITH CHECK (auth.uid() = client_user_id);

COMMENT ON FUNCTION public.enforce_quote_request_writes() IS
  'Column-level write control for quote_requests. Freezes identity, timing '
  'and pricing inputs for the life of the row; freezes location and budget '
  'once status leaves open; restricts owner status changes to cancellation. '
  'Bypassed by service_role (null auth.uid()) and by admin.';
