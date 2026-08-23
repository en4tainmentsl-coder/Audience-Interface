-- Applied via Supabase SQL Editor 2026-08-23 (4a and 4b).
--
-- 4a: performer_count (catering headcount), equipment_provided_by
-- (talent by default; large halls and outdoor events need a rig the talent
-- cannot supply), setup_arrival_at (varies by rig; platform rule is ready
-- 60-90 min before start), and talent_rate_at_request -- a snapshot of the
-- Starting Rate so a later rate change cannot move the goalposts on an
-- in-flight negotiation.
--
-- Quote expiry: 7 days from sending, never later than 72 hours before the
-- event, floored at 2 hours so genuinely last-minute bookings do not expire
-- on creation.
--
-- 4b: commission_amount, total_client_price and talent_net_earnings were
-- nullable with no default -- whatever the application sent was stored.
-- Now GENERATED ALWAYS, so no client can supply a wrong figure.
--
-- Commission is charged on quoted_amount + travel_fee + equipment_fee, NOT
-- on the base fee alone. Verified: base 85,000 + travel 4,500 + equipment
-- 25,000 yields commission 24,045 vs 17,850 on base only -- 6,195 more per
-- booking, and the gap widens on exactly the jobs where travel and rig hire
-- dominate.
--
-- total_client_price repeats the commission expression rather than
-- referencing commission_amount: Postgres does not allow a generated column
-- to reference another generated column.
--
-- Client-facing breakdown: line 1 talent total, line 2 handling and
-- convenience fee, then government levies at booking (bookings carries
-- vat_amount and sscl_amount), then final total.

-- Equipment responsibility: talent by default, but large halls and outdoor
-- events need a rig the talent cannot be expected to supply.
CREATE TYPE public.equipment_responsibility AS ENUM ('talent', 'venue', 'shared');

ALTER TABLE public.quotes
  ADD COLUMN performer_count       integer,
  ADD COLUMN equipment_provided_by public.equipment_responsibility
                                   NOT NULL DEFAULT 'talent',
  ADD COLUMN equipment_notes       text,
  ADD COLUMN setup_arrival_at      timestamptz;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_performer_count_valid
    CHECK (performer_count IS NULL OR performer_count BETWEEN 1 AND 50);

-- Snapshot the talent's Starting Rate at request time, so a later rate
-- change cannot move the goalposts on an in-flight negotiation.
ALTER TABLE public.quote_requests
  ADD COLUMN talent_rate_at_request numeric(12,2);

-- Quote validity: 7 days from sending, but never later than 72 hours
-- before the event. Floor of 2 hours so genuinely last-minute bookings
-- remain possible rather than expiring on creation.
CREATE OR REPLACE FUNCTION public.set_quote_expiry()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  event_start timestamptz;
BEGIN
  IF NEW.expires_at IS NULL THEN
    SELECT starts_at INTO event_start
    FROM public.quote_requests
    WHERE id = NEW.quote_request_id;

    NEW.expires_at := greatest(
      now() + interval '2 hours',
      least(coalesce(NEW.sent_at, now()) + interval '7 days',
            event_start - interval '72 hours')
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER quotes_set_expiry
  BEFORE INSERT ON public.quotes
  FOR EACH ROW EXECUTE FUNCTION public.set_quote_expiry();

-- Tighten money columns to 2dp
ALTER TABLE public.quotes
  ALTER COLUMN quoted_amount           TYPE numeric(12,2),
  ALTER COLUMN travel_fee              TYPE numeric(12,2),
  ALTER COLUMN equipment_fee           TYPE numeric(12,2),
  ALTER COLUMN commission_rate_percent TYPE numeric(5,2);

-- Rate must always be present; default is 21.00
ALTER TABLE public.quotes
  ALTER COLUMN commission_rate_percent SET NOT NULL;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_amounts_positive
    CHECK (quoted_amount > 0
       AND coalesce(travel_fee, 0)    >= 0
       AND coalesce(equipment_fee, 0) >= 0),
  ADD CONSTRAINT quotes_commission_rate_valid
    CHECK (commission_rate_percent >= 0 AND commission_rate_percent <= 100);

-- Replace app-supplied totals with database-computed ones
ALTER TABLE public.quotes
  DROP COLUMN commission_amount,
  DROP COLUMN total_client_price,
  DROP COLUMN talent_net_earnings;

-- Line 1 on the client's breakdown: everything the talent receives
ALTER TABLE public.quotes
  ADD COLUMN talent_net_earnings numeric(12,2)
    GENERATED ALWAYS AS (
      quoted_amount + coalesce(travel_fee, 0) + coalesce(equipment_fee, 0)
    ) STORED;

-- Line 2: handling and convenience fee, charged on the FULL talent line
-- including travel and equipment, not on the base fee alone.
ALTER TABLE public.quotes
  ADD COLUMN commission_amount numeric(12,2)
    GENERATED ALWAYS AS (
      round((quoted_amount + coalesce(travel_fee, 0) + coalesce(equipment_fee, 0))
            * commission_rate_percent / 100, 2)
    ) STORED;

-- Total before government levies, which are applied at booking
ALTER TABLE public.quotes
  ADD COLUMN total_client_price numeric(12,2)
    GENERATED ALWAYS AS (
      quoted_amount + coalesce(travel_fee, 0) + coalesce(equipment_fee, 0)
      + round((quoted_amount + coalesce(travel_fee, 0) + coalesce(equipment_fee, 0))
              * commission_rate_percent / 100, 2)
    ) STORED;
