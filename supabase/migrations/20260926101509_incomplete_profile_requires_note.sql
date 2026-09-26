-- 'incomplete_profile' does not mean what its name suggests. A profile cannot
-- reach pending_approval at all unless check_talent_completeness_before_submission
-- passes, so by review time every required field is present. A reviewer choosing
-- this reason is making a QUALITY judgement - a thin bio, a video that does not
-- show them performing - which the database cannot compute and cannot list.
--
-- So the reviewer is the only possible source of what is lacking, and the note
-- becomes mandatory here for the same reason it is mandatory for 'other':
-- without it the email tells the talent to fix something unspecified.
-- The name is kept deliberately (decided 2026-09-26); only the behaviour changes.

alter table public.profiles_talent
  drop constraint if exists chk_rejection_other_needs_note;

alter table public.profiles_talent
  add constraint chk_rejection_reason_needs_note check (
    rejection_reason is null
    or rejection_reason not in ('other', 'incomplete_profile')
    or (rejection_note is not null and btrim(rejection_note) <> '')
  );

create or replace function public.review_talent(
  p_talent_id uuid,
  p_reviewer  uuid,
  p_decision  text,
  p_reason    public.talent_rejection_reason default null,
  p_note      text default null
)
returns table (stage_name text, account_email text, contact_email text)
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_status     approval_status;
  v_deletion   timestamptz;
  v_user_id    uuid;
  v_seen_front boolean;
  v_seen_back  boolean;
  v_window     constant interval := interval '30 minutes';
BEGIN
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Decision must be approve or reject.' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles_users u
                  WHERE u.id = p_reviewer AND u.role = 'admin') THEN
    RAISE EXCEPTION 'Only an admin may review a profile.' USING ERRCODE = '42501';
  END IF;

  SELECT t.approval_status, t.deletion_requested_at, t.user_id
    INTO v_status, v_deletion, v_user_id
    FROM public.profiles_talent t WHERE t.id = p_talent_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No such talent profile.' USING ERRCODE = '42704';
  END IF;

  IF v_status <> 'pending_approval' THEN
    RAISE EXCEPTION 'This profile is not awaiting review (it is %).', v_status
      USING ERRCODE = '42501';
  END IF;

  IF p_decision = 'approve' THEN
    IF v_deletion IS NOT NULL THEN
      RAISE EXCEPTION 'This talent has requested deletion and cannot be approved.'
        USING ERRCODE = '42501';
    END IF;

    SELECT bool_or(l.asset_type = 'kyc_front'),
           bool_or(l.asset_type = 'kyc_back')
      INTO v_seen_front, v_seen_back
      FROM public.sensitive_asset_access_log l
     WHERE l.subject_talent_id = p_talent_id
       AND l.accessed_by_user_id = p_reviewer
       AND l.accessed_at > now() - v_window;

    IF NOT (coalesce(v_seen_front, false) AND coalesce(v_seen_back, false)) THEN
      RAISE EXCEPTION
        'Open both sides of the NIC before approving. Seen in the last 30 minutes: front=%, back=%.',
        coalesce(v_seen_front, false), coalesce(v_seen_back, false)
        USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles_talent t
       SET approval_status  = 'approved',
           profile_status   = 'active',
           is_verified      = true,
           is_public        = true,
           reviewed_at      = now(),
           reviewed_by      = p_reviewer,
           rejection_reason = null,
           rejection_note   = null
     WHERE t.id = p_talent_id;

    UPDATE public.talent_identity ti
       SET kyc_status = 'verified'
     WHERE ti.talent_id = p_talent_id;

  ELSE
    IF p_reason IS NULL THEN
      RAISE EXCEPTION 'A rejection reason is required.' USING ERRCODE = '22023';
    END IF;

    -- 'other' and 'incomplete_profile' both carry no usable detail on their own.
    IF p_reason IN ('other', 'incomplete_profile')
       AND (p_note IS NULL OR btrim(p_note) = '') THEN
      RAISE EXCEPTION
        'A note is required for this reason - the talent cannot act on it otherwise.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.profiles_talent t
       SET approval_status  = 'rejected',
           rejection_reason = p_reason,
           rejection_note   = nullif(btrim(coalesce(p_note, '')), ''),
           reviewed_at      = now(),
           reviewed_by      = p_reviewer,
           is_public        = false
     WHERE t.id = p_talent_id;

    IF p_reason IN ('documents_unclear', 'identity_mismatch') THEN
      UPDATE public.talent_identity ti
         SET kyc_status = 'rejected'
       WHERE ti.talent_id = p_talent_id;
    END IF;
  END IF;

  RETURN QUERY
  SELECT t.stage_name,
         coalesce((SELECT nullif(au.email, '') FROM auth.users au WHERE au.id = v_user_id),
                  nullif(t.email, '')),
         nullif(t.email, '')
    FROM public.profiles_talent t WHERE t.id = p_talent_id;
END;
$function$;

revoke all on function public.review_talent(uuid, uuid, text, public.talent_rejection_reason, text)
  from public, anon, authenticated;
grant execute on function public.review_talent(uuid, uuid, text, public.talent_rejection_reason, text)
  to service_role;
