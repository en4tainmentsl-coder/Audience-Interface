-- =====================================================================
-- Rating model rebuild
-- Todoist: 6hPWCv8J5vjcMQv5
--
-- The reviewer gives one integer 1-5 plus a required yes/no and an
-- optional comment. Sub-ratings are removed rather than left NULL.
-- The public average lives in talent_stats, not here, so no public
-- SELECT policy on this table is needed and is_verified is redundant.
--
-- Section 1 of 5: reviews_star columns, constraints and insert policy.
-- =====================================================================

-- 1a. This policy reads is_verified, so it must go before the column.
--     No replacement: the public never reads individual reviews.
drop policy if exists "reviews_star_public_read" on public.reviews_star;

-- 1b. The rater is always bookings.client_user_id. A venue booking puts
--     the venue's own user there (verified in RequestQuote.tsx), so the
--     separate venue branch and its profiles_venues join are redundant.
drop policy if exists "rev_client_or_venue_insert" on public.reviews_star;

create policy "reviews_star_client_insert" on public.reviews_star
  for insert to authenticated
  with check (
    auth.uid() = reviewer_user_id
    and exists (
      select 1
      from public.bookings b
      where b.id = reviews_star.booking_id
        and b.client_user_id = auth.uid()
        and b.booking_status = 'completed'
    )
  );

-- 1c. chk_review_rating is a byte-identical duplicate of
--     check_rating_range. Keeping check_rating_range. (Todoist 6h9798578vMxrxr5)
alter table public.reviews_star
  drop constraint if exists chk_review_rating,
  drop constraint if exists chk_review_overall_rating,
  drop constraint if exists chk_review_audience_response,
  drop constraint if exists chk_review_musical_ability,
  drop constraint if exists chk_review_professionalism,
  drop constraint if exists chk_review_sound_quality,
  drop constraint if exists chk_review_stage_presence;

-- 1d. event_type is derivable via bookings.quote_id -> quote_requests.event_type
--     (NOT NULL there), so storing it here duplicates a fact with nothing
--     keeping the two in sync. The events_type enum itself stays in use.
alter table public.reviews_star
  drop column if exists overall_rating,
  drop column if exists stage_presence_rating,
  drop column if exists musical_ability_rating,
  drop column if exists professionalism_rating,
  drop column if exists sound_quality_rating,
  drop column if exists audience_response_rating,
  drop column if exists event_type,
  drop column if exists is_verified;

-- 1e. Required. Safe as a bare SET NOT NULL because the table is empty.
alter table public.reviews_star
  alter column would_book_again set not null;

-- 1f. A row could previously target neither reviewee or both.
alter table public.reviews_star
  add constraint chk_review_single_reviewee
  check (num_nonnulls(reviewee_talent_id, reviewee_venue_id) = 1);


-- =====================================================================
-- Section 2 of 5: talent_stats
--
-- Deliberately a separate table rather than columns on profiles_talent.
-- profiles_talent grants talent ALL on their own row, and RLS has no
-- column granularity, so aggregates living there would need pinning in
-- enforce_talent_trust_fields() and would silently become writable the
-- day someone adds a column and forgets. Here, protection is structural:
-- no write policy exists for authenticated, so nothing is writable.
-- =====================================================================

create table if not exists public.talent_stats (
  talent_id      uuid primary key
                 references public.profiles_talent(id) on delete cascade,
  rating_sum     integer     not null default 0,
  rating_count   integer     not null default 0,
  rating_average numeric(4,3),
  heart_count    integer     not null default 0,
  updated_at     timestamptz not null default now(),

  -- Sum and count are the authoritative pair; the average is derived
  -- from them. These guard against a drifted or hand-edited row.
  constraint chk_talent_stats_counts_nonneg
    check (rating_count >= 0 and rating_sum >= 0 and heart_count >= 0),
  constraint chk_talent_stats_sum_within_count
    check (rating_sum between rating_count and rating_count * 5),
  constraint chk_talent_stats_average_presence
    check ((rating_count = 0 and rating_average is null)
        or (rating_count > 0 and rating_average between 1 and 5))
);

alter table public.talent_stats enable row level security;
alter table public.talent_stats force row level security;

-- Public read. The average and count are the only rating data anyone
-- outside admin ever sees; individual reviews are never exposed.
create policy "talent_stats_public_read" on public.talent_stats
  for select to anon, authenticated
  using (true);

-- Writes come only from the trigger and the recompute function.
create policy "talent_stats_service_role" on public.talent_stats
  for all to service_role
  using (true) with check (true);

-- NO insert/update/delete policy for authenticated. This is intentional.
-- Do not add one. Talent must never be able to move their own rating.


-- =====================================================================
-- Section 3 of 5: aggregate maintenance
--
-- Incremental arithmetic from NEW/OLD only. This function never SELECTs
-- from reviews_star, so FORCE ROW LEVEL SECURITY on that table cannot
-- affect the result regardless of how FORCE and BYPASSRLS interact for
-- the definer role. The recompute function in section 4 does read, and
-- runs as service_role, which has an explicit USING (true) policy.
-- =====================================================================

create or replace function public.apply_talent_rating_delta(
  p_talent_id  uuid,
  p_sum_delta  integer,
  p_count_delta integer
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if p_talent_id is null or (p_sum_delta = 0 and p_count_delta = 0) then
    return;
  end if;

  insert into public.talent_stats (talent_id, rating_sum, rating_count, rating_average)
  values (
    p_talent_id,
    greatest(p_sum_delta, 0),
    greatest(p_count_delta, 0),
    case when p_count_delta > 0
         then round(p_sum_delta::numeric / p_count_delta, 3)
         else null end
  )
  on conflict (talent_id) do update
    set rating_sum   = public.talent_stats.rating_sum   + p_sum_delta,
        rating_count = public.talent_stats.rating_count + p_count_delta,
        rating_average = case
          when public.talent_stats.rating_count + p_count_delta > 0
          then round(
                 (public.talent_stats.rating_sum + p_sum_delta)::numeric
                 / (public.talent_stats.rating_count + p_count_delta), 3)
          else null
        end,
        updated_at = now();
end;
$$;

revoke all on function public.apply_talent_rating_delta(uuid, integer, integer) from public, anon, authenticated;

create or replace function public.sync_talent_rating_stats()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'INSERT' then
    perform public.apply_talent_rating_delta(NEW.reviewee_talent_id, NEW.rating, 1);

  elsif tg_op = 'DELETE' then
    perform public.apply_talent_rating_delta(OLD.reviewee_talent_id, -OLD.rating, -1);

  elsif tg_op = 'UPDATE' then
    -- Reviewee reassignment is not reachable under current policies, but
    -- admin and service_role can do it. Move the whole contribution
    -- rather than assuming the talent is unchanged.
    if OLD.reviewee_talent_id is distinct from NEW.reviewee_talent_id then
      perform public.apply_talent_rating_delta(OLD.reviewee_talent_id, -OLD.rating, -1);
      perform public.apply_talent_rating_delta(NEW.reviewee_talent_id,  NEW.rating,  1);
    elsif OLD.rating is distinct from NEW.rating then
      perform public.apply_talent_rating_delta(NEW.reviewee_talent_id, NEW.rating - OLD.rating, 0);
    end if;
  end if;

  return coalesce(NEW, OLD);
end;
$$;

revoke all on function public.sync_talent_rating_stats() from public, anon, authenticated;

drop trigger if exists trg_sync_talent_rating_stats on public.reviews_star;

create trigger trg_sync_talent_rating_stats
  after insert or update or delete on public.reviews_star
  for each row execute function public.sync_talent_rating_stats();


-- =====================================================================
-- Section 4 of 5: recompute and drift detection
--
-- The section 3 trigger is incremental and cannot notice when it is
-- wrong. These read reviews_star directly and are SECURITY INVOKER, so
-- they must be called as service_role or admin (both have USING (true)
-- policies, which hold under FORCE ROW LEVEL SECURITY).
--
-- check_talent_rating_drift() is safe to run any time and changes
-- nothing. Run it before recompute, not after a problem is reported.
-- =====================================================================

create or replace function public.check_talent_rating_drift()
returns table (
  talent_id       uuid,
  stored_sum      integer,
  actual_sum      integer,
  stored_count    integer,
  actual_count    integer,
  stored_average  numeric,
  actual_average  numeric
)
language sql
stable
set search_path to 'public'
as $$
  with actual as (
    select t.id as talent_id,
           coalesce(sum(r.rating), 0)::integer as a_sum,
           count(r.*)::integer                 as a_count
    from public.profiles_talent t
    left join public.reviews_star r on r.reviewee_talent_id = t.id
    group by t.id
  )
  select a.talent_id,
         coalesce(s.rating_sum, 0),
         a.a_sum,
         coalesce(s.rating_count, 0),
         a.a_count,
         s.rating_average,
         case when a.a_count > 0
              then round(a.a_sum::numeric / a.a_count, 3)
              else null end
  from actual a
  left join public.talent_stats s on s.talent_id = a.talent_id
  where coalesce(s.rating_sum, 0)   is distinct from a.a_sum
     or coalesce(s.rating_count, 0) is distinct from a.a_count
     -- A talent with reviews but no stats row at all is drift too.
     or (a.a_count > 0 and s.talent_id is null);
$$;

create or replace function public.recompute_talent_rating_stats(
  p_talent_id uuid default null   -- null recomputes every talent
)
returns integer
language plpgsql
set search_path to 'public'
as $$
declare
  v_rows integer;
begin
  insert into public.talent_stats (talent_id, rating_sum, rating_count, rating_average)
  select t.id,
         coalesce(sum(r.rating), 0)::integer,
         count(r.*)::integer,
         case when count(r.*) > 0
              then round(sum(r.rating)::numeric / count(r.*), 3)
              else null end
  from public.profiles_talent t
  left join public.reviews_star r on r.reviewee_talent_id = t.id
  where p_talent_id is null or t.id = p_talent_id
  group by t.id
  on conflict (talent_id) do update
    set rating_sum     = excluded.rating_sum,
        rating_count   = excluded.rating_count,
        rating_average = excluded.rating_average,
        updated_at     = now();

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

revoke all on function public.check_talent_rating_drift()          from public, anon, authenticated;
revoke all on function public.recompute_talent_rating_stats(uuid)  from public, anon, authenticated;



-- =====================================================================
-- Section 5 of 5: close the profiles_talent.rating self-rating hole
--
-- profiles_talent.rating is NOT dropped here. VenueDashboard.tsx selects
-- it explicitly inside nested profiles_talent(...) selects (lines 265,
-- 271), and PostgREST fails the whole request on a missing column rather
-- than omitting the field. Eight surfaces read it: ArtistDetail, Home,
-- Artists, ClientDashboard, VenueDashboard, TalentDashboard, ArtistCard,
-- FlexArtistCard. The drop goes in a follow-up migration once those read
-- talent_stats instead.
--
-- Until then the column stays but must not be writable by its owner.
-- talent_profile_manage_own grants talent ALL on their own row and RLS
-- has no column granularity, so today any talent can set their own
-- rating to 5.00 via the REST endpoint. Live hole; closed here.
--
-- Body is the live 2026-08-31 function verbatim plus two NEW.rating
-- lines. The approval_status conditional is deliberately untouched:
-- draft -> pending_approval is legitimate self-submission, anything
-- else is self-approval. Do not flatten it to a simple pin.
-- =====================================================================

create or replace function public.enforce_talent_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified    := false;
      NEW.is_public      := false;
      NEW.profile_status := 'pending'::talent_status;
      NEW.rating         := 0.00;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified    := OLD.is_verified;
      NEW.is_public      := OLD.is_public;
      NEW.profile_status := OLD.profile_status;
      NEW.rating         := OLD.rating;
      -- Submitting yourself for review is legitimate. Approving yourself
      -- is not. Only draft -> pending_approval passes.
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;