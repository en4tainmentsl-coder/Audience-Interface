-- The deletion request must go through the request-deletion Edge Function, so
-- that the talent confirmation and the admin alert are always sent. Same shape
-- as accept_quote_and_create_booking: service_role only, REVOKEd from
-- authenticated, so it cannot be reached from the browser.
--
-- ⚠️ Under service_role auth.uid() is NULL, so enforce_talent_trust_fields
-- SKIPS ENTIRELY (its whole block is gated on auth.uid() IS NOT NULL). It will
-- NOT force is_public = false here. This function must set it explicitly.
-- check_talent_deletion_gate still fires: it only returns early for an admin.

drop function if exists public.request_profile_deletion();

create or replace function public.request_profile_deletion(p_user_id uuid)
returns table (talent_id uuid, stage_name text, email text, requested_at timestamptz)
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'A user id is required.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  UPDATE public.profiles_talent t
     SET deletion_requested_at = now(),
         is_public             = false   -- explicit: the trust guard does not run here
   WHERE t.user_id = p_user_id
     AND t.deletion_requested_at IS NULL
  RETURNING t.id, t.stage_name, t.email, t.deletion_requested_at;

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