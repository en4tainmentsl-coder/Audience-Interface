-- Quote acceptance orchestration. Todoist 6hPq7j7jFhF6Xx65.
--
-- Acceptance is three writes that must succeed or fail together:
--   1. quote     -> accepted
--   2. bookings  <- INSERT (enforce_booking_provenance derives everything)
--   3. request   -> converted
--
-- Order matters: enforce_quote_writes refuses acceptance unless the parent
-- request is still open or matched, so the request is converted LAST.
--
-- Doing this from an Edge Function as separate PostgREST calls would make
-- each write its own transaction. A failure after step 1 would leave an
-- accepted quote with no booking, and the request could no longer be
-- accepted because the quote is no longer pending. Wedged, needing manual
-- repair. A single function is one transaction.
--
-- Praveen 2026-09-05: a quote request can only ever have ONE quote. The
-- schema did not enforce that, so the unique constraint is added here.
-- It also removes any need to expire sibling quotes on acceptance --
-- note cascade_quote_request_close does NOT fire for 'converted'.

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_one_per_request UNIQUE (quote_request_id);

CREATE OR REPLACE FUNCTION public.accept_quote_and_create_booking(
  p_quote_id        uuid,
  p_client_user_id  uuid,
  p_message         text DEFAULT NULL
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_request_id uuid;
  v_client     uuid;
  v_req_status quotation_request_status;
  v_status     quotation_status;
  v_expires    timestamptz;
  v_booking_id uuid;
BEGIN
  -- Lock the quote for the duration of the transaction so two concurrent
  -- acceptances cannot both pass the status check.
  SELECT q.quote_request_id, q.quote_status, q.expires_at
    INTO v_request_id, v_status, v_expires
    FROM public.quotes q
   WHERE q.id = p_quote_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote % does not exist.', p_quote_id
      USING ERRCODE = '23503';
  END IF;

  SELECT qr.client_user_id, qr.status
    INTO v_client, v_req_status
    FROM public.quote_requests qr
   WHERE qr.id = v_request_id
   FOR UPDATE;

  -- Authorisation: only the client who raised the request may accept.
  IF v_client IS DISTINCT FROM p_client_user_id THEN
    RAISE EXCEPTION 'Only the client who made this request can accept the quote.'
      USING ERRCODE = '42501';
  END IF;

  IF v_status <> 'pending'::quotation_status THEN
    RAISE EXCEPTION 'This quote is % and can no longer be accepted.', v_status
      USING ERRCODE = '42501';
  END IF;

  IF v_expires <= now() THEN
    RAISE EXCEPTION 'This quote expired on %.', v_expires
      USING ERRCODE = '42501';
  END IF;

  IF v_req_status NOT IN ('open'::quotation_request_status,
                          'matched'::quotation_request_status) THEN
    RAISE EXCEPTION 'This request is % and is no longer live.', v_req_status
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.quotes
     SET quote_status = 'accepted'::quotation_status
   WHERE id = p_quote_id;

  INSERT INTO public.bookings (quote_id, message_to_talent)
  VALUES (p_quote_id, p_message)
  RETURNING id INTO v_booking_id;

  UPDATE public.quote_requests
     SET status = 'converted'::quotation_request_status
   WHERE id = v_request_id;

  RETURN v_booking_id;
END;
$function$;

-- service_role only. This function bypasses RLS by design, so it must not
-- be reachable by an authenticated user directly -- the Edge Function
-- authenticates the caller and passes the verified user id.
REVOKE ALL ON FUNCTION public.accept_quote_and_create_booking(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.accept_quote_and_create_booking(uuid, uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.accept_quote_and_create_booking(uuid, uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.accept_quote_and_create_booking(uuid, uuid, text) TO service_role;
