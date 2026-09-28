-- 20260928082832_drop_other_category_and_add_packages.sql
--
-- Removes the 'other' category and adds fixed platform-defined packages.
-- D-038. Settled with Praveen 2026-09-28.
--
-- WHY 'other' GOES
-- ----------------
-- Every other category now has a defined package and a priceable rate. 'other'
-- had neither - and under D-039 it also had no price range, so it was the one
-- category with two carve-outs. A client whose event does not fit picks the
-- nearest; v1 ships these nine event types and v2 can add more on real feedback.
--
-- Done now because it is free: zero quotes, zero bookings, zero quote requests,
-- and the three 'other' rate rows all had NULL amounts. It would be a migration
-- to think hard about once there is data.
--
-- THE ORDER MATTERS, AND THE OBVIOUS ORDER FAILS
-- ----------------------------------------------
-- Postgres cannot drop an enum value, so both types are rename-create-alter-drop.
-- The first attempt failed with:
--
--   cannot drop type rate_category_old because other objects depend on it
--   DETAIL: function rate_category_for_event_type(events_type_old) depends on it
--
-- Enum types appear in function SIGNATURES, so every function taking or
-- returning one pins the old type alive. They must be dropped BEFORE the types,
-- with CASCADE to take their triggers, and recreated after - triggers included.
-- The two triggers are talent_rates_seed on profiles_talent and
-- trg_quote_requests_rate_snapshot on quote_requests.
--
-- rate_category_for_event_type NOW RAISES instead of returning NULL. With no
-- 'other' there is no fallback category, so an unmapped event type must fail at
-- the mapping rather than producing a NULL rate that surfaces as a NOT NULL
-- violation three triggers later.
--
-- PACKAGES ARE FIXED AND PLATFORM-DEFINED
-- ---------------------------------------
-- En4 defines them, not talent, so clients see a uniform offering rather than
-- one performer's idea of a wedding set against another's.
--
-- Durations INCLUDE BREAKS, except spot performance. Only spot performance is a
-- range (15-20 minutes); the rest are single values stored as min = max.
--
-- NOTHING PRICES OFF min_minutes OR max_minutes. This is the point of fixed
-- packages: the fee is the talent's rate for the category, full stop. The old
-- multiplier - round(rate * greatest(1, hours / 4), 2) in enforce_quote_writes -
-- disappears entirely, and quote_requests.duration_hours goes back to being
-- what it always was: a generated column off the client's event window, for the
-- calendar. If a future change starts multiplying by duration, the whole
-- simplification is undone.
--
-- Append-only, same rule and same reason as price_ranges: a package definition
-- is what a past client was told they were buying, and editing it in place
-- would restate that retroactively. A set must cover EVERY rate category, or a
-- quote in the uncovered one has no package to name.
--
-- READABLE BY ANYONE, unlike rates and price ranges. A package is exactly what
-- the platform advertises. Select only; no write access for any browser role.
--
-- VERIFIED AFTER APPLYING: 7 categories, no leftover _old types, 7 packages,
-- 21 rate rows at 7 per talent, both triggers restored, all 9 event types
-- mapped, editing a package refused, and a one-row set refused at commit.

begin;

delete from public.talent_rates where category = 'other';

drop function if exists public.rate_category_for_event_type(public.events_type) cascade;
drop function if exists public.seed_talent_rate_rows() cascade;
drop function if exists public.set_talent_rate_at_request() cascade;

alter type public.rate_category rename to rate_category_old;

create type public.rate_category as enum (
  'special_events', 'wedding', 'concert', 'club_pub',
  'dinner_service', 'lunch_service', 'spot_performance'
);

alter table public.talent_rates
  alter column category type public.rate_category
  using category::text::public.rate_category;

alter type public.events_type rename to events_type_old;

create type public.events_type as enum (
  'wedding', 'corporate', 'birthday', 'concert', 'private',
  'dinner_service', 'lunch_service', 'club_pub', 'spot_performance'
);

alter table public.quote_requests
  alter column event_type type public.events_type
  using event_type::text::public.events_type;

drop type public.rate_category_old;
drop type public.events_type_old;

create function public.rate_category_for_event_type(p_event public.events_type)
returns public.rate_category
language plpgsql immutable strict set search_path to 'public' as $$
declare v public.rate_category;
begin
  v := (case p_event
    when 'corporate'        then 'special_events'
    when 'birthday'         then 'special_events'
    when 'private'          then 'special_events'
    when 'wedding'          then 'wedding'
    when 'concert'          then 'concert'
    when 'club_pub'         then 'club_pub'
    when 'dinner_service'   then 'dinner_service'
    when 'lunch_service'    then 'lunch_service'
    when 'spot_performance' then 'spot_performance'
  end)::public.rate_category;

  if v is null then
    raise exception 'No rate category is mapped for event type %. Add it here before adding it to events_type.', p_event
      using errcode = '23514';
  end if;
  return v;
end;
$$;

create function public.seed_talent_rate_rows()
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

create function public.set_talent_rate_at_request()
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
    new.talent_rate_at_request := old.talent_rate_at_request;
  end if;
  return new;
end;
$function$;

create trigger trg_quote_requests_rate_snapshot
  before insert or update on public.quote_requests
  for each row execute function public.set_talent_rate_at_request();

create table public.package_sets (
  id             uuid primary key default gen_random_uuid(),
  effective_from timestamptz not null,
  note           text,
  created_at     timestamptz not null default now(),
  constraint package_sets_note_len check (note is null or char_length(note) <= 500)
);

create unique index package_sets_effective_idx on public.package_sets (effective_from);

create table public.packages (
  id            uuid primary key default gen_random_uuid(),
  set_id        uuid not null references public.package_sets(id) on delete restrict,
  category      public.rate_category not null,
  label         text not null,
  min_minutes   integer not null,
  max_minutes   integer not null,
  created_at    timestamptz not null default now(),

  constraint packages_label_len   check (char_length(btrim(label)) between 1 and 200),
  constraint packages_min_range   check (min_minutes between 1 and 1440),
  constraint packages_max_range   check (max_minutes between 1 and 1440),
  constraint packages_min_le_max  check (min_minutes <= max_minutes),
  constraint packages_one_per_cat unique (set_id, category)
);

create index packages_set_category_idx on public.packages (set_id, category);

create or replace function public.packages_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'packages and package_sets are append-only: insert a new set with a later effective_from instead of % on %', TG_OP, TG_TABLE_NAME;
end;
$$;

create trigger packages_no_mutate
  before update or delete on public.packages
  for each row execute function public.packages_append_only();

create trigger package_sets_no_mutate
  before update or delete on public.package_sets
  for each row execute function public.packages_append_only();

-- Deferred, so the seven rows can be inserted in any order within the
-- transaction and completeness is judged once at commit.
create or replace function public.assert_package_set_complete()
returns trigger language plpgsql as $$
declare n integer; expected integer;
begin
  select count(*) into n from public.packages where set_id = NEW.set_id;
  expected := array_length(enum_range(null::public.rate_category), 1);
  if n <> expected then
    raise exception 'package set % has % rows, expected one per rate category (%)', NEW.set_id, n, expected;
  end if;
  return null;
end;
$$;

create constraint trigger packages_set_complete
  after insert on public.packages
  deferrable initially deferred
  for each row execute function public.assert_package_set_complete();

alter table public.package_sets enable row level security;
alter table public.packages     enable row level security;
alter table public.package_sets force row level security;
alter table public.packages     force row level security;

revoke all on public.package_sets from public, anon, authenticated;
revoke all on public.packages     from public, anon, authenticated;
grant select on public.package_sets to anon, authenticated;
grant select on public.packages     to anon, authenticated;

create policy package_sets_read    on public.package_sets for select to anon, authenticated using (true);
create policy packages_read        on public.packages     for select to anon, authenticated using (true);
create policy package_sets_service on public.package_sets for all to service_role using (true) with check (true);
create policy packages_service     on public.packages     for all to service_role using (true) with check (true);

create or replace function public.package_for_category(
  p_category public.rate_category,
  p_at       timestamptz default now()
) returns uuid
language sql stable security definer set search_path to 'public' as $$
  select p.id
    from public.packages p
    join public.package_sets s on s.id = p.set_id
   where s.effective_from <= p_at
     and s.effective_from = (
       select max(s2.effective_from) from public.package_sets s2
        where s2.effective_from <= p_at)
     and p.category = p_category
   limit 1;
$$;

grant execute on function public.package_for_category(public.rate_category, timestamptz) to anon, authenticated, service_role;

with s as (
  insert into public.package_sets (effective_from, note)
  values (now(), 'Initial packages agreed 2026-09-28. Durations include breaks except spot performance.')
  returning id
)
insert into public.packages (set_id, category, label, min_minutes, max_minutes)
select s.id, v.category::public.rate_category, v.label, v.mn, v.mx
  from s, (values
    ('special_events',   '4.5 hours, including breaks', 270, 270),
    ('wedding',          '6 hours, including breaks',   360, 360),
    ('concert',          '90 minutes',                   90,  90),
    ('club_pub',         '4.5 hours, including breaks', 270, 270),
    ('dinner_service',   '4.5 hours, including breaks', 270, 270),
    ('lunch_service',    '4.5 hours, including breaks', 270, 270),
    ('spot_performance', 'A short set of 3 songs, 15-20 minutes', 15, 20)
  ) as v(category, label, mn, mx);

comment on table public.packages is
  'Fixed platform-defined packages, one per rate category (D-038, settled 2026-09-28). En4 defines these rather than talent, so clients see a uniform offering. Durations include breaks, except spot performance. NOTHING PRICES OFF min_minutes or max_minutes - the fee is the talent rate for the category, full stop, and these exist for display. Append-only: a package definition is what a past client was told they were buying.';

commit;