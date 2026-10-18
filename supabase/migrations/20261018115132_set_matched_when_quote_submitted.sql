-- `matched` means "the talent has quoted". Nothing in the database ever set it:
-- the only writer was an admin clicking "Mark as Matched" in Admin.tsx, whose
-- button id is still `mark-quoted-btn` — the older, truer name.
--
-- Meanwhile enforce_quote_writes and accept_quote_and_create_booking both gate
-- on status IN ('open','matched'), written in expectation of a value nothing
-- produced. This closes that gap.
--
-- It also matters for the coming 48-hour expiry job: the deadline is a TALENT
-- RESPONSE deadline, so a request that has been quoted must stop being `open`.
-- Without this, the job would expire requests whose quote is sitting with the
-- client, and cascade_quote_request_close would then expire the quote too.

-- 1. Permit the transition. enforce_quote_request_writes previously allowed
--    exactly one status change for a non-admin caller (open|matched ->
--    cancelled), so the trigger below would raise 42501 and take the talent's
--    quote submission down with it.
--
--    The permission is deliberately narrow: open -> matched only when a pending
--    quote already exists for that request, so the status cannot be faked by a
--    caller who has not quoted.

CREATE OR REPLACE FUNCTION public.enforce_quote_request_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  caller_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  caller_role := get_my_role();

  IF caller_role = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF EXISTS (SELECT 1 FROM public.profiles_talent t
                WHERE t.id = NEW.talent_id
                  AND t.deletion_requested_at IS NOT NULL) THEN
      RAISE EXCEPTION 'This artist is no longer accepting bookings.'
        USING ERRCODE = '42501';
    END IF;

    NEW.status         := 'open'::quotation_request_status;
    NEW.decline_reason := NULL;
    NEW.created_at     := now();
    NEW.updated_at     := now();
    RETURN NEW;
  END IF;

  NEW.id                     := OLD.id;
  NEW.client_user_id         := OLD.client_user_id;
  NEW.talent_id              := OLD.talent_id;
  NEW.venue_id               := OLD.venue_id;
  NEW.event_type             := OLD.event_type;
  NEW.starts_at              := OLD.starts_at;
  NEW.ends_at                := OLD.ends_at;
  NEW.created_at             := OLD.created_at;
  NEW.talent_rate_at_request := OLD.talent_rate_at_request;
  NEW.decline_reason         := OLD.decline_reason;

  IF OLD.status <> 'open'::quotation_request_status THEN
    NEW.location             := OLD.location;
    NEW.event_address        := OLD.event_address;
    NEW.event_latitude       := OLD.event_latitude;
    NEW.event_longitude      := OLD.event_longitude;
    NEW.special_requirements := OLD.special_requirements;
    NEW.audience_capacity    := OLD.audience_capacity;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status IN ('open', 'matched') AND NEW.status = 'cancelled')
      OR (
        OLD.status = 'open'::quotation_request_status
        AND NEW.status = 'matched'::quotation_request_status
        AND EXISTS (SELECT 1 FROM public.quotes q
                     WHERE q.quote_request_id = OLD.id
                       AND q.quote_status = 'pending'::quotation_status)
      )
    ) THEN
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

-- 2. Set it. AFTER INSERT so the quote row is visible to the EXISTS check
--    above. Guarded on status = 'open' so a cancelled or expired request is
--    never resurrected by a late quote.

CREATE OR REPLACE FUNCTION public.set_request_matched_on_quote()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.quote_status = 'pending'::quotation_status THEN
    UPDATE public.quote_requests r
       SET status = 'matched'::quotation_request_status
     WHERE r.id = NEW.quote_request_id
       AND r.status = 'open'::quotation_request_status;
  END IF;
  RETURN NULL;
END;
$function$;

CREATE TRIGGER quotes_set_request_matched
AFTER INSERT ON public.quotes
FOR EACH ROW EXECUTE FUNCTION public.set_request_matched_on_quote();
