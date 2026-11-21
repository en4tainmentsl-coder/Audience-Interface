-- Stage 2C-2a: mirror the quote-side money columns onto bookings.
-- ADDITIVE ONLY. No function rewritten, nothing dropped or renamed.
--
-- enforce_booking_provenance copies every money column from the accepted
-- quote. Stage 2A added meals, accommodation and the talent commission leg
-- to quotes but not here, so the booking side must catch up BEFORE the
-- pricing rewrite -- otherwise accepting a quote would silently drop those
-- amounts or fail on insert.

alter table public.bookings
  add column meals_fee_amount               numeric(12,2) not null default 0.00,
  add column accommodation_fee_amount       numeric(12,2) not null default 0.00,
  add column commission_talent_rate_percent numeric(6,3)  not null default 0.000,
  add column commission_talent_amount       numeric(12,2) not null default 0.00;

comment on column public.bookings.meals_fee_amount is
  'Copied from the accepted quote. Reaches the talent whole -- no commission is deducted from it.';

comment on column public.bookings.accommodation_fee_amount is
  'Copied from the accepted quote. Reaches the talent whole.';

comment on column public.bookings.commission_talent_rate_percent is
  'Talent-side commission rate, copied from the accepted quote. DEDUCTED from the talent payout, never added to the client total.';

comment on column public.bookings.commission_talent_amount is
  'Talent-side commission in rupees, copied from the accepted quote. Already inside client_total_amount -- never add it on top.';

-- Match the widening applied to quotes in 20261031150000. rate_configs
-- stores rates as numeric(6,3); a booking snapshot at (5,2) would round a
-- fractional rate and stop reproducing its own amounts.

alter table public.bookings
  alter column commission_rate_percent type numeric(6,3),
  alter column sscl_rate_percent       type numeric(6,3),
  alter column vat_rate_percent        type numeric(6,3),
  alter column gateway_rate_percent    type numeric(6,3);
