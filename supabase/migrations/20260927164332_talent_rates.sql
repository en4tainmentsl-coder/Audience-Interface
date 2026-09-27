-- 20260927164332_talent_rates.sql
--
-- Per-category talent fees. D-038 (eight categories), D-046 (rate visibility).
-- Requires 20260927162423, which added club_pub and spot_performance - a new
-- enum value cannot be used in the transaction that adds it.
--
-- EIGHT CATEGORIES, TEN EVENT TYPES
-- ---------------------------------
-- 'special_events' is ONE fee covering corporate, birthday and private. That is
-- why rate_category is its own enum rather than reusing events_type: keying
-- rates by event type would mean three rows holding the same number, which have
-- to be kept in step, and "one fee replicated" is how sync bugs start.
--
-- rate_category_for_event_type() is the single place the mapping lives.
-- Verified after applying: all 10 event types map; none returns NULL.
--
-- EIGHT ROWS ALWAYS, AND amount IS NULLABLE - THIS IS THE COOLDOWN
-- ----------------------------------------------------------------
-- NULL amount means "I do not do this work". Rows are seeded on profile
-- creation and never inserted or deleted by a talent - `authenticated` holds
-- SELECT and UPDATE only.
--
-- If absence meant "does not do this work", opting out and back in would reset
-- the 30-day cooldown and the cooldown would be decorative: a talent wanting to
-- raise a wedding fee inside 30 days would delete the row and re-add it. With
-- permanent rows, `NEW.amount IS DISTINCT FROM OLD.amount` catches value->value,
-- value->NULL and NULL->value alike, so clearing a rate costs 30 days exactly
-- like changing one. The bypass closes structurally, not by another guard.
--
-- The cooldown only fires for caller_role = 'talent', mirroring
-- enforce_pricing_cooldown: an admin correcting a typo must not cost the talent
-- their next 30 days. CONSEQUENCE: service_role and admin bypass it entirely.
-- Any future Edge Function writing rates gets NO cooldown and must not be
-- written as though it does.
--
-- FLOOR OF 1000
-- -------------
-- Matches Range 1 in price_ranges (D-039). A rate below 1000 resolves to no
-- range at all and the talent drops out of every client filter - which reads as
-- a broken search rather than a bad rate. Without this CHECK the floor merely
-- relocates the hole.
--
-- NOT PUBLICLY READABLE (D-046)
-- -----------------------------
-- No anon grant. A talent reads and writes only their own rows. Clients see the
-- range, never the number - publishing rates alongside ranges would let anyone
-- derive the range boundaries exactly by browsing, defeating the rule that
-- talent never see the ranges.
--
-- profiles_talent.pricing_per_session is NOT dropped here. ProfileEditor.tsx
-- still reads and writes it and two triggers reference it. Until the frontend
-- moves and that column goes, anon SELECT on profiles_talent still exposes
-- every talent's rate through PostgREST - see the Standing Correction.
--
-- KNOWN WART: talent_rates_admin is `for all to authenticated`, which appears to
-- let an admin DELETE. `authenticated` holds no DELETE grant, so the policy has
-- nothing to permit and it is inert - but it reads wrongly. Tighten when next
-- touched.
--
-- VERIFIED AFTER APPLYING: 8 rows for each of the 3 talent; old rates migrated
-- to special_events (5,000 / 14,000 / 25,000); all 10 event types mapped; no
-- anon grant; authenticated limited to SELECT and UPDATE; 25,000 resolving
-- through price_range_for_amount to Range 3.

begin;

create type public.rate_category as enum (
  'special_events', 'wedding', 'concert', 'club_pub',
  'dinner_service', 'lunch_service', 'spot_performance', 'other'
);

create table public.talent_rates (
  id              uuid primary key default gen_random_uuid(),
  talent_id       uuid not null references public.profiles_talent(id) on delete cascade,
  category        public.rate_category not null,
  amount          numeric(12,2),
  rate_updated_at timestamptz,
  created_at      timestamptz not null default now(),

  constraint talent_rates_amount_floor
    check (amount is null or amount >= 1000),
  constraint talent_rates_amount_ceiling
    check (amount is null or amount <= 10000000),
  constraint talent_rates_one_per_category unique (talent_id, category)
);

create index talent_rates_category_amount_idx
  on public.talent_rates (category, amount) where amount is not null;

create or replace function public.rate_category_for_event_type(p_event public.events_type)
returns public.rate_category
language sql immutable strict set search_path to 'public' as $$
  select (case p_event
    when 'corporate'        then 'special_events'
    when 'birthday'         then 'special_events'
    when 'private'          then 'special_events'
    when 'wedding'          then 'wedding'
    when 'concert'          then 'concert'
    when 'club_pub'         then 'club_pub'
    when 'dinner_service'   then 'dinner_service'
    when 'lunch_service'    then 'lunch_service'
    when 'spot_performance' then 'spot_performance'
    when 'other'            then 'other'
  end)::public.rate_category
$$;

create or replace function public.seed_talent_rate_rows()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.talent_rates (talent_id, category)
  select NEW.id, c
    from unnest(enum_range(null::public.rate_category)) as c
  on conflict (talent_id, category) do nothing;
  return NEW;
end;
$$;

create trigger talent_rates_seed
  after insert on public.profiles_talent
  for each row execute function public.seed_talent_rate_rows();

create or replace function public.enforce_talent_rate_cooldown()
returns trigger language plpgsql set search_path to 'public' as $$
declare caller_role text := public.get_my_role();
begin
  if NEW.amount is distinct from OLD.amount then
    if caller_role = 'talent' then
      if OLD.rate_updated_at is not null
         and OLD.rate_updated_at > now() - interval '30 days' then
        raise exception 'Your % rate can only be changed once every 30 days. Next change available %.',
          replace(OLD.category::text, '_', ' '),
          to_char(OLD.rate_updated_at + interval '30 days', 'DD Mon YYYY')
          using errcode = '23514';
      end if;
      NEW.rate_updated_at := now();
    end if;
  end if;
  return NEW;
end;
$$;

create trigger a_talent_rates_cooldown
  before update on public.talent_rates
  for each row execute function public.enforce_talent_rate_cooldown();

create or replace function public.enforce_talent_rate_immutable()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  NEW.id         := OLD.id;
  NEW.talent_id  := OLD.talent_id;
  NEW.category   := OLD.category;
  NEW.created_at := OLD.created_at;
  return NEW;
end;
$$;

create trigger a0_talent_rates_pin
  before update on public.talent_rates
  for each row execute function public.enforce_talent_rate_immutable();

alter table public.talent_rates enable row level security;
alter table public.talent_rates force row level security;

revoke all on public.talent_rates from public, anon, authenticated;
grant select, update on public.talent_rates to authenticated;

create policy talent_rates_own_select on public.talent_rates
  for select to authenticated
  using (talent_id in (select id from public.profiles_talent where user_id = auth.uid()));

create policy talent_rates_own_update on public.talent_rates
  for update to authenticated
  using (talent_id in (select id from public.profiles_talent where user_id = auth.uid()))
  with check (talent_id in (select id from public.profiles_talent where user_id = auth.uid()));

create policy talent_rates_admin on public.talent_rates
  for all to authenticated
  using (public.get_my_role() = 'admin')
  with check (public.get_my_role() = 'admin');

create policy talent_rates_service on public.talent_rates
  for all to service_role using (true) with check (true);

-- Backfill for profiles that existed before the seed trigger.
insert into public.talent_rates (talent_id, category)
select t.id, c
  from public.profiles_talent t,
       unnest(enum_range(null::public.rate_category)) as c
on conflict (talent_id, category) do nothing;

-- The single general rate becomes the special_events rate; the other seven stay
-- NULL. Keeps the three fixtures submittable under the "at least one category"
-- rule without inventing numbers for categories nobody set.
update public.talent_rates r
   set amount = t.pricing_per_session,
       rate_updated_at = coalesce(t.pricing_updated_at, now())
  from public.profiles_talent t
 where r.talent_id = t.id
   and r.category = 'special_events'
   and t.pricing_per_session is not null;

comment on table public.talent_rates is
  'Per-category talent fees (D-038). Eight rows per talent, always present; a NULL amount means the talent does not do that work. Rows are never inserted or deleted by a talent - only updated - so opting out and back in cannot reset the 30-day per-category cooldown. NOT readable by anon, and readable by authenticated only for their own rows (D-046).';

comment on column public.talent_rates.amount is
  'NULL means the talent does not do this category. Floor of 1000 matches price_ranges Range 1; anything lower would resolve to no range and drop the talent out of every client filter.';

commit;