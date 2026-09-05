-- talent_payout_amount, commission_amount and total_client_price on quotes
-- were GENERATED ALWAYS columns. Assignments to them from a BEFORE trigger
-- are silently ignored, so compute_quote_pricing could not populate them.
--
-- Their stored expressions also encoded a model that has since been
-- rejected (settled 2026-09-05, Todoist 6hQpgHxVX8GMh3fX):
--
--   commission_amount  = 21% x (quoted + travel + equipment)
--     -> commission must be 21% of the PERFORMANCE FEE ONLY
--
--   total_client_price = payout + commission
--     -> omits SSCL, VAT and the PayHere gateway fee entirely
--
-- A generated column cannot be converted in place, so each is dropped and
-- re-added as a plain column. quotes is at 0 rows, so nothing is lost.
--
-- Dropping commission_amount also drops quotes_base_adds_up, which
-- references it. It is recreated below.

ALTER TABLE public.quotes
  DROP CONSTRAINT IF EXISTS quotes_base_adds_up;

ALTER TABLE public.quotes
  DROP CONSTRAINT IF EXISTS quotes_payout_adds_up;

ALTER TABLE public.quotes
  DROP CONSTRAINT IF EXISTS quotes_total_adds_up;

ALTER TABLE public.quotes
  DROP COLUMN talent_payout_amount,
  DROP COLUMN commission_amount,
  DROP COLUMN total_client_price;

ALTER TABLE public.quotes
  ADD COLUMN talent_payout_amount numeric(12,2),
  ADD COLUMN commission_amount    numeric(12,2),
  ADD COLUMN total_client_price   numeric(12,2);

-- Recreate the invariants against the settled model.

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_payout_adds_up CHECK (
    talent_payout_amount IS NULL
    OR talent_payout_amount = quoted_amount
                            + COALESCE(travel_fee, 0)
                            + COALESCE(equipment_fee, 0)
  );

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_base_adds_up CHECK (
    base_amount IS NULL
    OR base_amount = quoted_amount
                   + COALESCE(travel_fee, 0)
                   + COALESCE(equipment_fee, 0)
                   + commission_amount
  );

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_total_adds_up CHECK (
    total_client_price IS NULL
    OR total_client_price = base_amount + sscl_amount + vat_amount + gateway_fee_amount
  );

COMMENT ON COLUMN public.quotes.commission_amount IS
  'En4 commission: 21% of the performance fee only, never of travel or equipment.';

COMMENT ON COLUMN public.quotes.talent_payout_amount IS
  'Full amount the talent receives: performance + travel + equipment. Markup model, nothing is netted off.';

COMMENT ON COLUMN public.quotes.total_client_price IS
  'What the client pays: base + SSCL + VAT + PayHere, with the gateway fee grossed up by division.';
