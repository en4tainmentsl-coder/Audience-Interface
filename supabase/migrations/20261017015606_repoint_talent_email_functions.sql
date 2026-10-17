-- Both functions fall back to profiles_talent.email when the auth.users email
-- is empty. That column is about to be dropped, so they read talent_contact
-- instead. Behaviour is unchanged: talent_contact was backfilled from the same
-- values. Everything above each RETURN QUERY is untouched.

CREATE OR REPLACE FUNCTION public.review_talent(
  p_talent_id uuid, p_reviewer uuid, p_decision text,
  p_reason talent_rejection_reason DEFAULT NULL::talent_rejection_reason,
  p_note text DEFAULT NULL::text)
RETURNS TABLE(stage_name text, account_email text, contact_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
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
        'A note is required for this reason — the talent cannot act on it otherwise.'
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
                  nullif(c.email, '')),
         nullif(c.email, '')
    FROM public.profiles_talent t
    LEFT JOIN public.talent_contact c ON c.talent_id = t.id
   WHERE t.id = p_talent_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_profile_deletion(p_user_id uuid)
RETURNS TABLE(talent_id uuid, stage_name text, account_email text,
              contact_email text, requested_at timestamp with time zone)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_account_email text;
  v_contact_email text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'A user id is required.' USING ERRCODE = '42501';
  END IF;

  SELECT nullif(au.email, '') INTO v_account_email
    FROM auth.users au WHERE au.id = p_user_id;

  -- Captured before the UPDATE: RETURNING cannot reach another table.
  SELECT nullif(c.email, '') INTO v_contact_email
    FROM public.talent_contact c
    JOIN public.profiles_talent t ON t.id = c.talent_id
   WHERE t.user_id = p_user_id;

  RETURN QUERY
  UPDATE public.profiles_talent t
     SET deletion_requested_at = now(),
         is_public             = false   -- explicit: the trust guard does not run under service_role
   WHERE t.user_id = p_user_id
     AND t.deletion_requested_at IS NULL
  RETURNING t.id,
            t.stage_name,
            coalesce(v_account_email, v_contact_email),
            v_contact_email,
            t.deletion_requested_at;

  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM public.profiles_talent
                WHERE user_id = p_user_id AND deletion_requested_at IS NOT NULL) THEN
      RAISE EXCEPTION 'A deletion request is already in progress for this profile.'
        USING ERRCODE = '42501';
    END IF;
    RAISE EXCEPTION 'No talent profile found for this account.' USING ERRCODE = '42501';
  END IF;
END;
$function$;
