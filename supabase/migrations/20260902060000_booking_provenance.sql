-- Give bookings a verifiable origin.
--
-- Found 2026-09-02 while testing the messages fix: a 'confirmed' booking was
-- created with no quote, no amounts, and nothing objected. bookings is the
-- authoritative money record and it was structurally free-floating:
--
--   - quote_id nullable, so a booking need not derive from any agreement
--   - talent_id, client_user_id, starts_at, ends_at independently supplied,
--     so a booking could cite quote A while naming talent B
--   - money columns are plain numeric DEFAULT 0.00, not generated
--   - bookings_total_adds_up_check reads "client_total_amount = 0.00 OR
--     (parts sum)", so an all-zero booking satisfies it trivially
--   - nothing stopped one accepted quote spawning many bookings
--
-- Decision settled 2026-09-02: quote_id is required, with NO admin exception.
-- Offline deals are not yet a real need, and NOT NULL now is a one-line
-- migration to relax later, whereas tightening after quote-less rows exist
-- means backfilling. If it is ever relaxed, add an explicit booking_origin
-- enum rather than permitting null - a null says nothing about intent.

-- 1. Every booking derives from exactly one quote.
ALTER TABLE public.bookings
  ALTER COLUMN quote_id SET NOT NULL;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_quote_id_unique UNIQUE (quote_id);

-- 2. Provenance: parties, times and the two unambiguous money figures are
--    read from the quote, never supplied by the caller.
CREATE OR REPLACE FUNCTION public.enforce_booking_provenance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  q_status     quotation_status;
  q_talent     uuid;
  q_gross      numeric;
  q_commission numeric;
  r_client     uuid;
  r_venue      uuid;
  r_starts     timestamptz;
  r_ends       timestamptz;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT q.quote_status, q.talent_id, q.talent_net_earnings, q.commission_amount,
           qr.client_user_id, qr.venue_id, qr.starts_at, qr.ends_at
      INTO q_status, q_talent, q_gross, q_commission,
           r_client, r_venue, r_starts, r_ends
      FROM public.quotes q
      JOIN public.quote_requests qr ON qr.id = q.quote_request_id
     WHERE q.id = NEW.quote_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Cannot create a booking: quote % does not exist.',
        NEW.quote_id USING ERRCODE = '23503';
    END IF;

    IF q_status <> 'accepted'::quotation_status THEN
      RAISE EXCEPTION
        'A booking requires an accepted quote (quote % is %).',
        NEW.quote_id, q_status
        USING ERRCODE = '42501';
    END IF;

    -- Read from the agreement, not from the caller. Previously a booking
    -- could cite one quote and name a different talent.
    NEW.talent_id      := q_talent;
    NEW.client_user_id := r_client;
    NEW.venue_id       := r_venue;
    NEW.starts_at      := r_starts;
    NEW.ends_at        := r_ends;

    -- These two are identical under both the markup and deduction commission
    -- models - base plus fees, and 21% of that. Only the DIRECTION differs,
    -- and direction affects only client_total_amount and talent_net_amount,
    -- which are deliberately left alone pending the decision with Erich
    -- (see the commission/VAT naming task).
    NEW.agreed_gross_amount := q_gross;
    NEW.commission_amount   := q_commission;

    NEW.created_at := now();
    RETURN NEW;
  END IF;

  -- Provenance is immutable for every caller, service_role included. The
  -- agreement it derives from cannot change, so neither can these.
  NEW.id                  := OLD.id;
  NEW.quote_id            := OLD.quote_id;
  NEW.client_user_id      := OLD.client_user_id;
  NEW.talent_id           := OLD.talent_id;
  NEW.venue_id            := OLD.venue_id;
  NEW.starts_at           := OLD.starts_at;
  NEW.ends_at             := OLD.ends_at;
  NEW.agreed_gross_amount := OLD.agreed_gross_amount;
  NEW.commission_amount   := OLD.commission_amount;
  NEW.created_at          := OLD.created_at;

  RETURN NEW;
END;
$function$;

-- Sorts before trg_enforce_booking_status_transition, which guards
-- booking_status separately and is left untouched.
DROP TRIGGER IF EXISTS enforce_booking_provenance ON public.bookings;
CREATE TRIGGER enforce_booking_provenance
  BEFORE INSERT OR UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.enforce_booking_provenance();

COMMENT ON FUNCTION public.enforce_booking_provenance() IS
  'Derives a booking''s parties, times, agreed_gross_amount and '
  'commission_amount from its accepted quote, and freezes them for all '
  'callers. Refuses a booking whose quote is missing or not accepted. '
  'client_total_amount and talent_net_amount are NOT derived - they depend '
  'on the unresolved commission direction.';

COMMENT ON COLUMN public.bookings.quote_id IS
  'Required. Every booking derives from exactly one accepted quote, enforced '
  'by enforce_booking_provenance() and a unique constraint. No admin '
  'exception - decided 2026-09-02.';
