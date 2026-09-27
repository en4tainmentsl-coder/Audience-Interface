-- 20260917190000_fix_trust_guard_null_role_bypass.sql
--
-- Makes five trust-field guards fail closed when get_my_role() returns NULL.
--
-- SEVERITY: LATENT, NOT LIVE. An earlier version of this comment block, and the
-- description of PR #113, claimed a live exploitable bypass and included a worked
-- exploit. That was wrong and is corrected here. See the PR thread for the full
-- correction. Tracked as Todoist 6hX2G6fqHXXRWVhX.
--
-- THE DEFECT
-- ----------
-- get_my_role() returns NULL - not an error - when the caller holds a valid session
-- but has no profiles_users row.
--
-- Five guards gated their pins as:
--     IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
-- With a NULL role, `NULL <> 'admin'` is NULL, not TRUE, so the IF does not fire and
-- the entire guard body is skipped.
--
-- The idiom split is the point worth remembering:
--   IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN RETURN NEW;
--     -> fails CLOSED on NULL. Correct. Used by enforce_user_trust_fields,
--        enforce_message_writes, enforce_payout_account_trust_fields. Not touched.
--   IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
--     -> fails OPEN on NULL. Was used by the five functions below.
--
-- WHY IT WAS NOT EXPLOITABLE
-- --------------------------
-- Every surface these five guards protect was already masked:
--
--   profiles_talent    FK user_id -> profiles_users(id)
--   profiles_clients   FK user_id -> profiles_users(id)
--   profiles_venues    FK user_id -> profiles_users(id) ON DELETE CASCADE
--   quotes             no INSERT policy for `authenticated` at all; service_role only
--
-- enforce_featured_requires_admin sits on profiles_talent, so the same FK covers it.
--
-- A caller with no profiles_users row cannot insert into any of them - verified
-- 2026-09-17 through a real authenticated session, which returned
--     409  23503  Key is not present in table "profiles_users".
-- A caller who has a profiles_users row returns a non-NULL role, so the guard fires
-- normally. The NULL window is unreachable on every guarded surface.
--
-- It becomes live if any of those FKs is dropped, if an INSERT policy is added to
-- quotes for `authenticated`, or if a new guard uses the failing-open idiom on a
-- table without that FK. None of those masks is documented as load-bearing, which is
-- the reason to fix the guards rather than rely on them.
--
-- THE FIX
-- -------
--     get_my_role() IS DISTINCT FROM 'admin'
-- NULL IS DISTINCT FROM 'admin' is TRUE, so the guard fires for a roleless caller.
-- No behaviour change for any real role.
--
-- Function bodies below are reproduced verbatim from pg_get_functiondef() read live
-- on 2026-09-17. The ONLY change in each is the gate comparison.
--
-- VERIFIED
-- --------
-- Regression tested 2026-09-18 through a real session with role = 'talent'. An
-- insert requesting is_public true, is_verified true, approval_status 'approved'
-- landed as false / false / draft, with profile_status pending, rating 0.00,
-- is_featured false. The replacement did not break the guards that already worked.
--
-- Related: D-023 records all four profile guards as compliant. That audit verified
-- they exist and pin the correct columns; it did not test them with a NULL role.

BEGIN;

-- 1. profiles_talent -----------------------------------------------------------
-- Pins: is_verified, is_public, profile_status, rating, pricing_updated_at,
--       approval_status (draft -> pending_approval is the only allowed transition).

CREATE OR REPLACE FUNCTION public.enforce_talent_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified        := false;
      NEW.is_public          := false;
      NEW.profile_status     := 'pending'::talent_status;
      NEW.rating             := 0.00;
      NEW.pricing_updated_at := NULL;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified        := OLD.is_verified;
      NEW.is_public          := OLD.is_public;
      NEW.profile_status     := OLD.profile_status;
      NEW.rating             := OLD.rating;
      NEW.pricing_updated_at := OLD.pricing_updated_at;
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 2. profiles_clients ----------------------------------------------------------
-- Pins: approval_status.

CREATE OR REPLACE FUNCTION public.enforce_client_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 3. profiles_venues -----------------------------------------------------------
-- Pins: is_verified, approval_status.

CREATE OR REPLACE FUNCTION public.enforce_venue_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified := false;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified := OLD.is_verified;
      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval') THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 4. profiles_talent featuring -------------------------------------------------
-- Forces is_featured and its four companion columns back to unfeatured for any
-- non-admin. Under the bug a roleless caller could self-feature onto the homepage.

CREATE OR REPLACE FUNCTION public.enforce_featured_requires_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.is_featured = true AND auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    NEW.is_featured := false;
    NEW.feature_sort_order := NULL;
    NEW.featured_expires_at := NULL;
    NEW.featured_by := NULL;
    NEW.featured_at := NULL;
  END IF;
  RETURN NEW;
END;
$function$;

-- 5. quotes --------------------------------------------------------------------
-- NOTE: this function contains BOTH idioms. Only the INSERT gate is vulnerable and
-- only it is changed. The UPDATE gate further down reads
--   IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN RETURN NEW;
-- which already fails closed on a NULL role and is left exactly as it is.
--
-- The INSERT gate pins commission_rate_percent := 21.00 and quote_status :=
-- 'pending'. Under the bug a roleless caller could insert a quote at 0% commission
-- in an already-accepted state, bypassing D-003.

CREATE OR REPLACE FUNCTION public.enforce_quote_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req_rate      numeric;
  req_hours     numeric;
  req_talent    uuid;
  parent_status quotation_request_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT qr.talent_rate_at_request, qr.duration_hours, qr.talent_id
      INTO req_rate, req_hours, req_talent
      FROM public.quote_requests qr
     WHERE qr.id = NEW.quote_request_id;

    IF req_rate IS NULL THEN
      RAISE EXCEPTION
        'Cannot price a quote: quote_request % has no talent_rate_at_request.',
        NEW.quote_request_id
        USING ERRCODE = '22004';
    END IF;

    -- A quote always belongs to the talent the request named.
    NEW.talent_id     := req_talent;
    NEW.quoted_amount := round(req_rate * greatest(1, req_hours / 4), 2);

    NEW.created_at := now();
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
      NEW.commission_rate_percent := 21.00;
      NEW.quote_status            := 'pending'::quotation_status;
    END IF;

    RETURN NEW;
  END IF;

  NEW.id               := OLD.id;
  NEW.quote_request_id := OLD.quote_request_id;
  NEW.talent_id        := OLD.talent_id;
  NEW.quoted_amount    := OLD.quoted_amount;
  NEW.created_at       := OLD.created_at;
  NEW.updated_at       := now();

  IF NEW.quote_status = 'accepted'::quotation_status
     AND OLD.quote_status IS DISTINCT FROM NEW.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;

    IF parent_status NOT IN ('open'::quotation_request_status,
                             'matched'::quotation_request_status) THEN
      RAISE EXCEPTION
        'Cannot accept a quote whose request is %. Acceptance requires a live request.',
        parent_status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  NEW.commission_rate_percent := OLD.commission_rate_percent;
  NEW.sent_at                 := OLD.sent_at;
  NEW.expires_at              := OLD.expires_at;

  IF NEW.quote_status IS DISTINCT FROM OLD.quote_status THEN
    SELECT qr.status INTO parent_status
      FROM public.quote_requests qr WHERE qr.id = OLD.quote_request_id;

    IF NOT (OLD.quote_status = 'pending'::quotation_status
            AND NEW.quote_status = 'expired'::quotation_status
            AND parent_status IN ('cancelled'::quotation_request_status,
                                  'expired'::quotation_request_status,
                                  'declined'::quotation_request_status)) THEN
      RAISE EXCEPTION
        'A talent cannot change quote_status. Acceptance and rejection are client actions handled by the orchestration service.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

COMMIT;

-- NOT DONE HERE, deliberately:
--
-- 1. No trigger is created or dropped. CREATE OR REPLACE FUNCTION leaves every
--    existing trigger binding intact; the a_-prefixed trigger names and their
--    ordering are unchanged. Confirmed after apply: 1 trigger bound per function.
--
-- 2. Function privileges are NOT re-granted or re-revoked. CREATE OR REPLACE
--    preserves the existing ACL. Confirmed unchanged after apply, including the
--    pre-existing anon=X / PUBLIC=X grants on four of the five, which are the
--    D-026 pattern for SECURITY DEFINER trigger functions and are left alone.
--
-- 3. This does NOT fix talent_select_public, which reads
--      USING (is_public = true)
--    and checks neither approval_status nor is_verified. That remains open.
--
-- 4. This does NOT create profiles_users rows. A session with no profiles_users row
--    still cannot create any profile row - the FKs above block it - so that state is
--    a functional gap in onboarding, not a security one.
