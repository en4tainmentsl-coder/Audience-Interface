-- Hourly job flipping open quote requests to expired once responds_by passes.
-- Cadence settled 2026-10-18: daily would turn a 48-hour deadline into
-- "somewhere between 48 and 72", which is not what was agreed.
--
-- Why status = 'open' alone is the right filter: since 20261018115132, a
-- request moves to 'matched' the moment a talent submits a quote. So 'open'
-- means "no quote yet", which is exactly what the talent response deadline
-- governs. Requests already quoted are out of scope here — the client's own
-- window is quotes.expires_at.
--
-- The quotes side needs no handling: cascade_quote_request_close already flips
-- pending quotes to expired when a request closes. There are none on an open
-- request by definition, but the cascade stays correct if that ever changes.
--
-- enforce_quote_request_writes returns early when auth.uid() IS NULL, so this
-- job is unconstrained by it. The WHERE clause below is the only control on
-- what it touches — keep it narrow.

CREATE OR REPLACE FUNCTION public.expire_quote_requests()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  n integer;
BEGIN
  UPDATE public.quote_requests
     SET status = 'expired'::quotation_request_status
   WHERE status = 'open'::quotation_request_status
     AND responds_by < now();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$function$;

REVOKE ALL ON FUNCTION public.expire_quote_requests() FROM PUBLIC, anon, authenticated;

SELECT cron.schedule(
  'expire-quote-requests',
  '5 * * * *',
  $cron$select public.expire_quote_requests();$cron$
);
