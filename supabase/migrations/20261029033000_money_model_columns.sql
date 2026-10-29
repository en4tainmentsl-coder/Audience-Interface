-- Stage 2A of the money model rework: ADDITIVE ONLY.
--
-- Adds the columns the reworked pricing model needs. Changes NO behaviour:
-- no function is rewritten, no column is dropped or renamed, and nothing
-- reads these columns yet. The pricing rewrite lands separately.

-- quotes ---------------------------------------------------------------

alter table public.quotes
  add column commission_talent_rate_percent numeric(5,2)  not null default 0.00,
  add column commission_talent_amount       numeric(12,2)          default 0.00,
  add column tax_base_amount                numeric(12,2)          default 0.00,
  add column meals_fee                      numeric(12,2)          default 0.00,
  add column accommodation_fee              numeric(12,2)          default 0.00;

comment on column public.quotes.commission_talent_rate_percent is
  'Talent-side commission rate, DEDUCTED from the talent fee only -- not added to the client bill. Charged on quoted_amount, not on the grossed-up client price: on a fee of 100 the talent receives 90 and the platform takes 20 in total, not 21.';

comment on column public.quotes.commission_talent_amount is
  'Talent-side commission in rupees. Never add this to the client bill -- it is money moving out of the talent payout, already inside the client total.';

comment on column public.quotes.tax_base_amount is
  'The amount SSCL and VAT are charged on. Per the taxation consultant (2026-10-26) this is the ENTIRE client invoice: talent fee + travel + meals + accommodation + client-side commission. Held separately from base_amount, which means payout + commission and is not the same figure.';

comment on column public.quotes.meals_fee is
  'Talent-entered meals fee. Unlocks above the configured distance threshold. Reaches the talent whole -- no commission is deducted from it.';

comment on column public.quotes.accommodation_fee is
  'Talent-entered accommodation fee. Unlocks above the configured distance threshold. Reaches the talent whole.';

-- bookings -------------------------------------------------------------

alter table public.bookings
  add column gateway_fee_absorbed_amount numeric(12,2) not null default 0.00;

comment on column public.bookings.gateway_fee_absorbed_amount is
  'What En4 absorbed on a TALENT-initiated cancellation. The client is refunded in full and the gateway does not return its fee, so En4 bears it and recovers nothing from the talent (D-008, 2026-10-25). Zero on every other cancellation type, where the client bears it. Exists so the cost of talent cancellations is a number rather than something reconstructed from refunds.';

-- quote_requests -------------------------------------------------------
-- Disclosure only. The client declares the SITUATION, never an amount, and
-- these have NO pricing effect. They exist because D-025 leaves no
-- communication channel at quote-request stage, so the talent would
-- otherwise be quoting blind on what the venue provides.
-- NULL means not declared -- existing rows were never asked.

alter table public.quote_requests
  add column sound_provided  boolean,
  add column lights_provided boolean,
  add column meals_provided  boolean;

comment on column public.quote_requests.sound_provided is
  'Client-declared: does the venue provide sound? Disclosure only, no pricing effect. NULL = not declared.';

comment on column public.quote_requests.lights_provided is
  'Client-declared: does the venue provide lights? Disclosure only, no pricing effect. NULL = not declared.';

comment on column public.quote_requests.meals_provided is
  'Client-declared: will meals be provided at the venue? Disclosure only, no pricing effect -- it does NOT suppress the talent meals_fee. Informs the talent before they quote.';
