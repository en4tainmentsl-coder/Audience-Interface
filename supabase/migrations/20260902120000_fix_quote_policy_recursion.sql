-- Fix infinite recursion (42P17) between quote_requests and quotes policies.
--
-- APPLIED VIA SQL EDITOR 2026-09-02 before this file existed. This migration
-- records what was run so the repo matches live and a fresh environment
-- reproduces it. Do NOT re-apply to production - the ADD CONSTRAINT would
-- fail as a duplicate.
--
-- Found by the first authenticated PostgREST request ever made against this
-- schema. Any RLS-bound read of EITHER table failed outright:
--
--   quote_requests_talent_read (SELECT on quote_requests) queries quotes
--   quotes_client_read         (SELECT on quotes)         queries quote_requests
--
-- Each policy's evaluation triggers the other's. Postgres aborts with 42P17.
--
-- PRE-EXISTING: both policies predate the 2026-09-01/02 hardening work.
-- Undetected because no application code touches these tables yet, and
-- because every prior test ran through execute_sql as postgres, which
-- bypasses RLS entirely. The policies were verified as written, never as
-- enforced. This would have stopped the orchestration layer on first contact.

-- 1. quote_requests_talent_read is redundant. quote_requests.talent_id is
--    NOT NULL, so every request names exactly one talent, and
--    qr_talent_select_targeted already grants that talent read access
--    without a cross-table reference.
DROP POLICY IF EXISTS quote_requests_talent_read ON public.quote_requests;

-- 2. Close the anomaly that made the redundant policy look necessary:
--    nothing forced quotes.talent_id to match the request's talent. Both
--    columns were already NOT NULL, so a quote always named A talent - just
--    not necessarily the RIGHT one. Derive it, as quoted_amount already is.
CREATE OR REPLACE FUNCTION public.enforce_quote_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req_rate      numeric;
  req_hours     numeric;
  req_talent    uuid;
  parent_status quotation_request_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT qr.talent_rate_at_request, qr.duration_hours, qr.talent_id
      INTO req_rate, req_hours, req_talent
      FROM public.quote_requests qr
     WHERE qr.id = NEW.quote_request_id;

    IF req_rate IS NULL THEN
      RAISE EXCEPTION
        'Cannot price a quote: quote_request % has no talent_rate_at_request.',
        NEW.quote_request_id
        USING ERRCODE = '22004';
    END IF;

    -- A quote always belongs to the talent the request named. Hard rule.
    NEW.talent_id     := req_talent;
    NEW.quoted_amount := round(req_rate * greatest(1, req_hours / 4), 2);

    NEW.created_at := now();
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
      NEW.commission_rate_percent := 21.00;
      NEW.quote_status            := 'pending'::quotation_status;
    END IF;

    RETURN NEW;
  END IF;

  NEW.id               := OLD.id;
  NEW.quote_request_id := OLD.quote_request_id;
  NEW.talent_id        := OLD.talent_id;
  NEW.quoted_amount    := OLD.quoted_amount;
  NEW.created_at       := OLD.created_at;
  NEW.updated_at       := now();

  IF NEW.quote_status = 'accepted'::quotation_status
     AND OLD.quote_status IS DISTINCT FROM NEW.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;

    IF parent_status NOT IN ('open'::quotation_request_status,
                             'matched'::quotation_request_status) THEN
      RAISE EXCEPTION
        'Cannot accept a quote whose request is %. Acceptance requires a live request.',
        parent_status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  NEW.commission_rate_percent := OLD.commission_rate_percent;
  NEW.sent_at                 := OLD.sent_at;
  NEW.expires_at              := OLD.expires_at;

  IF NEW.quote_status IS DISTINCT FROM OLD.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;

    IF NOT (OLD.quote_status = 'pending'::quotation_status
            AND NEW.quote_status = 'expired'::quotation_status
            AND parent_status IN ('cancelled'::quotation_request_status,
                                  'expired'::quotation_request_status,
                                  'declined'::quotation_request_status)) THEN
      RAISE EXCEPTION
        'A talent cannot change quote_status. Acceptance and rejection are client actions handled by the orchestration service.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 3. Tripwire making the hard rule structural rather than dependent on the
--    trigger surviving future edits.
--
-- CAVEAT: Postgres does not truly support subqueries in CHECK constraints.
-- Wrapping one in a function is a known workaround and is NOT re-validated
-- when the OTHER table changes. That is acceptable only because
-- quote_requests.talent_id is pinned immutable by
-- enforce_quote_request_writes() - the two protections depend on each other.
CREATE OR REPLACE FUNCTION public.quote_talent_matches_request(q_request_id uuid, q_talent_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.quote_requests qr
     WHERE qr.id = q_request_id AND qr.talent_id = q_talent_id
  );
$$;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_talent_matches_request
  CHECK (public.quote_talent_matches_request(quote_request_id, talent_id));
