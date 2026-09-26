-- Talent "Delete my profile", request half. Spec: Todoist 6hcPC3qXjH55JpQ5 / 6hcJcMmFc69pgcQ5.
-- The profile row is NEVER deleted; erasure is anonymise-in-place by an admin later.
-- profile_status is deliberately untouched: 'inactive' belongs to the separate
-- dormant feature, so "requested deletion" and "taking a break" stay distinguishable.

alter table public.profiles_talent
  add column if not exists deletion_requested_at timestamptz;

comment on column public.profiles_talent.deletion_requested_at is
  'Set when the talent requests deletion. Hides the profile and blocks new quote requests. Non-admins may set it once and can never clear it: withdrawal is admin-only. Admin erasure is due within 14 calendar days.';

-- 1. Trust guard: the one allowed transition, and no way back.
create or replace function public.enforce_talent_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified           := false;
      NEW.is_public             := false;
      NEW.profile_status        := 'pending'::talent_status;
      NEW.rating                := 0.00;
      NEW.pricing_updated_at    := NULL;
      NEW.deletion_requested_at := NULL;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified        := OLD.is_verified;
      NEW.is_public          := OLD.is_public;
      NEW.profile_status     := OLD.profile_status;
      NEW.rating             := OLD.rating;
      NEW.pricing_updated_at := OLD.pricing_updated_at;

      IF OLD.deletion_requested_at IS NOT NULL THEN
        -- Already requested. Immovable: only an admin can withdraw it.
        NEW.deletion_requested_at := OLD.deletion_requested_at;
      ELSIF NEW.deletion_requested_at IS NOT NULL THEN
        -- The one permitted transition. Server clock, never the client's.
        NEW.deletion_requested_at := now();
        NEW.is_public             := false;
      END IF;

      -- Submitting for approval is barred once deletion is requested, so a
      -- hidden profile cannot walk itself back into the review queue.
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval'
              AND NEW.deletion_requested_at IS NULL) THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 2. The gate. In a trigger, not only in the RPC, so a direct PostgREST
--    update cannot step around it.
create or replace function public.check_talent_deletion_gate()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  blockers text[] := '{}';
  n int;
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO n FROM public.bookings b
   WHERE b.talent_id = NEW.id
     AND b.booking_status IN ('pending','confirmed','disputed');
  IF n > 0 THEN
    blockers := array_append(blockers, n || ' booking(s) still open');
  END IF;

  SELECT count(*) INTO n FROM public.quote_requests qr
   WHERE qr.talent_id = NEW.id
     AND qr.status IN ('open','matched');
  IF n > 0 THEN
    blockers := array_append(blockers, n || ' quote request(s) awaiting your reply');
  END IF;

  SELECT count(*) INTO n FROM public.quotes q
   WHERE q.talent_id = NEW.id
     AND q.quote_status = 'pending';
  IF n > 0 THEN
    blockers := array_append(blockers, n || ' quote(s) you have sent still awaiting a decision');
  END IF;

  IF array_length(blockers, 1) > 0 THEN
    RAISE EXCEPTION
      'Your profile cannot be deleted yet: %. Please close these first, or contact us for help.',
      array_to_string(blockers, '; ')
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

drop trigger if exists check_talent_deletion_gate on public.profiles_talent;
create trigger check_talent_deletion_gate
  before update on public.profiles_talent
  for each row
  when (OLD.deletion_requested_at IS NULL AND NEW.deletion_requested_at IS NOT NULL)
  execute function public.check_talent_deletion_gate();

-- 3. The polite door. SECURITY INVOKER: RLS decides whose row this is, and the
--    caller's own uid resolves the row, so it cannot be aimed at anyone else.
create or replace function public.request_profile_deletion()
returns timestamptz
language plpgsql
security invoker
set search_path to 'public'
as $function$
DECLARE
  v_when timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to request deletion.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles_talent
     SET deletion_requested_at = now()
   WHERE user_id = auth.uid()
     AND deletion_requested_at IS NULL
  RETURNING deletion_requested_at INTO v_when;

  IF v_when IS NULL THEN
    IF EXISTS (SELECT 1 FROM public.profiles_talent
                WHERE user_id = auth.uid() AND deletion_requested_at IS NOT NULL) THEN
      RAISE EXCEPTION 'A deletion request is already in progress for this profile.'
        USING ERRCODE = '42501';
    END IF;
    RAISE EXCEPTION 'No talent profile found for this account.' USING ERRCODE = '42501';
  END IF;

  RETURN v_when;
END;
$function$;

revoke all on function public.request_profile_deletion() from public, anon;
grant execute on function public.request_profile_deletion() to authenticated;