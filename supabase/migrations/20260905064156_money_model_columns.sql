-- Canonical money model. Decisions recorded in Todoist 6hQpgHxVX8GMh3fX,
-- settled 2026-09-05.
--
--   base_amount          = talent_fee + travel_fee + equipment_fee + commission
--   client_total_amount  = base_amount + sscl + vat + gateway_fee
--   talent_payout_amount = talent_fee + travel_fee + equipment_fee
--
-- Commission is 21% of the PERFORMANCE FEE ONLY (not travel, not equipment).
-- Markup model: the talent receives all three of their components in full.
-- SSCL applies to base, then VAT to the SSCL-inclusive figure, then the
-- PayHere fee is grossed up by DIVISION (subtotal / 0.967), never x1.033.
--
-- bank_charge_amount (HNB Rs.25) is retained as a column for reconciliation
-- but is ABSORBED BY EN4 and appears in none of the equations above.
--
-- Rates are pinned per row: VAT was 15% before 2024 and SSCL rates move.
-- Historical rows must reconcile against the rate in force at the time.

-- ---------------------------------------------------------------
-- quotes: rename + pricing breakdown
-- ---------------------------------------------------------------

ALTER TABLE public.quotes
  RENAME COLUMN talent_net_earnings TO talent_payout_amount;

ALTER TABLE public.quotes
  ADD COLUMN base_amount          numeric(12,2),
  ADD COLUMN sscl_rate_percent    numeric(5,2) NOT NULL DEFAULT 2.50,
  ADD COLUMN sscl_amount          numeric(12,2),
  ADD COLUMN vat_rate_percent     numeric(5,2) NOT NULL DEFAULT 18.00,
  ADD COLUMN vat_amount           numeric(12,2),
  ADD COLUMN gateway_rate_percent numeric(5,2) NOT NULL DEFAULT 3.30,
  ADD COLUMN gateway_fee_amount   numeric(12,2);

-- Left nullable deliberately: the pricing function does not exist yet.
-- Tighten to NOT NULL in the migration that ships it.

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_rates_valid CHECK (
    sscl_rate_percent    BETWEEN 0 AND 100 AND
    vat_rate_percent     BETWEEN 0 AND 100 AND
    gateway_rate_percent BETWEEN 0 AND 100
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
  ADD CONSTRAINT quotes_payout_adds_up CHECK (
    talent_payout_amount IS NULL
    OR talent_payout_amount = quoted_amount
                            + COALESCE(travel_fee, 0)
                            + COALESCE(equipment_fee, 0)
  );

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_total_adds_up CHECK (
    total_client_price IS NULL
    OR total_client_price = base_amount + sscl_amount + vat_amount + gateway_fee_amount
  );

-- ---------------------------------------------------------------
-- bookings: type fixes
-- ---------------------------------------------------------------
-- These four were unconstrained numeric while every other money column
-- was numeric(12,2). Dividing by 0.967 would have stored unrounded
-- values such as 163851.602895553 in the ledger.

ALTER TABLE public.bookings
  ALTER COLUMN agreed_gross_amount TYPE numeric(12,2),
  ALTER COLUMN commission_amount   TYPE numeric(12,2),
  ALTER COLUMN talent_net_amount   TYPE numeric(12,2),
  ALTER COLUMN deposit_amount      TYPE numeric(12,2);

-- ---------------------------------------------------------------
-- bookings: drop the superseded adds-up check
-- ---------------------------------------------------------------
-- The old constraint encoded a different model. It put bank_charge_amount
-- inside the client total, and added commission separately to gross, which
-- would double-count once base_amount includes commission.

ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_total_adds_up_check;

-- ---------------------------------------------------------------
-- bookings: renames
-- ---------------------------------------------------------------
-- talent_net_amount nets nothing off under markup; it is the full payout.
-- agreed_gross_amount is the pre-tax base SSCL is computed on, not a gross.

ALTER TABLE public.bookings RENAME COLUMN talent_net_amount   TO talent_payout_amount;
ALTER TABLE public.bookings RENAME COLUMN agreed_gross_amount TO base_amount;

ALTER TABLE public.bookings RENAME CONSTRAINT chk_booking_gross_positive TO chk_booking_base_positive;
ALTER TABLE public.bookings RENAME CONSTRAINT chk_booking_net_positive   TO chk_booking_payout_positive;

-- ---------------------------------------------------------------
-- bookings: breakdown snapshot + rate pins
-- ---------------------------------------------------------------
-- Snapshotted rather than joined from quotes so a later quote amendment
-- cannot rewrite what was agreed. Also required by the cancellation
-- formula, which takes 20% of each talent component separately.

ALTER TABLE public.bookings
  ADD COLUMN talent_fee_amount       numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN travel_fee_amount       numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN equipment_fee_amount    numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN commission_rate_percent numeric(5,2),
  ADD COLUMN sscl_rate_percent       numeric(5,2),
  ADD COLUMN vat_rate_percent        numeric(5,2),
  ADD COLUMN gateway_rate_percent    numeric(5,2);

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_base_adds_up CHECK (
    base_amount = 0.00
    OR base_amount = talent_fee_amount
                   + travel_fee_amount
                   + equipment_fee_amount
                   + commission_amount
  );

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_payout_adds_up CHECK (
    talent_payout_amount IS NULL
    OR talent_payout_amount = talent_fee_amount
                            + travel_fee_amount
                            + equipment_fee_amount
  );

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_total_adds_up CHECK (
    client_total_amount = 0.00
    OR client_total_amount = base_amount + sscl_amount + vat_amount + gateway_fee_amount
  );
