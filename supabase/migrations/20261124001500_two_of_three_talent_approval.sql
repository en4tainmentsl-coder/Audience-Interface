-- 2-of-3 reviewer approval for talent profiles.
--
-- Decisions (Praveen, 2026-11-23 / 2026-11-24):
--   * Reviewers are a named allowlist, NOT profiles_users.role = 'admin' — that role
--     also covers the shared admin.001 account and non-reviewing staff.
--   * Signatures are scoped to a review_cycle, so a profile edited after approval
--     needs two fresh signatures while the old ones survive as audit history.
--   * The threshold lives as a constant in the function: changing how many people
--     must sign off on identity documents should cost a migration and a review.
--   * One rejection rejects; two approvals are needed to go live.

-- ---------------------------------------------------------------------------
-- 1. Who may cast a signature
-- ---------------------------------------------------------------------------

create table public.reviewers (
  user_id    uuid primary key references public.profiles_users(id) on delete restrict,
  granted_at timestamptz not null default now(),
  granted_by uuid references public.profiles_users(id) on delete set null,
  revoked_at timestamptz,
  note       text,
  constraint reviewers_revoked_after_granted
    check (revoked_at is null or revoked_at >= granted_at)
);

comment on table public.reviewers is
  'Named allowlist of people who may cast a profile-approval signature. Deliberately separate from profiles_users.role = ''admin''.';

alter table public.reviewers enable row level security;

create policy reviewers_admin_select on public.reviewers
  for select to authenticated
  using (exists (select 1 from public.profiles_users u
                  where u.id = auth.uid() and u.role = 'admin'));

create policy reviewers_service on public.reviewers
  for all to service_role using (true) with check (true);

revoke all on table public.reviewers from anon, authenticated;
grant select on table public.reviewers to authenticated;
grant all    on table public.reviewers to service_role;

-- Seeded reviewers: Praveen, Ashey, Ranil. Erich and admin.001@ are excluded
-- deliberately — Erich left the review path on 2026-11-23, and a shared account
-- cannot carry an attributable signature.
insert into public.reviewers (user_id, note)
select u.id, 'Seeded 2026-11-24 with the 2-of-3 decision'
  from public.profiles_users u
 where u.email in ('praveen.edema@gmail.com', 'asheys@gmail.com', 'ranilpt@gmail.com');

do $$
declare n integer;
begin
  select count(*) into n from public.reviewers;
  if n <> 3 then
    raise exception 'Expected 3 seeded reviewers, got % — check the email addresses.', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Review cycles, so signatures do not survive a resubmission
-- ---------------------------------------------------------------------------

alter table public.profiles_talent
  add column review_cycle smallint not null default 1;

alter table public.profiles_talent
  add constraint profiles_talent_review_cycle_positive check (review_cycle >= 1);

comment on column public.profiles_talent.review_cycle is
  'Increments each time the profile re-enters pending_approval. Signatures are counted per cycle, so an edited profile needs fresh approvals.';

create function public.bump_review_cycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.approval_status = 'pending_approval'
     and old.approval_status is distinct from 'pending_approval' then
    new.review_cycle := old.review_cycle + 1;
  end if;
  return new;
end;
$$;

-- NAME MATTERS: this must sort AFTER z_directus_column_scope, which rejects any
-- column a Directus write changes that is not in its allowed list. Running later
-- means the scope check never sees review_cycle move, so review_cycle does not
-- have to be added to that list — which would let a reviewer void signatures by
-- bumping the cycle by hand.
create trigger zz_bump_review_cycle
  before update on public.profiles_talent
  for each row execute function public.bump_review_cycle();

-- ---------------------------------------------------------------------------
-- 3. The signatures themselves
-- ---------------------------------------------------------------------------

create table public.talent_approvals (
  id           uuid primary key default gen_random_uuid(),
  talent_id    uuid not null references public.profiles_talent(id) on delete cascade,
  approver_id  uuid not null references public.profiles_users(id) on delete restrict,
  review_cycle smallint not null,
  decision     text not null check (decision in ('approve', 'reject')),
  reason       public.talent_rejection_reason,
  note         text,
  decided_at   timestamptz not null default now(),
  constraint talent_approvals_one_per_cycle
    unique (talent_id, approver_id, review_cycle),
  constraint talent_approvals_reason_only_on_reject
    check (decision = 'reject' or reason is null),
  constraint talent_approvals_note_length
    check (note is null or char_length(note) <= 500)
);

comment on table public.talent_approvals is
  'Append-only record of each reviewer decision, per talent per review cycle. One row per reviewer per cycle.';

alter table public.talent_approvals enable row level security;

create policy talent_approvals_admin_select on public.talent_approvals
  for select to authenticated
  using (exists (select 1 from public.profiles_users u
                  where u.id = auth.uid() and u.role = 'admin'));

create policy talent_approvals_service on public.talent_approvals
  for all to service_role using (true) with check (true);

revoke all on table public.talent_approvals from anon, authenticated;
grant select on table public.talent_approvals to authenticated;
grant all    on table public.talent_approvals to service_role;

create function public.talent_approvals_no_mutate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if coalesce(current_setting('en4.admin_override', true), '') = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception
    'talent_approvals is append-only: a recorded signature cannot be changed or removed.'
    using errcode = '23514',
          hint = 'Record a new decision in a new review cycle instead.';
end;
$$;

create trigger talent_approvals_no_mutate
  before update or delete on public.talent_approvals
  for each row execute function public.talent_approvals_no_mutate();

-- ---------------------------------------------------------------------------
-- 4. The guarantee: no profile goes live without two distinct signatures
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER on purpose: this must count every signature regardless of
-- whose RLS view triggered the update. SECURITY INVOKER would count zero rows
-- for a caller who cannot select talent_approvals, and block a valid approval.
create function public.enforce_talent_approval_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_required constant integer := 2;   -- 2-of-3. Changing this is a migration, deliberately.
  v_signatures integer;
begin
  if new.approval_status = 'approved'
     and old.approval_status is distinct from 'approved' then

    if coalesce(current_setting('en4.admin_override', true), '') = 'on' then
      return new;
    end if;

    select count(distinct a.approver_id)
      into v_signatures
      from public.talent_approvals a
      join public.reviewers r
        on r.user_id = a.approver_id and r.revoked_at is null
     where a.talent_id    = new.id
       and a.review_cycle = new.review_cycle
       and a.decision     = 'approve';

    if v_signatures < v_required then
      raise exception
        'This profile has % of % required approvals for review cycle %.',
        v_signatures, v_required, new.review_cycle
        using errcode = '23514',
              hint = 'Two different named reviewers must each approve before a profile goes live.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_talent_approval_threshold() from public, anon, authenticated;

create trigger zy_enforce_approval_threshold
  before update on public.profiles_talent
  for each row execute function public.enforce_talent_approval_threshold();

-- ---------------------------------------------------------------------------
-- 5. Recording a decision
-- ---------------------------------------------------------------------------

create function public.record_talent_review_as(
  p_talent_id uuid,
  p_approver  uuid,
  p_decision  text,
  p_reason    public.talent_rejection_reason default null,
  p_note      text default null
)
returns table (
  stage_name         text,
  account_email      text,
  contact_email      text,
  approvals_now      integer,
  approvals_required integer,
  now_live           boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_required constant integer  := 2;
  v_window   constant interval := interval '30 minutes';
  v_status     public.approval_status;
  v_deletion   timestamptz;
  v_user_id    uuid;
  v_cycle      smallint;
  v_seen_front boolean;
  v_seen_back  boolean;
  v_count      integer := 0;
  v_live       boolean := false;
begin
  if p_decision not in ('approve', 'reject') then
    raise exception 'Decision must be approve or reject.' using errcode = '22023';
  end if;

  if p_approver is null then
    raise exception 'No reviewer identity on this call.' using errcode = '42501';
  end if;

  if not exists (select 1 from public.reviewers r
                  where r.user_id = p_approver and r.revoked_at is null) then
    raise exception 'Only a named reviewer may record an approval decision.'
      using errcode = '42501',
            hint = 'Reviewers live in public.reviewers, which is not the same as role = admin.';
  end if;

  select t.approval_status, t.deletion_requested_at, t.user_id, t.review_cycle
    into v_status, v_deletion, v_user_id, v_cycle
    from public.profiles_talent t
   where t.id = p_talent_id
     for update;

  if not found then
    raise exception 'No such talent profile.' using errcode = '42704';
  end if;

  if v_status <> 'pending_approval' then
    raise exception 'This profile is not awaiting review (it is %).', v_status
      using errcode = '42501';
  end if;

  if p_decision = 'approve' then
    if v_deletion is not null then
      raise exception 'This talent has requested deletion and cannot be approved.'
        using errcode = '42501';
    end if;

    -- Each signer must have opened both sides of the NIC themselves, recently.
    select bool_or(l.asset_type = 'kyc_front'),
           bool_or(l.asset_type = 'kyc_back')
      into v_seen_front, v_seen_back
      from public.sensitive_asset_access_log l
     where l.subject_talent_id   = p_talent_id
       and l.accessed_by_user_id = p_approver
       and l.accessed_at > now() - v_window;

    if not (coalesce(v_seen_front, false) and coalesce(v_seen_back, false)) then
      raise exception
        'Open both sides of the NIC before approving. Seen in the last 30 minutes: front=%, back=%.',
        coalesce(v_seen_front, false), coalesce(v_seen_back, false)
        using errcode = '42501';
    end if;
  else
    if p_reason is null then
      raise exception 'A rejection reason is required.' using errcode = '22023';
    end if;
    if p_reason in ('other', 'incomplete_profile')
       and (p_note is null or btrim(p_note) = '') then
      raise exception
        'A note is required for this reason — the talent cannot act on it otherwise.'
        using errcode = '22023';
    end if;
  end if;

  begin
    insert into public.talent_approvals
      (talent_id, approver_id, review_cycle, decision, reason, note)
    values
      (p_talent_id, p_approver, v_cycle, p_decision, p_reason,
       nullif(btrim(coalesce(p_note, '')), ''));
  exception when unique_violation then
    raise exception 'You have already recorded a decision for this review cycle.'
      using errcode = '23505',
            hint = 'One decision per reviewer per review cycle.';
  end;

  if p_decision = 'reject' then
    update public.profiles_talent t
       set approval_status  = 'rejected',
           rejection_reason = p_reason,
           rejection_note   = nullif(btrim(coalesce(p_note, '')), ''),
           reviewed_at      = now(),
           reviewed_by      = p_approver,
           is_public        = false
     where t.id = p_talent_id;

    if p_reason in ('documents_unclear', 'identity_mismatch') then
      update public.talent_identity ti
         set kyc_status = 'rejected'
       where ti.talent_id = p_talent_id;
    end if;
  else
    select count(distinct a.approver_id)
      into v_count
      from public.talent_approvals a
      join public.reviewers r
        on r.user_id = a.approver_id and r.revoked_at is null
     where a.talent_id    = p_talent_id
       and a.review_cycle = v_cycle
       and a.decision     = 'approve';

    if v_count >= v_required then
      update public.profiles_talent t
         set approval_status  = 'approved',
             profile_status   = 'active',
             is_verified      = true,
             is_public        = true,
             reviewed_at      = now(),
             reviewed_by      = p_approver,
             rejection_reason = null,
             rejection_note   = null
       where t.id = p_talent_id;

      update public.talent_identity ti
         set kyc_status  = 'verified',
             verified_by = p_approver,
             verified_at = now()
       where ti.talent_id = p_talent_id;

      v_live := true;
    end if;
  end if;

  return query
  select t.stage_name,
         coalesce((select nullif(au.email, '') from auth.users au where au.id = v_user_id),
                  nullif(c.email, '')),
         nullif(c.email, ''),
         v_count,
         v_required,
         v_live
    from public.profiles_talent t
    left join public.talent_contact c on c.talent_id = t.id
   where t.id = p_talent_id;
end;
$$;

revoke all on function
  public.record_talent_review_as(uuid, uuid, text, public.talent_rejection_reason, text)
  from public, anon, authenticated;

-- Entry point for a reviewer's own session: identity comes from the JWT, not an argument.
create function public.record_talent_review(
  p_talent_id uuid,
  p_decision  text,
  p_reason    public.talent_rejection_reason default null,
  p_note      text default null
)
returns table (
  stage_name         text,
  account_email      text,
  contact_email      text,
  approvals_now      integer,
  approvals_required integer,
  now_live           boolean
)
language sql
security definer
set search_path = ''
as $$
  select * from public.record_talent_review_as(
    p_talent_id, auth.uid(), p_decision, p_reason, p_note);
$$;

revoke all on function
  public.record_talent_review(uuid, text, public.talent_rejection_reason, text)
  from public, anon;
grant execute on function
  public.record_talent_review(uuid, text, public.talent_rejection_reason, text)
  to authenticated, service_role;

-- Existing Edge Function caller keeps its signature and its three columns.
create or replace function public.review_talent(
  p_talent_id uuid,
  p_reviewer  uuid,
  p_decision  text,
  p_reason    public.talent_rejection_reason,
  p_note      text
)
returns table (stage_name text, account_email text, contact_email text)
language sql
security definer
set search_path = ''
as $$
  select r.stage_name, r.account_email, r.contact_email
    from public.record_talent_review_as(
      p_talent_id, p_reviewer, p_decision, p_reason, p_note) r;
$$;
