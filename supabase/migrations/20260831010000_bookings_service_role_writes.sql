-- =====================================================================
-- bookings: service-role-only writes + status transition guard
-- Todoist: 6hPq7j7jFhF6Xx65
--
-- Before this migration any authenticated user could insert a bookings
-- row naming themselves as client_user_id with booking_status set
-- directly to 'completed', then satisfy reviews_star_client_insert
-- perfectly and post a review for a talent they never hired. Repeated
-- with fresh accounts, that drives a rival's average to 1.0.
--
-- Bookings are now created and updated only by the orchestration
-- service (service_role), from an accepted quote. Cancellation goes
-- through the service too, by decision 2026-08-31 -- cancellation
-- carries deposit and refund consequences that a bare status flip
-- cannot express.
-- =====================================================================

-- 1. No client-side insert path. Verified 2026-08-31: nothing in either
--    repo inserts into bookings, so this drops an unused policy.
drop policy if exists "bookings_client_insert" on public.bookings;

-- 2. No client-side update path either.
--
--    NOTE: this silently breaks VenueDashboard.tsx:391, which does
--    .update({ booking_status: 'cancelled' }). PostgREST does not error
--    when RLS matches no rows -- it returns success having changed
--    nothing, so the button will appear to work and the booking will
--    stay live. Must be repointed at the cancellation Edge Function.
drop policy if exists "bookings_client_update" on public.bookings;

-- service_role_full_access remains and is now the only write path.
-- bookings_participant_read remains: clients, talent and venues can
-- still see their own bookings.


-- =====================================================================
-- Status transition guard
--
-- Deliberately strict: this binds service_role and Directus as well as
-- clients. That is the point. Clients can no longer write at all after
-- the policy drops above, so the only remaining way a booking reaches
-- an impossible state is a bug in the orchestration service -- which is
-- exactly what this catches.
--
-- Directus connects as nocobase_admin with no JWT, so auth.uid() is
-- null and get_my_role() returns null. The usual
-- "IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin'" guard would
-- therefore exempt Directus by accident. It is deliberately not used.
--
-- Escape hatch, for genuine emergencies only:
--
--     begin;
--     set local en4.admin_override = 'on';
--     update public.bookings set booking_status = '...' where id = '...';
--     commit;
--
-- set local scopes it to the transaction, so it cannot leak into the
-- next statement. Directus never sets it, so ordinary admin edits stay
-- governed.
-- =====================================================================

create or replace function public.enforce_booking_status_transition()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if OLD.booking_status = NEW.booking_status then
    return NEW;
  end if;

  if current_setting('en4.admin_override', true) = 'on' then
    return NEW;
  end if;

  if not (
       (OLD.booking_status = 'pending'   and NEW.booking_status in ('confirmed', 'cancelled'))
    or (OLD.booking_status = 'confirmed' and NEW.booking_status in ('completed', 'cancelled', 'disputed'))
    or (OLD.booking_status = 'disputed'  and NEW.booking_status in ('completed', 'cancelled'))
  ) then
    raise exception
      'Illegal booking status transition: % -> %. Legal moves: pending->confirmed|cancelled, confirmed->completed|cancelled|disputed, disputed->completed|cancelled. completed and cancelled are terminal.',
      OLD.booking_status, NEW.booking_status
      using errcode = 'check_violation';
  end if;

  return NEW;
end;
$$;

revoke all on function public.enforce_booking_status_transition() from public, anon, authenticated;

drop trigger if exists trg_enforce_booking_status_transition on public.bookings;

create trigger trg_enforce_booking_status_transition
  before update of booking_status on public.bookings
  for each row execute function public.enforce_booking_status_transition();