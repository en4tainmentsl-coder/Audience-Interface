-- Rate configuration layer (D-044).
-- Append-only, effective-dated platform pricing configuration.
--
-- NOTHING READS THIS TABLE YET. The pricing functions are repointed in a
-- later migration so that the behaviour change -- two-sided commission,
-- Rs 150/km travel, equipment removal -- lands in one place rather than
-- being spread across two deployments.

create table public.rate_configs (
  id                             uuid primary key default gen_random_uuid(),
  effective_from                 timestamptz not null unique,

  -- Two legs, independently settable. The client leg is ADDED to the client
  -- bill on the full talent bill; the talent leg is DEDUCTED from the talent
  -- fee only.
  commission_client_rate_percent numeric(6,3) not null,
  commission_talent_rate_percent numeric(6,3) not null,

  travel_rate_per_km             numeric(10,2) not null,
  travel_free_threshold_km       numeric(6,2)  not null,
  travel_fallback_percent        numeric(6,3)  not null,

  -- Distance gates for the talent-entered meals and accommodation fees.
  meals_threshold_km             numeric(6,2)  not null,
  accommodation_threshold_km     numeric(6,2)  not null,

  sscl_rate_percent              numeric(6,3) not null,
  vat_rate_percent               numeric(6,3) not null,
  gateway_rate_percent           numeric(6,3) not null,

  note                           text,
  created_at                     timestamptz not null default now(),

  constraint rate_configs_note_len
    check (note is null or char_length(note) <= 500),

  constraint rate_configs_percents_sane
    check (commission_client_rate_percent >= 0 and commission_client_rate_percent < 100
       and commission_talent_rate_percent >= 0 and commission_talent_rate_percent < 100
       and sscl_rate_percent              >= 0 and sscl_rate_percent              < 100
       and vat_rate_percent               >= 0 and vat_rate_percent               < 100
       and travel_fallback_percent        >= 0 and travel_fallback_percent        < 100),

  -- Load-bearing: the gateway gross-up divides by (1 - rate/100).
  constraint rate_configs_gateway_below_100
    check (gateway_rate_percent >= 0 and gateway_rate_percent < 100),

  constraint rate_configs_distances_sane
    check (travel_rate_per_km           >= 0
       and travel_free_threshold_km     >= 0
       and meals_threshold_km           >= 0
       and accommodation_threshold_km   >= meals_threshold_km)
);

comment on table public.rate_configs is
  'Append-only platform rate configuration. Amend by inserting a new row with a later effective_from, never by updating an existing row -- a quote snapshot is only preserved if the row it points at can never change.';

-- Append-only guard, mirroring price_ranges_append_only().
create function public.rate_configs_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception
    'rate_configs is append-only: insert a new row with a later effective_from instead of % on %',
    TG_OP, TG_TABLE_NAME;
end;
$$;

create trigger rate_configs_no_mutate
  before delete or update on public.rate_configs
  for each row execute function public.rate_configs_append_only();

-- Resolver. Returns the WHOLE row, not just the id, because the pricing
-- functions need the rate values and cannot read the table directly.
-- SECURITY DEFINER for that reason; EXECUTE is revoked from public so the
-- rates are not readable by an authenticated caller through this door.
create function public.rate_config_at(p_at timestamptz)
returns public.rate_configs
language sql
stable
security definer
set search_path = public
as $$
  select c.*
    from public.rate_configs c
   where c.effective_from <= p_at
   order by c.effective_from desc
   limit 1;
$$;

alter table public.rate_configs enable row level security;

revoke all on table public.rate_configs from anon, authenticated;
grant select, insert on table public.rate_configs to service_role;

create policy rate_configs_service on public.rate_configs
  for all to service_role using (true) with check (true);

revoke all on function public.rate_configs_append_only() from public;
revoke all on function public.rate_config_at(timestamptz) from public;
grant execute on function public.rate_config_at(timestamptz) to service_role;

-- Seed. Carries the DECIDED values, not the currently live ones, because
-- nothing reads this table until the pricing functions are repointed.
-- Backdated so every existing and future quote resolves it.
insert into public.rate_configs (
  effective_from,
  commission_client_rate_percent, commission_talent_rate_percent,
  travel_rate_per_km, travel_free_threshold_km, travel_fallback_percent,
  meals_threshold_km, accommodation_threshold_km,
  sscl_rate_percent, vat_rate_percent, gateway_rate_percent,
  note
) values (
  '2026-01-01T00:00:00Z',
  10.000, 10.000,
  150.00, 10.00, 7.500,
  100.00, 150.00,
  0.000, 0.000, 3.300,
  'Initial configuration. Two-sided commission at 10/10, travel Rs 150/km, tax dormant. Not yet read by any function.'
);
