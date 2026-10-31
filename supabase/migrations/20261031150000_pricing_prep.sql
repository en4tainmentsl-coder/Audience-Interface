-- Stage 2C-1: preparation for the pricing rewrite. ADDITIVE ONLY.
--
-- Widens the rate snapshot columns and adds the rate_configs FK.
-- No function is rewritten and nothing is dropped. Behaviour unchanged.

-- Rates are stored in rate_configs as numeric(6,3). The snapshot columns
-- here were numeric(5,2), so a fractional rate such as 7.125 would round to
-- 7.13 on snapshot and the stored rate would no longer reproduce the stored
-- amount. Harmless at the current 10.000 and 3.300; a silent reconciliation
-- defect the first time a rate is not a round figure.

alter table public.quotes
  alter column commission_rate_percent        type numeric(6,3),
  alter column commission_talent_rate_percent type numeric(6,3),
  alter column sscl_rate_percent              type numeric(6,3),
  alter column vat_rate_percent               type numeric(6,3),
  alter column gateway_rate_percent           type numeric(6,3);

-- Which configuration row priced this quote. Nullable: existing quotes were
-- priced before the config layer existed, and backfilling them would assert
-- a provenance that is not true. RESTRICT because rate_configs is
-- append-only -- a referenced row must never disappear.

alter table public.quotes
  add column rate_config_id uuid references public.rate_configs(id) on delete restrict;

comment on column public.quotes.rate_config_id is
  'The rate_configs row this quote was priced from. NULL on quotes priced before the config layer existed. The numeric rate columns remain the authoritative snapshot -- this FK records provenance, not the rates themselves.';
