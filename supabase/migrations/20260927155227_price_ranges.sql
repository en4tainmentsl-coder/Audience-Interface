-- 20260927155227_price_ranges.sql
--
-- Client-facing price ranges 1-10. Settled by Praveen 2026-09-27.
--
-- WHAT A RANGE IS
-- ---------------
-- A client filters talent by "Range 6". Membership is DERIVED from the talent's
-- rate for the event type, never stored on the talent - so shifting a boundary
-- re-buckets everyone at once, which is the whole point. A stored range column
-- would be a denormalised value that goes stale.
--
-- Naming: ordered and non-judgemental were the criteria. Tier, Level, Grade,
-- Class and Category all rank the performer rather than the price. A neutral
-- noun plus a number is the only form that stays ordered when the label appears
-- away from the filter - on a quote, in an email. Ascending, so a new talent
-- does not start at what reads like a bottom rank.
--
-- LOWER BOUND ONLY - this is not a style choice
-- ---------------------------------------------
-- The first draft stored both bounds: 1000-7500, 7600-18000, and so on. That
-- left 7,550 in no range at all, and the same hole at every boundary. A talent
-- landing in a hole would have had no range and dropped out of every client
-- filter - which would have looked like a broken search, not a config gap.
--
-- A range now runs from its own floor to the next floor, exclusive. Range 10 is
-- uncapped, so the most expensive acts cannot fall off the top. The floor
-- belongs to the range above: 7,499 is Range 1, 7,500 is Range 2.
--
-- Range 1 starts at 1,000 and nothing below it resolves. talent_rates MUST
-- therefore carry CHECK (amount >= 1000), or the floor merely relocates the hole.
--
-- SHARED ACROSS EVENT TYPES
-- -------------------------
-- One ladder for all eight categories. The concern was that a shared card would
-- dump every spot performance into Range 1, but the ladder spans 1,000 to 2.3m+
-- and they spread out: spot performance lands around 3-4, a club gig 4, a
-- wedding 6, a headline act 9. Shared keeps "Range 6" meaning the same money
-- everywhere, which is exactly the property that lets the label travel.
-- Per-event-type overrides later would be a nullable event_type column plus a
-- lookup change, not a rewrite.
--
-- APPEND-ONLY, AND ENFORCED
-- -------------------------
-- Admin shifts ranges by inserting a NEW set, never by editing one a quote
-- already points at. Editing in place would retroactively rewrite what a past
-- client was shown. The triggers below refuse UPDATE and DELETE outright -
-- including from the SQL editor, deliberately.
--
-- Two tables, not one, because a set must stay whole: with effective_from
-- repeated on ten rows, nothing stops nine moving and one not.
--
-- NOT PUBLICLY READABLE
-- ---------------------
-- The client sees the label; the numbers stay server-side. This is load-bearing.
-- Publishing the boundaries would hand a talent their own ceiling by
-- subtraction, defeating the never-see-the-bands rule rather than weakening it -
-- the same leak pricing_per_session opened, where anon SELECT on profiles_talent
-- exposed every rate through PostgREST to anyone holding the publishable key.
--
-- Supabase default privileges grant anon and authenticated on new public tables,
-- and REVOKE FROM PUBLIC alone does not strip a role-specific grant, so the
-- revokes name the roles. Verified after applying: no anon or authenticated
-- grant on either table.
--
-- VERIFIED AGAINST THE LIVE DATABASE AFTER APPLYING
-- -------------------------------------------------
--   7,499 -> Range 1, 7,500 -> Range 2   (no gap at the boundary)
--   50,000,000 -> Range 10                (uncapped)
--   999 -> null                           (below the floor)
--   UPDATE refused; floor still 7,500 afterwards
--   A 1-row set refused at commit

begin;

create table public.price_range_sets (
  id            uuid primary key default gen_random_uuid(),
  effective_from timestamptz not null,
  note          text,
  created_at    timestamptz not null default now(),
  constraint price_range_sets_note_len check (note is null or char_length(note) <= 500)
);

create unique index price_range_sets_effective_idx
  on public.price_range_sets (effective_from);

create table public.price_ranges (
  id         uuid primary key default gen_random_uuid(),
  set_id     uuid not null references public.price_range_sets(id) on delete restrict,
  ordinal    smallint not null,
  min_amount numeric(12,2) not null,

  constraint price_ranges_ordinal_range check (ordinal between 1 and 10),
  constraint price_ranges_min_floor     check (min_amount >= 1000),
  -- Range 1 anchors the ladder at the agreed floor.
  constraint price_ranges_first_anchor  check (ordinal <> 1 or min_amount = 1000),
  constraint price_ranges_unique_ord    unique (set_id, ordinal),
  constraint price_ranges_unique_min    unique (set_id, min_amount)
);

create index price_ranges_set_ordinal_idx on public.price_ranges (set_id, ordinal);

create or replace function public.price_ranges_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'price_ranges and price_range_sets are append-only: insert a new set with a later effective_from instead of % on %', TG_OP, TG_TABLE_NAME;
end;
$$;

create trigger price_ranges_no_mutate
  before update or delete on public.price_ranges
  for each row execute function public.price_ranges_append_only();

create trigger price_range_sets_no_mutate
  before update or delete on public.price_range_sets
  for each row execute function public.price_ranges_append_only();

-- Deferred, so the ten rows can be inserted in any order inside the transaction
-- and completeness is judged once at commit.
create or replace function public.assert_price_range_set_valid()
returns trigger language plpgsql as $$
declare n integer; bad integer;
begin
  select count(*) into n from public.price_ranges where set_id = NEW.set_id;
  if n <> 10 then
    raise exception 'price range set % has % rows, expected exactly 10', NEW.set_id, n;
  end if;

  select count(*) into bad from (
    select min_amount, ordinal,
           lag(min_amount) over (order by ordinal) as prev
      from public.price_ranges where set_id = NEW.set_id
  ) s where prev is not null and min_amount <= prev;

  if bad > 0 then
    raise exception 'price range set % is not strictly ascending by ordinal', NEW.set_id;
  end if;
  return null;
end;
$$;

create constraint trigger price_ranges_set_complete
  after insert on public.price_ranges
  deferrable initially deferred
  for each row execute function public.assert_price_range_set_valid();

alter table public.price_range_sets enable row level security;
alter table public.price_ranges     enable row level security;
alter table public.price_range_sets force row level security;
alter table public.price_ranges     force row level security;

revoke all on public.price_range_sets from public, anon, authenticated;
revoke all on public.price_ranges     from public, anon, authenticated;

create policy price_range_sets_service on public.price_range_sets
  for all to service_role using (true) with check (true);
create policy price_ranges_service on public.price_ranges
  for all to service_role using (true) with check (true);

-- Resolves an amount to its range in the set in force at a given moment. The
-- p_at argument matters: a quote must resolve against the ladder that was live
-- when the client browsed, not the one live today.
create or replace function public.price_range_for_amount(
  p_amount numeric,
  p_at     timestamptz default now()
) returns uuid
language sql stable security definer set search_path to 'public' as $$
  select r.id
    from public.price_ranges r
    join public.price_range_sets s on s.id = r.set_id
   where s.effective_from <= p_at
     and s.effective_from = (
       select max(s2.effective_from) from public.price_range_sets s2
        where s2.effective_from <= p_at)
     and r.min_amount <= p_amount
   order by r.min_amount desc
   limit 1;
$$;

revoke all on function public.price_range_for_amount(numeric, timestamptz) from public, anon, authenticated;
grant execute on function public.price_range_for_amount(numeric, timestamptz) to service_role;

-- Seed: the ladder agreed 2026-09-27. Geometric - each step 2.4x down to 1.44x,
-- tightening as the money grows, because 5,000 matters at Range 1 and is
-- invisible at Range 9. Range 1 is the widest in relative terms (7.5x); split it
-- if spot performances turn out to cluster at 3-5k.
with s as (
  insert into public.price_range_sets (effective_from, note)
  values (now(), 'Initial ladder agreed 2026-09-27. Floors only; Range 10 uncapped.')
  returning id
)
insert into public.price_ranges (set_id, ordinal, min_amount)
select s.id, v.ordinal, v.min_amount
  from s, (values
    (1::smallint,    1000.00),
    (2::smallint,    7500.00),
    (3::smallint,   18000.00),
    (4::smallint,   35000.00),
    (5::smallint,   80000.00),
    (6::smallint,  180000.00),
    (7::smallint,  320000.00),
    (8::smallint,  575000.00),
    (9::smallint,  975000.00),
    (10::smallint, 1400000.00)
  ) as v(ordinal, min_amount);

comment on table public.price_ranges is
  'Client-facing price ranges 1-10, ascending. Lower bound only: a range runs to the next floor, exclusive; Range 10 is uncapped. Shared across all event types (settled 2026-09-27). Append-only: amend by inserting a new set. NOT readable by anon or authenticated - the numbers must never reach a talent.';

commit;