-- The deletion confirmation is a security notice ("if this was not you, reply
-- immediately"), so it must reach the verified account identity, not
-- profiles_talent.email, which is a user-editable contact field and was found
-- to diverge from the sign-in address on a live row (2026-09-26). An attacker
-- who took over an account could otherwise change the contact address first and
-- the real owner would never be warned.
--
-- Returns both: account_email is the recipient, contact_email only so the
-- caller can log a divergence.

drop function if exists public.request_profile_deletion(uuid);

create function public.request_profile_deletion(p_user_id uuid)
returns table (
  talent_id     uuid,
  stage_name    text,
  account_email text,
  contact_email text,
  requested_at  timestamptz
)
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_account_email text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'A user id is required.' USING ERRCODE = '42501';
  END IF;

  SELECT nullif(au.email, '') INTO v_account_email
    FROM auth.users au WHERE au.id = p_user_id;

  RETURN QUERY
  UPDATE public.profiles_talent t
     SET deletion_requested_at = now(),
         is_public             = false   -- explicit: the trust guard does not run under service_role
   WHERE t.user_id = p_user_id
     AND t.deletion_requested_at IS NULL
  RETURNING t.id,
            t.stage_name,
            coalesce(v_account_email, nullif(t.email, '')),
            nullif(t.email, ''),
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

revoke all on function public.request_profile_deletion(uuid) from public, anon, authenticated;
grant execute on function public.request_profile_deletion(uuid) to service_role;