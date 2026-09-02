-- Couple the quote lifecycle to the quote_request lifecycle.
--
-- Found 2026-09-02 by an end-to-end rolled-back test: a client cancelled a
-- request, and the talent then successfully edited fees on the still-pending
-- quote hanging off it. Nothing in the database coupled the two, so a quote
-- against a dead request stayed pending, editable, and structurally
-- acceptable. The orchestration service would have had to remember to check
-- the parent status on every acceptance - exactly the check that gets missed.
--
-- Two halves:
--   1. Closing a request expires its pending quotes.
--   2. Acceptance is refused outright when the parent is not live. This
--      applies to service_role too, on the same principle as quoted_amount:
--      a bug in the orchestration layer must not be able to do this silently.

CREATE OR REPLACE FUNCTION public.enforce_quote_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req_rate      numeric;
  req_hours     numeric;
  parent_status quotation_request_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT qr.talent_rate_at_request, qr.duration_hours
      INTO req_rate, req_hours
      FROM public.quote_requests qr
     WHERE qr.id = NEW.quote_request_id;

    IF req_rate IS NULL THEN
      RAISE EXCEPTION
        'Cannot price a quote: quote_request % has no talent_rate_at_request.',
        NEW.quote_request_id
        USING ERRCODE = '22004';
    END IF;

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

  -- Applies to EVERY caller, service_role included. A quote cannot be
  -- accepted once its request has been cancelled, expired or declined.
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
    -- One permitted non-admin transition: the cascade below. It runs under
    -- the cancelling client's auth.uid(), so it needs a path through here.
    -- Narrow enough to need no escape hatch - it is only reachable when the
    -- parent request is already closed, where expiring a quote is harmless.
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

-- Cascade. AFTER UPDATE, so the parent status is already committed to the
-- row by the time enforce_quote_writes reads it back.
CREATE OR REPLACE FUNCTION public.cascade_quote_request_close()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status IN ('cancelled'::quotation_request_status,
                        'expired'::quotation_request_status,
                        'declined'::quotation_request_status) THEN
    -- 'expired', not 'rejected': the client never judged the quote, the
    -- request went away underneath it. Keeps 'rejected' meaning an actual
    -- client decision, which matters for talent acceptance stats.
    UPDATE public.quotes
       SET quote_status = 'expired'::quotation_status
     WHERE quote_request_id = NEW.id
       AND quote_status = 'pending'::quotation_status;
  END IF;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS cascade_quote_request_close ON public.quote_requests;
CREATE TRIGGER cascade_quote_request_close
  AFTER UPDATE ON public.quote_requests
  FOR EACH ROW EXECUTE FUNCTION public.cascade_quote_request_close();

COMMENT ON FUNCTION public.cascade_quote_request_close() IS
  'Expires pending quotes when their quote_request is cancelled, expired or '
  'declined. Pairs with the acceptance guard in enforce_quote_writes(), which '
  'refuses acceptance against a non-live request for all callers.';
