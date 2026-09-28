-- 20260928031427_drop_pricing_per_session_and_pin_rate_updated_at.sql
--
-- Closes the rate leak, and a cooldown bypass found while closing it.
--
-- THE LEAK
-- --------
-- anon held SELECT on profiles_talent including pricing_per_session, and the
-- talent_select_public policy granted SELECT to public. The publishable key
-- ships in the frontend bundle by design, so this returned every listed
-- talent's rate to anyone, with no account and no probing:
--
--   curl '.../rest/v1/profiles_talent?select=stage_name,pricing_per_session' \
--        -H 'apikey: <publishable key>'
--
-- The UI was never where this lived - Audience-Interface never displayed the
-- rate at all. RLS could not fix it either: RLS gates ROWS, not columns, so a
-- policy letting a talent see other public profiles lets them see every granted
-- column on those rows. Revoking from anon alone would not have worked either,
-- since authenticated held the same grant and every talent has an account.
--
-- Dropping the column closes it by construction rather than by a grant someone
-- has to remember not to re-add (D-046). Rates have lived in talent_rates since
-- 20260927164332, which is owner-only.
--
-- ORDERING: Talent_Interface #96 removed the last frontend write FIRST and was
-- deployed before this ran. With the column gone and the app still sending it,
-- PostgREST rejects the upsert and profile saving breaks for every talent.
--
-- THE BYPASS, found while writing this
-- ------------------------------------
-- enforce_talent_rate_cooldown stamps rate_updated_at ONLY inside the
-- "amount changed" branch. A talent holds UPDATE on their own talent_rates rows
-- with no column-level restriction, so:
--
--   1. UPDATE talent_rates SET rate_updated_at = '2020-01-01'  (amount unchanged)
--      - the branch does not run, nothing overwrites it, the value is stored
--   2. change the amount - the cooldown reads OLD.rate_updated_at, sees 2020,
--      and passes
--
-- Same shape as the row-delete bypass the eight-permanent-rows design closed,
-- arriving through a column instead. Pinned in enforce_talent_rate_immutable
-- rather than in the cooldown, because a0_ sorts before a_ and the cooldown
-- must still be able to overwrite with now() when an amount genuinely changes.
--
-- Verified in a rolled-back transaction: rewinding rate_updated_at with amount
-- unchanged leaves the value untouched.
--
-- ALSO REMOVED
-- ------------
-- enforce_pricing_cooldown and its trigger (superseded by the per-category
-- cooldown), profiles_talent_pricing_range, and the two pricing_updated_at
-- lines in enforce_talent_trust_fields - that column is dropped here, and the
-- protection it gave now lives in the pin above.
--
-- VERIFIED AFTER APPLYING: both columns gone; old cooldown function and trigger
-- gone; constraint gone; no function still references pricing_per_session; the
-- rewind is blocked; a rate still resolves through price_range_for_amount; and
-- the curl above returns 42703 rather than data.

begin;

create or replace function public.enforce_talent_rate_immutable()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  NEW.id              := OLD.id;
  NEW.talent_id       := OLD.talent_id;
  NEW.category        := OLD.category;
  NEW.created_at      := OLD.created_at;
  NEW.rate_updated_at := OLD.rate_updated_at;
  return NEW;
end;
$$;

drop trigger if exists talent_pricing_cooldown on public.profiles_talent;
drop function if exists public.enforce_pricing_cooldown();

create or replace function public.enforce_talent_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  caller_role text := public.get_my_role();
BEGIN
  IF caller_role = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.is_verified          := false;
    NEW.is_featured          := false;
    NEW.rating               := NULL;
    NEW.total_bookings       := 0;
    NEW.approved_at          := NULL;
    NEW.approved_by          := NULL;
    NEW.rejection_reason     := NULL;
    NEW.rejection_note       := NULL;
    IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
      NEW.approval_status := 'draft'::approval_status;
    END IF;
  ELSE
    NEW.is_verified          := OLD.is_verified;
    NEW.is_featured          := OLD.is_featured;
    NEW.rating               := OLD.rating;
    NEW.total_bookings       := OLD.total_bookings;
    NEW.approved_at          := OLD.approved_at;
    NEW.approved_by          := OLD.approved_by;
    NEW.rejection_reason     := OLD.rejection_reason;
    NEW.rejection_note       := OLD.rejection_note;

    -- Note: this COERCES rather than raising, so a disallowed transition
    -- returns 200 with nothing changed. Any legitimate caller changing a
    -- trust-guarded field must read the value back, not test for an error.
    IF NOT (OLD.approval_status IN ('draft', 'rejected')
            AND NEW.approval_status = 'pending_approval') THEN
      NEW.approval_status := OLD.approval_status;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

alter table public.profiles_talent
  drop constraint if exists profiles_talent_pricing_range;

alter table public.profiles_talent
  drop column if exists pricing_per_session,
  drop column if exists pricing_updated_at;

comment on function public.enforce_talent_rate_immutable() is
  'Pins the structural columns of talent_rates, including rate_updated_at. Without that pin a talent could set rate_updated_at to a past date in an update that left amount unchanged, then change the amount and pass the 30-day cooldown against the value they supplied.';

commit;