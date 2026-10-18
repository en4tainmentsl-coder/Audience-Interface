-- The talent's 48-hour window to quote or decline (settled by Praveen
-- 2026-10-04). Distinct from quotes.expires_at, which is the CLIENT's window to
-- accept a quote once made. Two clocks, different owners.
--
-- The expression mirrors set_quote_expiry deliberately: a window, clamped
-- against the event, floored so it can never already be past.
--
-- Minimum lead time of 120 hours (settled 2026-10-18) is what makes the clamp a
-- safety net rather than routine behaviour: 48h for the talent plus the 72h
-- pre-event clamp on quotes.expires_at means a request made any closer cannot
-- give both sides a full window. Without the block, a request made 100 hours
-- out leaves the client roughly two hours to accept a quote for an event three
-- days away.

alter table public.quote_requests
  add column responds_by timestamptz;

update public.quote_requests
   set responds_by = greatest(
         now() + interval '2 hours',
         least(created_at + interval '48 hours',
               starts_at  - interval '72 hours')
       )
 where responds_by is null;

alter table public.quote_requests
  alter column responds_by set not null;

comment on column public.quote_requests.responds_by is
  'Deadline for the talent to quote or decline. Set on insert, never by the client. The hourly expiry job flips open -> expired once this passes.';

CREATE OR REPLACE FUNCTION public.set_request_responds_by()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  caller_role text;
BEGIN
  -- Minimum lead time. Skipped for admins and for unauthenticated callers
  -- (service_role, pg_cron, seeds), mirroring enforce_quote_request_writes.
  IF auth.uid() IS NOT NULL THEN
    caller_role := get_my_role();
    IF caller_role <> 'admin'
       AND NEW.starts_at < now() + interval '120 hours' THEN
      RAISE EXCEPTION
        'Requests must be made at least 5 days before the event. This event starts %.',
        to_char(NEW.starts_at, 'DD Mon YYYY at HH24:MI')
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- Always derived, never accepted from the caller.
  NEW.responds_by := greatest(
    now() + interval '2 hours',
    least(coalesce(NEW.created_at, now()) + interval '48 hours',
          NEW.starts_at - interval '72 hours')
  );

  RETURN NEW;
END;
$function$;

CREATE TRIGGER quote_requests_set_responds_by
BEFORE INSERT ON public.quote_requests
FOR EACH ROW EXECUTE FUNCTION public.set_request_responds_by();
