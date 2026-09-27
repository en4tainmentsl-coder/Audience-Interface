-- 20260927183713_rate_model_submission_gate_and_request_snapshot.sql
--
-- Moves the two trigger reads of profiles_talent.pricing_per_session onto
-- talent_rates. D-038, D-046. Requires 20260927164332.
--
-- Three functions read the old column. After this, only enforce_pricing_cooldown
-- does, and that one dies with the column.
--
-- 1. check_talent_pricing_before_submission
--    Was: a starting rate is required. Now: at least one category rate is set.
--
--    On INSERT the check cannot be expressed, because talent_rates rows are
--    seeded by an AFTER INSERT trigger and so do not exist yet when this BEFORE
--    trigger runs. Rather than let that surface as a confusing "set at least one
--    rate" error on a profile that has no rate rows at all, INSERT with a
--    submitted status gets its own message. The column defaults to 'draft', so
--    the normal path - create draft, set rates, submit - is unaffected.
--
-- 2. set_talent_rate_at_request
--    Was: snapshot profiles_talent.pricing_per_session. Now: snapshot the rate
--    for the REQUESTED EVENT TYPE, via rate_category_for_event_type.
--
--    A NULL amount means the talent has not opted into that category. The
--    client-facing picker filters those talent out, so the exception here is a
--    backstop for a hand-crafted insert through PostgREST - clients hold INSERT
--    on quote_requests, so the picker cannot be the only enforcement.
--
--    Without it the NULL snapshot flows into enforce_quote_writes, which
--    multiplies it into quoted_amount and fails as a NOT NULL violation: the
--    wrong error, in the wrong place, shown to a client who did nothing wrong.
--
--    The message names no number. It is read by a client, and a talent's rate
--    is not published to anyone (D-046).
--
-- VERIFIED BEHAVIOURALLY in a rolled-back transaction, not just by reading:
--   wedding for a talent with no wedding rate -> refused, correct message
--   corporate -> special_events -> accepted, snapshot 5000.00
--   submit with every rate NULL             -> refused, correct message
--   fixtures unchanged afterwards

begin;

create or replace function public.check_talent_pricing_before_submission()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  transitioning boolean;
  rates_set     integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    transitioning := true;
  ELSE
    transitioning := NEW.approval_status IS DISTINCT FROM OLD.approval_status;
  END IF;

  IF NOT transitioning
     OR NEW.approval_status NOT IN ('pending_approval', 'approved') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'A talent profile is created as a draft. Set at least one category rate, then submit it for approval.'
      USING ERRCODE = '23514';
  END IF;

  SELECT count(*) INTO rates_set
    FROM public.talent_rates
   WHERE talent_id = NEW.id
     AND amount IS NOT NULL;

  IF rates_set = 0 THEN
    RAISE EXCEPTION 'Set a rate for at least one event category before submitting your profile for approval.'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

create or replace function public.set_talent_rate_at_request()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_category public.rate_category;
begin
  if TG_OP = 'INSERT' then
    v_category := public.rate_category_for_event_type(new.event_type);

    select tr.amount
      into new.talent_rate_at_request
      from public.talent_rates tr
     where tr.talent_id = new.talent_id
       and tr.category  = v_category;

    if new.talent_rate_at_request is null then
      raise exception 'This performer is not available for % bookings.',
        replace(new.event_type::text, '_', ' ')
        using errcode = '23514';
    end if;
  else
    -- Immutable after creation. Protects in-flight requests from later rate
    -- changes, and stops the client rewriting it through the FOR ALL policy.
    new.talent_rate_at_request := old.talent_rate_at_request;
  end if;
  return new;
end;
$function$;

comment on function public.set_talent_rate_at_request() is
  'Snapshots the talent rate for the requested event type onto the quote request (D-038). Reads talent_rates via rate_category_for_event_type, not the legacy profiles_talent.pricing_per_session. Refuses the request when the talent has no rate for that category.';

commit;