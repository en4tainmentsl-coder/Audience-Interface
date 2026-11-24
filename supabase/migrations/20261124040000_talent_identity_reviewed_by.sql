-- Record WHO decided on a KYC row, for rejections as well as approvals.
--
-- Decision (Praveen, 2026-11-24, Todoist 6hqMWFjFCWwXhCc5): a rejection must be
-- attributable on talent_identity itself, but verified_by must keep meaning
-- "verified". Chosen over leaving rejections unattributed, and over overloading
-- verified_by with rejection decisions — a column whose name contradicts its
-- contents misleads whoever reads it next.
--
--   verified_by / verified_at -> the identity verification. Approval only.
--   reviewed_by / reviewed_at -> the most recent decision, either outcome.
--
-- On an approval both pairs are written and agree. They diverge when a verified
-- profile is later rejected: the verification that happened stays on record,
-- and the rejection that followed is attributed separately.

alter table public.talent_identity
  add column reviewed_by uuid references public.profiles_users(id) on delete set null,
  add column reviewed_at timestamptz;

comment on column public.talent_identity.reviewed_by is
  'Reviewer whose decision last set kyc_status, on approval or rejection. verified_by records the verification specifically and is never written on a rejection.';

comment on column public.talent_identity.reviewed_at is
  'When the most recent KYC decision was recorded.';

create or replace function public.record_talent_review_as(
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

    -- Every rejection is attributed. Only the two document reasons move
    -- kyc_status; the rest are profile problems, not document problems.
    update public.talent_identity ti
       set kyc_status  = case
                           when p_reason in ('documents_unclear', 'identity_mismatch')
                           then 'rejected'::public.kyc_status
                           else ti.kyc_status
                         end,
           reviewed_by = p_approver,
           reviewed_at = now()
     where ti.talent_id = p_talent_id;
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
             verified_at = now(),
             reviewed_by = p_approver,
             reviewed_at = now()
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