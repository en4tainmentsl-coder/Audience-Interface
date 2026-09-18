-- 20260917190000_fix_trust_guard_null_role_bypass.sql
--
-- Closes a privilege bypass in five trust-field guards.
--
-- THE BUG
-- -------
-- get_my_role() is:
--     SELECT role::text FROM public.profiles_users WHERE id = auth.uid() LIMIT 1;
-- It returns NULL — not an error — when the caller holds a valid session but has
-- no profiles_users row.
--
-- Five guards gate their pins as:
--     IF auth.uid() IS NOT NULL AND get_my_role() <> 'admin' THEN
--
-- With a NULL role, `NULL <> 'admin'` evaluates to NULL, which is not TRUE, so the
-- IF does not fire and THE ENTIRE GUARD BODY IS SKIPPED. Every column those guards
-- exist to pin becomes freely writable by the caller.
--
-- Guards written the other way round — `IF auth.uid() IS NULL OR get_my_role() =
-- 'admin' THEN RETURN NEW;` — are unaffected: NULL there fails to early-return, so
-- the guard still runs. enforce_user_trust_fields, enforce_message_writes and
-- enforce_payout_account_trust_fields are already correct and are NOT touched here.
--
-- WHY IT IS LIVE NOW
-- ------------------
-- Nothing creates a profiles_users row automatically. There is no trigger on
-- auth.users and no signup-handler function anywhere in the database — verified
-- 2026-09-17. Every profiles_users row to date was created by hand.
--
-- Google OAuth went live 2026-09-17. The first OAuth user (adb4ab47-944b-4ea1-9016
-- -2d603533c201) holds a session with NO profiles_users row, and is therefore in the
-- bypassing state right now. So will every subsequent OAuth user until an onboarding
-- path exists.
--
-- Worked exploit, before this migration:
--   INSERT INTO profiles_talent (user_id, full_name, primary_genre_id,
--                                is_public, is_verified, approval_status)
--   VALUES (auth.uid(), 'x', <any genre>, true, true, 'approved');
-- talent_profile_manage_own grants ALL to authenticated WHERE auth.uid() = user_id,
-- and talent_select_public exposes any row WHERE is_public = true to anon. The
-- result is a self-approved, self-verified, publicly readable talent profile.
--
-- THE FIX
-- -------
--     get_my_role() IS DISTINCT FROM 'admin'
--
-- NULL IS DISTINCT FROM 'admin' is TRUE, so the guard fires for a roleless caller.
-- Behaviour is unchanged for every real role: 'talent', 'client' and 'venue' were
-- already distinct from 'admin', and 'admin' still bypasses.
--
-- Function bodies below are reproduced verbatim from pg_get_functiondef() read live
-- on 2026-09-17. The ONLY change in each is the gate comparison.
--
-- Related: D-023 records all four profile guards as compliant. That audit verified
-- the guards exist and pin the correct columns; it did not test them with a NULL
-- role. See EN4_DECISION_REGISTER Standing Corrections.

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
--    ordering are unchanged.
--
-- 2. Function privileges are NOT re-granted or re-revoked. CREATE OR REPLACE
--    preserves the existing ACL. Per D-026, verify pg_proc.proacl afterwards
--    anyway if anything looks off — but no change is expected.
--
-- 3. This does NOT fix talent_select_public, which reads
--      USING (is_public = true)
--    and checks neither approval_status nor is_verified. That remains open. This
--    migration removes the ability to SET is_public without admin rights, which
--    makes that policy far harder to abuse, but it does not make it correct.
--
-- 4. This does NOT create profiles_users rows. The underlying condition — a valid
--    session with no profile row — still exists and still needs an onboarding path.
--    This migration makes that state safe rather than eliminating it.
