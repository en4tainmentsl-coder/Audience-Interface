-- The hourly expiry job left updated_at untouched. updated_at is maintained by
-- enforce_quote_request_writes, which returns early when auth.uid() IS NULL --
-- exactly the path pg_cron takes. So an expired request still reported whatever
-- updated_at it had before, which is a lie about when it last changed.
--
-- Observed in production 2026-10-18: a request expired at 15:05 UTC still read
-- updated_at = 2026-10-13.
--
-- Setting it in the job rather than changing the trigger: the trigger's early
-- return is deliberate and other unauthenticated writers rely on it.

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
     SET status     = 'expired'::quotation_request_status,
         updated_at = now()
   WHERE status = 'open'::quotation_request_status
     AND responds_by < now();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$function$;
