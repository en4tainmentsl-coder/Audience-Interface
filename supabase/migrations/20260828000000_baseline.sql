-- Extension dependencies. pg_dump omits these even for extensions installed
-- in the dumped schema, because the objects belong to the extension rather
-- than the schema -- so a dump alone cannot rebuild a database that uses them.
--
-- btree_gist is required by bookings_no_talent_double_booking, an EXCLUDE
-- constraint using gist over a uuid column; gist has no default operator
-- class for uuid without it.
--
-- NOTE: installed in public on production, which is NOT the Supabase
-- convention (every other extension is in extensions). Declared here as it
-- actually is, so this file reproduces production. Relocating it is tracked
-- separately.
CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA "public";

-- ── Role dependency ────────────────────────────────────────────────────────
-- nocobase_admin is a cluster-level role, not a schema object, so pg_dump
-- never emits it -- but the GRANT statements later in this file reference it
-- and fail with "role does not exist" without it.
--
-- The name is historical: NocoBase was abandoned (its FDW plugin hardcodes a
-- BEFORE INSERT trigger that cannot work on views), and this role now serves
-- Directus. Renaming it is a separate exercise.
--
-- Deliberately created WITHOUT a password and WITHOUT BYPASSRLS, unlike
-- production:
--
--   * A password in a committed migration is a credential in source control.
--     Set it out of band on any real environment.
--   * BYPASSRLS is the single most consequential privilege in this database --
--     it is what lets the admin panel read every row regardless of policy.
--     Granting it from a file makes it trivially easy to apply somewhere it
--     was never intended. Grant it deliberately, per environment.
--
-- Consequence: a database rebuilt from this file has a role that RESOLVES the
-- grants below but cannot log in and cannot bypass RLS. That is correct for a
-- shadow or CI database. For a real staging environment, set the password and
-- decide on BYPASSRLS explicitly.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'nocobase_admin') THEN
    CREATE ROLE "nocobase_admin" NOLOGIN;
  END IF;
END
$$;





SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."admin_level" AS ENUM (
    'super_admin',
    'manager',
    'partner',
    'support',
    'executive'
);


ALTER TYPE "public"."admin_level" OWNER TO "postgres";


CREATE TYPE "public"."approval_status" AS ENUM (
    'draft',
    'pending_approval',
    'approved',
    'rejected'
);


ALTER TYPE "public"."approval_status" OWNER TO "postgres";


CREATE TYPE "public"."audit_action" AS ENUM (
    'insert',
    'update',
    'delete',
    'login',
    'approve',
    'reject'
);


ALTER TYPE "public"."audit_action" OWNER TO "postgres";


CREATE TYPE "public"."auth_code_types" AS ENUM (
    'deposit',
    'full_payment',
    'credit_draw',
    'refund_credit'
);


ALTER TYPE "public"."auth_code_types" OWNER TO "postgres";


CREATE TYPE "public"."auth_status" AS ENUM (
    'active',
    'used',
    'expired',
    'cancelled'
);


ALTER TYPE "public"."auth_status" OWNER TO "postgres";


CREATE TYPE "public"."availability_blocked_reason" AS ENUM (
    'booking',
    'personal',
    'holiday',
    'travel',
    'other'
);


ALTER TYPE "public"."availability_blocked_reason" OWNER TO "postgres";


CREATE TYPE "public"."booking_status" AS ENUM (
    'pending',
    'confirmed',
    'cancelled',
    'completed',
    'disputed'
);


ALTER TYPE "public"."booking_status" OWNER TO "postgres";


CREATE TYPE "public"."client_approval_type" AS ENUM (
    'credit_card',
    'deferred_payment',
    'corporate_account'
);


ALTER TYPE "public"."client_approval_type" OWNER TO "postgres";


CREATE TYPE "public"."client_payment_type" AS ENUM (
    'card',
    'bank_transfer',
    'authorization_code',
    'corporate_account'
);


ALTER TYPE "public"."client_payment_type" OWNER TO "postgres";


CREATE TYPE "public"."contract_status" AS ENUM (
    'draft',
    'sent',
    'signed_by_talent',
    'signed_by_venue',
    'fully_signed',
    'void'
);


ALTER TYPE "public"."contract_status" OWNER TO "postgres";


CREATE TYPE "public"."equipment_responsibility" AS ENUM (
    'talent',
    'venue',
    'shared'
);


ALTER TYPE "public"."equipment_responsibility" OWNER TO "postgres";


CREATE TYPE "public"."events_status" AS ENUM (
    'draft',
    'published',
    'booked',
    'cancelled',
    'completed'
);


ALTER TYPE "public"."events_status" OWNER TO "postgres";


CREATE TYPE "public"."events_type" AS ENUM (
    'wedding',
    'corporate',
    'birthday',
    'concert',
    'private',
    'dinner_service',
    'lunch_service',
    'other'
);


ALTER TYPE "public"."events_type" OWNER TO "postgres";


CREATE TYPE "public"."kyc_status" AS ENUM (
    'pending',
    'submitted',
    'verified',
    'rejected'
);


ALTER TYPE "public"."kyc_status" OWNER TO "postgres";


CREATE TYPE "public"."notifications_channel" AS ENUM (
    'push',
    'email',
    'sms',
    'in_app'
);


ALTER TYPE "public"."notifications_channel" OWNER TO "postgres";


CREATE TYPE "public"."notifications_type" AS ENUM (
    'booking_confirmed',
    'booking_cancelled',
    'booking_completed',
    'booking_pending',
    'quote_received',
    'quote_accepted',
    'quote_rejected',
    'payment_received',
    'payout_processed',
    'payout_failed',
    'star_review_received',
    'heart_review_received',
    'message_received',
    'kyc_approved',
    'kyc_rejected',
    'contract_signed',
    'system_alert'
);


ALTER TYPE "public"."notifications_type" OWNER TO "postgres";


CREATE TYPE "public"."payments_flow" AS ENUM (
    'immediate',
    'deferred',
    'escrow'
);


ALTER TYPE "public"."payments_flow" OWNER TO "postgres";


CREATE TYPE "public"."payments_methods" AS ENUM (
    'card',
    'bank_transfer',
    'payhere',
    'authorization_code'
);


ALTER TYPE "public"."payments_methods" OWNER TO "postgres";


CREATE TYPE "public"."payments_status" AS ENUM (
    'pending',
    'completed',
    'failed',
    'refunded',
    'disputed'
);


ALTER TYPE "public"."payments_status" OWNER TO "postgres";


CREATE TYPE "public"."payments_types" AS ENUM (
    'deposit',
    'balance',
    'refund',
    'adjustment'
);


ALTER TYPE "public"."payments_types" OWNER TO "postgres";


CREATE TYPE "public"."payout_schedule" AS ENUM (
    'daily',
    'weekly',
    'monthly',
    'manual'
);


ALTER TYPE "public"."payout_schedule" OWNER TO "postgres";


CREATE TYPE "public"."payout_status" AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed',
    'reversed'
);


ALTER TYPE "public"."payout_status" OWNER TO "postgres";


CREATE TYPE "public"."quotation_request_status" AS ENUM (
    'open',
    'matched',
    'expired',
    'cancelled',
    'converted',
    'declined'
);


ALTER TYPE "public"."quotation_request_status" OWNER TO "postgres";


CREATE TYPE "public"."quotation_status" AS ENUM (
    'pending',
    'accepted',
    'rejected',
    'expired',
    'countered'
);


ALTER TYPE "public"."quotation_status" OWNER TO "postgres";


CREATE TYPE "public"."quote_decline_reason" AS ENUM (
    'schedule_conflict',
    'outside_service_area',
    'event_type_mismatch',
    'other'
);


ALTER TYPE "public"."quote_decline_reason" OWNER TO "postgres";


CREATE TYPE "public"."related_entity_type" AS ENUM (
    'talent',
    'booking',
    'contract',
    'venue',
    'payment'
);


ALTER TYPE "public"."related_entity_type" OWNER TO "postgres";


CREATE TYPE "public"."revenue_type" AS ENUM (
    'commission',
    'subscription',
    'advert',
    'adjustment',
    'other'
);


ALTER TYPE "public"."revenue_type" OWNER TO "postgres";


CREATE TYPE "public"."subscription_plan" AS ENUM (
    'free',
    'basic',
    'pro',
    'agency'
);


ALTER TYPE "public"."subscription_plan" OWNER TO "postgres";


CREATE TYPE "public"."subscription_status" AS ENUM (
    'active',
    'cancelled',
    'expired',
    'trialing',
    'paused'
);


ALTER TYPE "public"."subscription_status" OWNER TO "postgres";


CREATE TYPE "public"."talent_media_resource_type" AS ENUM (
    'image',
    'video',
    'raw',
    'audio'
);


ALTER TYPE "public"."talent_media_resource_type" OWNER TO "postgres";


CREATE TYPE "public"."talent_media_type" AS ENUM (
    'profile_photo',
    'gallery',
    'trailer',
    'live_performance',
    'press_kit',
    'document'
);


ALTER TYPE "public"."talent_media_type" OWNER TO "postgres";


CREATE TYPE "public"."talent_status" AS ENUM (
    'pending',
    'active',
    'suspended',
    'inactive'
);


ALTER TYPE "public"."talent_status" OWNER TO "postgres";


CREATE TYPE "public"."talent_type" AS ENUM (
    'solo',
    'duo',
    '3-piece',
    'full band',
    'dj'
);


ALTER TYPE "public"."talent_type" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'client',
    'venue',
    'talent',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."user_status" AS ENUM (
    'active',
    'suspended',
    'banned',
    'pending'
);


ALTER TYPE "public"."user_status" OWNER TO "postgres";


CREATE TYPE "public"."venue_account_purpose" AS ENUM (
    'payment',
    'payout'
);


ALTER TYPE "public"."venue_account_purpose" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_client_age"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.role = 'client'
     AND NEW.date_of_birth IS NOT NULL
     AND NOT is_18_or_over(NEW.date_of_birth) THEN
    RAISE EXCEPTION 'Client must be 18 or older. Registration cannot proceed with the provided date of birth.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_client_age"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_client_approvals_venue_only"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role text;
BEGIN
  IF NEW.venue_user_id IS NOT NULL THEN
    SELECT role INTO v_role FROM profiles_users WHERE id = NEW.venue_user_id;

    IF v_role IS NULL THEN
      RAISE EXCEPTION 'venue_user_id does not reference an existing profiles_users row.'
        USING ERRCODE = '23503';
    ELSIF v_role <> 'venue' THEN
      RAISE EXCEPTION 'client_approvals.venue_user_id must reference a user with role = venue (found role = %).', v_role
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_client_approvals_venue_only"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_client_dob_before_submission"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_dob date;
BEGIN
  IF NEW.approval_status IN ('pending_approval', 'approved') THEN
    IF NEW.user_id IS NULL THEN
      RAISE EXCEPTION 'Client profile has no linked user account; cannot verify date of birth before submission.'
        USING ERRCODE = '23514';
    END IF;

    SELECT date_of_birth INTO v_dob
    FROM profiles_users
    WHERE id = NEW.user_id;

    IF v_dob IS NULL THEN
      RAISE EXCEPTION 'Date of birth is required before a client profile can be submitted for approval.'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_client_dob_before_submission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_talent_age"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL AND NOT is_18_or_over(NEW.date_of_birth) THEN
    RAISE EXCEPTION 'Talent must be 18 or older. Registration cannot proceed with the provided date of birth.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_talent_age"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_talent_dob_before_submission"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.approval_status IN ('pending_approval', 'approved')
     AND NEW.date_of_birth IS NULL THEN
    RAISE EXCEPTION 'Date of birth is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_talent_dob_before_submission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_talent_pricing_before_submission"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.approval_status IN ('pending_approval', 'approved')
     AND NEW.pricing_per_session IS NULL THEN
    RAISE EXCEPTION 'A starting rate is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_talent_pricing_before_submission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) RETURNS numeric
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    SET "search_path" TO 'public'
    AS $$
  SELECT round((6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * power(sin(radians(lon2 - lon1) / 2), 2)
  )))::numeric, 2);
$$;


ALTER FUNCTION "public"."distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_featured_requires_admin"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.is_featured = true AND auth.uid() IS NOT NULL AND get_my_role() != 'admin' THEN
    NEW.is_featured := false;
    NEW.feature_sort_order := NULL;
    NEW.featured_expires_at := NULL;
    NEW.featured_by := NULL;
    NEW.featured_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_featured_requires_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_pricing_cooldown"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  caller_role text := public.get_my_role();
BEGIN
  IF NEW.pricing_per_session IS DISTINCT FROM OLD.pricing_per_session THEN

    IF caller_role = 'talent' THEN
      IF OLD.pricing_updated_at IS NOT NULL
         AND OLD.pricing_updated_at > now() - interval '30 days' THEN
        RAISE EXCEPTION 'Your starting rate can only be changed once every 30 days. Next change available %.',
          to_char(OLD.pricing_updated_at + interval '30 days', 'DD Mon YYYY')
          USING ERRCODE = '23514';
      END IF;
      -- Only a talent's own change starts their clock. An admin correction
      -- should not cost the talent their next 30 days.
      NEW.pricing_updated_at := now();
    END IF;

  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_pricing_cooldown"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT role::text
  FROM public.profiles_users
  WHERE id = auth.uid()
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_my_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nic_hmac_key"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'vault'
    AS $$
DECLARE
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'nic_hmac_key'
  LIMIT 1;

  IF v_key IS NULL THEN
    RAISE EXCEPTION 'nic_hmac_key not found in vault';
  END IF;

  RETURN v_key;
END;
$$;


ALTER FUNCTION "public"."get_nic_hmac_key"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_webhook_secret"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_secret TEXT;
BEGIN
  SELECT decrypted_secret
  INTO   v_secret
  FROM   vault.decrypted_secrets
  WHERE  name = 'webhook_secret'
  LIMIT  1;

  RETURN v_secret;
END;
$$;


ALTER FUNCTION "public"."get_webhook_secret"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_talent_approval"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.profile_status = 'active' AND OLD.profile_status != 'active' THEN
    NEW.is_public := true;
  END IF;

  IF NEW.profile_status IN ('suspended', 'inactive') THEN
    NEW.is_public := false;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_talent_approval"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_18_or_over"("dob" "date") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT dob IS NOT NULL AND dob <= (CURRENT_DATE - INTERVAL '18 years');
$$;


ALTER FUNCTION "public"."is_18_or_over"("dob" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_talent_available"("p_talent_id" "uuid", "p_starts_at" timestamp with time zone, "p_ends_at" timestamp with time zone, "p_buffer" interval DEFAULT '03:00:00'::interval) RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.talent_id = p_talent_id
      AND b.booking_status <> 'cancelled'
      AND tstzrange(b.starts_at - p_buffer, b.ends_at + p_buffer)
          && tstzrange(p_starts_at, p_ends_at)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.talent_unavailability u
    WHERE u.talent_id = p_talent_id
      AND tstzrange(u.starts_at, u.ends_at) && tstzrange(p_starts_at, p_ends_at)
  );
$$;


ALTER FUNCTION "public"."is_talent_available"("p_talent_id" "uuid", "p_starts_at" timestamp with time zone, "p_ends_at" timestamp with time zone, "p_buffer" interval) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_quote_expiry"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  event_start timestamptz;
BEGIN
  IF NEW.expires_at IS NULL THEN
    SELECT starts_at INTO event_start
    FROM public.quote_requests
    WHERE id = NEW.quote_request_id;

    NEW.expires_at := greatest(
      now() + interval '2 hours',
      least(coalesce(NEW.sent_at, now()) + interval '7 days',
            event_start - interval '72 hours')
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_quote_expiry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_talent_rate_at_request"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if TG_OP = 'INSERT' then
    select pt.pricing_per_session
      into new.talent_rate_at_request
      from public.profiles_talent pt
     where pt.id = new.talent_id;
  else
    -- Immutable after creation. Protects in-flight requests from later rate
    -- changes, and stops the client rewriting it through the FOR ALL policy.
    new.talent_rate_at_request := old.talent_rate_at_request;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."set_talent_rate_at_request"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "performed_by" "uuid",
    "table_name" "text" NOT NULL,
    "record_id" "uuid" NOT NULL,
    "action" "public"."audit_action" NOT NULL,
    "old_values" "jsonb",
    "new_values" "jsonb",
    "changed_fields" "text"[],
    "ip_address" "inet",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_audit_action" CHECK (("action" = ANY (ARRAY['insert'::"public"."audit_action", 'update'::"public"."audit_action", 'delete'::"public"."audit_action", 'login'::"public"."audit_action", 'approve'::"public"."audit_action", 'reject'::"public"."audit_action"])))
);

ALTER TABLE ONLY "public"."audit_log" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."authorization_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_approval_id" "uuid" NOT NULL,
    "client_user_id" "uuid" NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "code" "text",
    "code_type" "public"."auth_code_types" NOT NULL,
    "max_amount" numeric,
    "actual_amount" numeric,
    "is_used" boolean DEFAULT false,
    "used_in_payment_id" "uuid" NOT NULL,
    "used_at" timestamp with time zone NOT NULL,
    "generated_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone,
    "status" "public"."auth_status",
    "notes" "text",
    CONSTRAINT "chk_authcode_actual_positive" CHECK (("actual_amount" >= (0)::numeric)),
    CONSTRAINT "chk_authcode_max_positive" CHECK (("max_amount" > (0)::numeric)),
    CONSTRAINT "chk_authcode_status" CHECK (("status" = ANY (ARRAY['active'::"public"."auth_status", 'used'::"public"."auth_status", 'expired'::"public"."auth_status", 'cancelled'::"public"."auth_status"]))),
    CONSTRAINT "chk_authcode_type" CHECK (("code_type" = ANY (ARRAY['deposit'::"public"."auth_code_types", 'full_payment'::"public"."auth_code_types", 'credit_draw'::"public"."auth_code_types", 'refund_credit'::"public"."auth_code_types"])))
);

ALTER TABLE ONLY "public"."authorization_codes" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."authorization_codes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."availability" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "available_date_start" "date",
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone,
    "is_blocked" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "available_date_end" "date",
    "blocked_reason" "public"."availability_blocked_reason",
    CONSTRAINT "availability_blocked_reason_check" CHECK (((("is_blocked" = true) AND ("blocked_reason" IS NOT NULL)) OR (("is_blocked" = false) AND ("blocked_reason" IS NULL)))),
    CONSTRAINT "chk_availability_date_order" CHECK (("available_date_end" >= "available_date_start")),
    CONSTRAINT "chk_availability_time_order" CHECK (("end_time" > "start_time"))
);

ALTER TABLE ONLY "public"."availability" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quote_id" "uuid",
    "client_user_id" "uuid" NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "venue_id" "uuid",
    "agreed_gross_amount" numeric DEFAULT 0.00 NOT NULL,
    "commission_amount" numeric DEFAULT 0.00 NOT NULL,
    "talent_net_amount" numeric,
    "deposit_amount" numeric DEFAULT 0.00,
    "booking_status" "public"."booking_status" DEFAULT 'pending'::"public"."booking_status" NOT NULL,
    "contract_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" "uuid",
    "message_to_talent" "text",
    "currency" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "payment_advanced" boolean DEFAULT false NOT NULL,
    "payment_advanced_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "completed_by_user_id" "uuid",
    "auto_completed" boolean DEFAULT false NOT NULL,
    "gateway_fee_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "bank_charge_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "vat_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "sscl_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "client_total_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    CONSTRAINT "bookings_ends_after_starts" CHECK (("ends_at" > "starts_at")),
    CONSTRAINT "bookings_payment_advanced_check" CHECK (((("payment_advanced" = false) AND ("payment_advanced_at" IS NULL)) OR (("payment_advanced" = true) AND ("payment_advanced_at" IS NOT NULL)))),
    CONSTRAINT "bookings_total_adds_up_check" CHECK ((("client_total_amount" = 0.00) OR ("client_total_amount" = ((((("agreed_gross_amount" + "commission_amount") + "gateway_fee_amount") + "bank_charge_amount") + "vat_amount") + "sscl_amount")))),
    CONSTRAINT "chk_booking_commission_positive" CHECK (("commission_amount" >= (0)::numeric)),
    CONSTRAINT "chk_booking_currency_format" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_booking_deposit_positive" CHECK (("deposit_amount" >= (0)::numeric)),
    CONSTRAINT "chk_booking_gross_positive" CHECK (("agreed_gross_amount" >= (0)::numeric)),
    CONSTRAINT "chk_booking_net_positive" CHECK (("talent_net_amount" >= (0)::numeric)),
    CONSTRAINT "chk_booking_status" CHECK (("booking_status" = ANY (ARRAY['pending'::"public"."booking_status", 'confirmed'::"public"."booking_status", 'cancelled'::"public"."booking_status", 'completed'::"public"."booking_status", 'disputed'::"public"."booking_status"])))
);

ALTER TABLE ONLY "public"."bookings" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."bookings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."bookings"."agreed_gross_amount" IS 'The talent''s agreed fee — what the talent receives before deductions. NOT the client total.';



COMMENT ON COLUMN "public"."bookings"."commission_amount" IS 'En4tainment commission: 21% markup on agreed_gross_amount. Added on top, not deducted from it.';



COMMENT ON COLUMN "public"."bookings"."talent_net_amount" IS 'What the talent is actually paid out. Equals agreed_gross_amount unless deductions apply.';



COMMENT ON COLUMN "public"."bookings"."payment_advanced" IS 'Denormalised from payments.payment_status. Must be written in the same operation that confirms payment.';



COMMENT ON COLUMN "public"."bookings"."client_total_amount" IS 'Total charged to the client: agreed_gross + commission + gateway_fee + bank_charge + vat + sscl.';



CREATE TABLE IF NOT EXISTS "public"."client_approvals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_user_id" "uuid",
    "approved_by_user_id" "uuid" NOT NULL,
    "approval_type" "public"."client_approval_type" NOT NULL,
    "credit_limit" numeric DEFAULT 250000.00,
    "current_balance" numeric DEFAULT 0.00 NOT NULL,
    "available_credit" numeric DEFAULT 250000.00 NOT NULL,
    "payment_terms_days" smallint DEFAULT 30 NOT NULL,
    "approval_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "approved_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "last_reviewed_at" timestamp with time zone DEFAULT "now"(),
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "chk_approval_balance" CHECK (("current_balance" >= (0)::numeric)),
    CONSTRAINT "chk_approval_credit_limit" CHECK (("credit_limit" >= (0)::numeric)),
    CONSTRAINT "chk_approval_payment_terms" CHECK (("payment_terms_days" >= 0)),
    CONSTRAINT "chk_approval_status" CHECK (("approval_status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'suspended'::"text", 'revoked'::"text"]))),
    CONSTRAINT "chk_approval_type" CHECK (("approval_type" = ANY (ARRAY['credit_card'::"public"."client_approval_type", 'deferred_payment'::"public"."client_approval_type", 'corporate_account'::"public"."client_approval_type"])))
);

ALTER TABLE ONLY "public"."client_approvals" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_approvals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_payment_methods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "method_type" "public"."client_payment_type" NOT NULL,
    "gateway_token" "text" NOT NULL,
    "display_label" "text" DEFAULT ''::"text" NOT NULL,
    "card_brand" "text",
    "card_last_4" "text",
    "card_expiry_month" smallint NOT NULL,
    "card_expiry_year" smallint NOT NULL,
    "bank_name" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_cpm_card_last4" CHECK (("card_last_4" ~ '^[0-9]{4}$'::"text")),
    CONSTRAINT "chk_cpm_expiry_month" CHECK ((("card_expiry_month" >= 1) AND ("card_expiry_month" <= 12))),
    CONSTRAINT "chk_cpm_expiry_year" CHECK (("card_expiry_year" >= 2025)),
    CONSTRAINT "chk_cpm_method_type" CHECK (("method_type" = ANY (ARRAY['card'::"public"."client_payment_type", 'bank_transfer'::"public"."client_payment_type", 'authorization_code'::"public"."client_payment_type", 'corporate_account'::"public"."client_payment_type"])))
);

ALTER TABLE ONLY "public"."client_payment_methods" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."contracts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "title" "text" DEFAULT ''::"text" NOT NULL,
    "storage_path" "text",
    "content_text" "text",
    "status" "public"."contract_status" NOT NULL,
    "signed_by_talent_at" timestamp with time zone,
    "signed_by_venue_at" timestamp with time zone,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_contract_status" CHECK (("status" = ANY (ARRAY['draft'::"public"."contract_status", 'sent'::"public"."contract_status", 'signed_by_talent'::"public"."contract_status", 'signed_by_venue'::"public"."contract_status", 'fully_signed'::"public"."contract_status", 'void'::"public"."contract_status"])))
);

ALTER TABLE ONLY "public"."contracts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."contracts" OWNER TO "postgres";






























































































































































































CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "related_entity_type" "public"."related_entity_type" NOT NULL,
    "related_entity_id" "uuid" NOT NULL,
    "file_name" "text" NOT NULL,
    "storage_bucket" "text" NOT NULL,
    "file_path" "text" NOT NULL,
    "uploaded_by_user_id" "uuid" NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE ONLY "public"."documents" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "title" "text" DEFAULT ''::"text" NOT NULL,
    "description" "text" NOT NULL,
    "event_date" "date" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "capacity" smallint NOT NULL,
    "budget_min" numeric NOT NULL,
    "budget_max" numeric NOT NULL,
    "currency" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "genre_tags" "text" NOT NULL,
    "status" "public"."events_status" DEFAULT 'draft'::"public"."events_status" NOT NULL,
    "is_public" boolean DEFAULT true NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_event_budget_min" CHECK (("budget_min" >= (0)::numeric)),
    CONSTRAINT "chk_event_budget_range" CHECK (("budget_max" >= "budget_min")),
    CONSTRAINT "chk_event_capacity_positive" CHECK (("capacity" > 0)),
    CONSTRAINT "chk_event_currency_format" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_event_status" CHECK (("status" = ANY (ARRAY['draft'::"public"."events_status", 'published'::"public"."events_status", 'booked'::"public"."events_status", 'cancelled'::"public"."events_status", 'completed'::"public"."events_status"])))
);

ALTER TABLE ONLY "public"."events" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."genres" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "genre_name" "text" NOT NULL,
    "description" "text",
    "icon_url" "text",
    "display_order" smallint DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_lobby_safe" boolean DEFAULT false NOT NULL,
    "is_dinner_ambiance" boolean DEFAULT false NOT NULL,
    "is_pub_crowd" boolean DEFAULT false NOT NULL,
    "is_high_energy_club" boolean DEFAULT false NOT NULL,
    CONSTRAINT "chk_genre_display_order" CHECK (("display_order" >= 0))
);

ALTER TABLE ONLY "public"."genres" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."genres" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "sender_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "content" "text" DEFAULT ''::"text" NOT NULL,
    "attachment_url" "text",
    "attachment_type" "text",
    "is_read" boolean DEFAULT false NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_message_attachment_type" CHECK (("attachment_type" = ANY (ARRAY['image'::"text", 'pdf'::"text", 'audio'::"text", 'video'::"text", 'other'::"text"])))
);

ALTER TABLE ONLY "public"."messages" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" OWNER TO "postgres";


COMMENT ON COLUMN "public"."messages"."attachment_type" IS 'mime type of the attachment e.g. image/jpeg, application/pdf';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "public"."notifications_type" NOT NULL,
    "related_entity_id" "uuid" NOT NULL,
    "message_preview" "text",
    "is_read" boolean DEFAULT false NOT NULL,
    "sent_at" timestamp with time zone DEFAULT "now"(),
    "channel" "public"."notifications_channel" NOT NULL,
    CONSTRAINT "chk_notification_channel" CHECK (("channel" = ANY (ARRAY['in_app'::"public"."notifications_channel", 'email'::"public"."notifications_channel", 'push'::"public"."notifications_channel", 'sms'::"public"."notifications_channel"])))
);

ALTER TABLE ONLY "public"."notifications" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "payer_user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "payment_type" "public"."payments_types" NOT NULL,
    "payment_method" "public"."payments_methods" NOT NULL,
    "gross_amount" numeric NOT NULL,
    "commission_portion" numeric NOT NULL,
    "net_to_talent" numeric NOT NULL,
    "platform_revenue" numeric NOT NULL,
    "transaction_reference" "text",
    "payment_status" "public"."payments_status" NOT NULL,
    "paid_at" timestamp with time zone,
    "payment_flow" "public"."payments_flow" NOT NULL,
    "payment_gateway_provider" "text" NOT NULL,
    "gateway_transaction_id" "text",
    "authorization_code" "uuid",
    "authorization_code_expires_at" timestamp with time zone,
    "is_pre_approved" boolean DEFAULT false NOT NULL,
    "gateway_fee" numeric DEFAULT 0.00 NOT NULL,
    "currency" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "gateway_order_id" "text" DEFAULT ''::"text" NOT NULL,
    CONSTRAINT "chk_payment_commission" CHECK (("commission_portion" >= (0)::numeric)),
    CONSTRAINT "chk_payment_currency_format" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_payment_flow" CHECK (("payment_flow" = ANY (ARRAY['immediate'::"public"."payments_flow", 'deferred'::"public"."payments_flow", 'escrow'::"public"."payments_flow"]))),
    CONSTRAINT "chk_payment_gateway_fee" CHECK (("gateway_fee" >= (0)::numeric)),
    CONSTRAINT "chk_payment_gross_positive" CHECK (("gross_amount" > (0)::numeric)),
    CONSTRAINT "chk_payment_method" CHECK (("payment_method" = ANY (ARRAY['card'::"public"."payments_methods", 'bank_transfer'::"public"."payments_methods", 'payhere'::"public"."payments_methods", 'authorization_code'::"public"."payments_methods"]))),
    CONSTRAINT "chk_payment_net_client" CHECK (("net_to_talent" >= (0)::numeric)),
    CONSTRAINT "chk_payment_platform_revenue" CHECK (("platform_revenue" >= (0)::numeric)),
    CONSTRAINT "chk_payment_status" CHECK (("payment_status" = ANY (ARRAY['pending'::"public"."payments_status", 'completed'::"public"."payments_status", 'failed'::"public"."payments_status", 'refunded'::"public"."payments_status", 'disputed'::"public"."payments_status"]))),
    CONSTRAINT "chk_payment_type" CHECK (("payment_type" = ANY (ARRAY['deposit'::"public"."payments_types", 'balance'::"public"."payments_types", 'refund'::"public"."payments_types", 'adjustment'::"public"."payments_types"])))
);

ALTER TABLE ONLY "public"."payments" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles_admin" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "full_name" "text" DEFAULT ''::"text" NOT NULL,
    "admin_level" "public"."admin_level",
    "permissions" "text" DEFAULT ''' { } '''::"text",
    "department" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "chk_admin_level" CHECK (("admin_level" = ANY (ARRAY['super_admin'::"public"."admin_level", 'manager'::"public"."admin_level", 'partner'::"public"."admin_level", 'support'::"public"."admin_level", 'executive'::"public"."admin_level"])))
);

ALTER TABLE ONLY "public"."profiles_admin" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_admin" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles_admin" IS 'Full access to all tables and all rows. Can read, write, and delete anything on the platform.';



CREATE TABLE IF NOT EXISTS "public"."profiles_clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "full_name" "text" DEFAULT ''::"text" NOT NULL,
    "company_name" "text",
    "address_row_1" "text",
    "preferred_genre" "text" DEFAULT ''''' { } ''''::text''::text'::"text",
    "preferred_language" "text" DEFAULT ''''' { } ''''::text''::text'::"text",
    "typical_budget_range" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "address_row_2" "text",
    "address_city" "text",
    "address_country" "text",
    "address_postal_code" smallint,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "avatar_url" "text",
    "avatar_public_id" "text",
    "approval_status" "public"."approval_status" DEFAULT 'draft'::"public"."approval_status" NOT NULL
);

ALTER TABLE ONLY "public"."profiles_clients" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_clients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles_talent" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "stage_name" "text" DEFAULT ''::"text",
    "full_name" "text" DEFAULT ''::"text" NOT NULL,
    "email" "text",
    "mobile" "text",
    "url_trailer_video" "text",
    "url_live_performace_video" "text",
    "pricing_per_session" numeric(12,2),
    "primary_location" "text",
    "optional_location_1" "text",
    "optional_location_2" "text",
    "optional_location_3" "text",
    "optional_location_4" "text",
    "languages" "text",
    "type_of_performer" "public"."talent_type" DEFAULT 'solo'::"public"."talent_type" NOT NULL,
    "type_of_ensemble" "text" DEFAULT ''::"text",
    "profile_photo_url" "text",
    "bio" "text",
    "rating" numeric DEFAULT 0.00,
    "profile_status" "public"."talent_status" DEFAULT 'pending'::"public"."talent_status" NOT NULL,
    "is_verified" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "short_bio" "text",
    "primary_genre_id" "uuid" NOT NULL,
    "secondary_genre_id" "uuid",
    "tertiary_genre_id" "uuid",
    "is_public" boolean DEFAULT true NOT NULL,
    "cover_photo_url" "text",
    "profile_photo_public_id" "text",
    "cover_photo_public_id" "text",
    "en4tainment_profile_id" "text",
    "is_featured" boolean DEFAULT false,
    "feature_sort_order" integer,
    "featured_by" "text",
    "featured_at" timestamp with time zone,
    "featured_expires_at" timestamp with time zone,
    "approval_status" "public"."approval_status" DEFAULT 'draft'::"public"."approval_status" NOT NULL,
    "date_of_birth" "date",
    "pricing_updated_at" timestamp with time zone,
    "base_latitude" numeric(9,6),
    "base_longitude" numeric(9,6),
    "travel_radius_km" integer,
    CONSTRAINT "chk_talent_pricing_positive" CHECK (("pricing_per_session" >= (0)::numeric)),
    CONSTRAINT "chk_talent_profile_status" CHECK (("profile_status" = ANY (ARRAY['pending'::"public"."talent_status", 'active'::"public"."talent_status", 'inactive'::"public"."talent_status", 'suspended'::"public"."talent_status"]))),
    CONSTRAINT "chk_talent_rating_range" CHECK ((("rating" >= (0)::numeric) AND ("rating" <= (5)::numeric))),
    CONSTRAINT "profiles_talent_base_coords_valid" CHECK (((("base_latitude" IS NULL) AND ("base_longitude" IS NULL)) OR ((("base_latitude" >= ('-90'::integer)::numeric) AND ("base_latitude" <= (90)::numeric)) AND (("base_longitude" >= ('-180'::integer)::numeric) AND ("base_longitude" <= (180)::numeric))))),
    CONSTRAINT "profiles_talent_dob_sane" CHECK ((("date_of_birth" IS NULL) OR (("date_of_birth" > '1900-01-01'::"date") AND ("date_of_birth" <= CURRENT_DATE)))),
    CONSTRAINT "profiles_talent_genres_distinct_check" CHECK (((("secondary_genre_id" IS NULL) OR ("secondary_genre_id" <> "primary_genre_id")) AND (("tertiary_genre_id" IS NULL) OR ("tertiary_genre_id" <> "primary_genre_id")) AND (("tertiary_genre_id" IS NULL) OR ("secondary_genre_id" IS NULL) OR ("tertiary_genre_id" <> "secondary_genre_id")) AND (("tertiary_genre_id" IS NULL) OR ("secondary_genre_id" IS NOT NULL)))),
    CONSTRAINT "profiles_talent_pricing_range" CHECK ((("pricing_per_session" IS NULL) OR (("pricing_per_session" > (0)::numeric) AND ("pricing_per_session" <= (10000000)::numeric)))),
    CONSTRAINT "profiles_talent_travel_radius_valid" CHECK ((("travel_radius_km" IS NULL) OR (("travel_radius_km" >= 1) AND ("travel_radius_km" <= 1000))))
);


ALTER TABLE "public"."profiles_talent" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles_talent" IS 'Performers, artists, entertainers. Own their profile, pricing, media, and payout info. Receive and manage booking requests.';



CREATE TABLE IF NOT EXISTS "public"."profiles_users" (
    "id" "uuid" NOT NULL,
    "email" "text" DEFAULT ''::"text" NOT NULL,
    "phone" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "public"."user_status" DEFAULT 'active'::"public"."user_status" NOT NULL,
    "last_login_at" timestamp with time zone,
    "role" "text" DEFAULT 'client'::"text" NOT NULL,
    "date_of_birth" "date",
    CONSTRAINT "chk_users_role" CHECK (("role" = ANY (ARRAY['talent'::"text", 'client'::"text", 'venue'::"text", 'admin'::"text"]))),
    CONSTRAINT "chk_users_status" CHECK (("status" = ANY (ARRAY['active'::"public"."user_status", 'suspended'::"public"."user_status", 'banned'::"public"."user_status", 'pending'::"public"."user_status"]))),
    CONSTRAINT "profiles_users_dob_sane" CHECK ((("date_of_birth" IS NULL) OR (("date_of_birth" > '1900-01-01'::"date") AND ("date_of_birth" <= CURRENT_DATE)))),
    CONSTRAINT "profiles_users_role_valid" CHECK (("role" = ANY (ARRAY['talent'::"text", 'client'::"text", 'venue'::"text", 'admin'::"text"])))
);

ALTER TABLE ONLY "public"."profiles_users" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_users" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles_users" IS 'Fans and customers. Read-only access to public talent and venue profiles. Can leave reviews.';



CREATE TABLE IF NOT EXISTS "public"."profiles_venues" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name_of_venue" "text" DEFAULT ''::"text" NOT NULL,
    "name_of_location" "text" DEFAULT ''::"text" NOT NULL,
    "size_of_space" integer,
    "location_of_venue" "text",
    "url_google_maps_pin" "text",
    "address_row_1" "text" DEFAULT ''::"text" NOT NULL,
    "required_time_slot" "text",
    "performance_days" "text" DEFAULT ''''''' { } ''''''::text'::"text",
    "allowed_breaks" smallint,
    "meals_for_talent" boolean DEFAULT false,
    "meal_details" "text",
    "audience_age_range" "text",
    "audience_nationality" "text" DEFAULT ''''''' { } ''''''::text'::"text",
    "type_of_occasion" "text" DEFAULT ''''''' { } ''''''::text'::"text",
    "music_genre_preference" "text" DEFAULT ''''''' { } ''''''::text'::"text",
    "language_preference" "text" DEFAULT ''''''' { } ''''''::text'::"text",
    "contact_person" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "contact_mobile" "text",
    "url_venue_photo" "text",
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "address_row_2" "text" DEFAULT ''::"text" NOT NULL,
    "address_city" "text" DEFAULT ''::"text" NOT NULL,
    "address_country" "text" DEFAULT ''::"text" NOT NULL,
    "address_postal_code" "text" DEFAULT ''::"text" NOT NULL,
    "time_per_break" smallint,
    "avatar_url" "text",
    "avatar_public_id" "text",
    "approval_status" "public"."approval_status" DEFAULT 'draft'::"public"."approval_status" NOT NULL,
    "latitude" numeric(9,6),
    "longitude" numeric(9,6),
    CONSTRAINT "chk_allowed_breaks" CHECK (("allowed_breaks" >= 0)),
    CONSTRAINT "chk_time_per_break" CHECK (("time_per_break" >= 0)),
    CONSTRAINT "profiles_venues_coords_valid" CHECK (((("latitude" IS NULL) AND ("longitude" IS NULL)) OR ((("latitude" >= ('-90'::integer)::numeric) AND ("latitude" <= (90)::numeric)) AND (("longitude" >= ('-180'::integer)::numeric) AND ("longitude" <= (180)::numeric)))))
);

ALTER TABLE ONLY "public"."profiles_venues" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_venues" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles_venues" IS 'Hosts and organizers. Own their venue profile, events, capacity specs, contracts, and payments. Send booking requests to talent.';



CREATE TABLE IF NOT EXISTS "public"."quote_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_user_id" "uuid" NOT NULL,
    "venue_id" "uuid",
    "event_type" "public"."events_type" NOT NULL,
    "location" "text",
    "budget_min" numeric,
    "budget_max" numeric,
    "special_requirements" "text",
    "status" "public"."quotation_request_status",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "talent_id" "uuid" NOT NULL,
    "decline_reason" "public"."quote_decline_reason",
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "duration_hours" numeric GENERATED ALWAYS AS ((EXTRACT(epoch FROM ("ends_at" - "starts_at")) / (3600)::numeric)) STORED,
    "event_latitude" numeric(9,6),
    "event_longitude" numeric(9,6),
    "event_address" "text",
    "talent_rate_at_request" numeric(12,2),
    CONSTRAINT "chk_qreq_budget_min" CHECK (("budget_min" >= (0)::numeric)),
    CONSTRAINT "chk_qreq_budget_range" CHECK (("budget_max" >= "budget_min")),
    CONSTRAINT "chk_qreq_decline_reason_consistency" CHECK (((("status" = 'declined'::"public"."quotation_request_status") AND ("decline_reason" IS NOT NULL)) OR (("status" <> 'declined'::"public"."quotation_request_status") AND ("decline_reason" IS NULL)))),
    CONSTRAINT "chk_qreq_status" CHECK (("status" = ANY (ARRAY['open'::"public"."quotation_request_status", 'matched'::"public"."quotation_request_status", 'declined'::"public"."quotation_request_status", 'expired'::"public"."quotation_request_status", 'cancelled'::"public"."quotation_request_status", 'converted'::"public"."quotation_request_status"]))),
    CONSTRAINT "quote_requests_coords_valid" CHECK (((("event_latitude" IS NULL) AND ("event_longitude" IS NULL)) OR ((("event_latitude" >= ('-90'::integer)::numeric) AND ("event_latitude" <= (90)::numeric)) AND (("event_longitude" >= ('-180'::integer)::numeric) AND ("event_longitude" <= (180)::numeric))))),
    CONSTRAINT "quote_requests_ends_after_starts" CHECK (("ends_at" > "starts_at")),
    CONSTRAINT "quote_requests_has_location" CHECK ((("venue_id" IS NOT NULL) OR (("event_latitude" IS NOT NULL) AND ("event_longitude" IS NOT NULL))))
);

ALTER TABLE ONLY "public"."quote_requests" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."quote_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quote_request_id" "uuid" NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "quoted_amount" numeric(12,2) NOT NULL,
    "travel_fee" numeric(12,2) DEFAULT 0.00,
    "equipment_fee" numeric(12,2) DEFAULT 0.00,
    "commission_rate_percent" numeric(5,2) DEFAULT 21.00 NOT NULL,
    "quote_status" "public"."quotation_status",
    "sent_at" timestamp with time zone NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "notes_to_client" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "counter_used" boolean DEFAULT false NOT NULL,
    "performer_count" integer,
    "equipment_provided_by" "public"."equipment_responsibility" DEFAULT 'talent'::"public"."equipment_responsibility" NOT NULL,
    "equipment_notes" "text",
    "setup_arrival_at" timestamp with time zone,
    "talent_net_earnings" numeric(12,2) GENERATED ALWAYS AS ((("quoted_amount" + COALESCE("travel_fee", (0)::numeric)) + COALESCE("equipment_fee", (0)::numeric))) STORED,
    "commission_amount" numeric(12,2) GENERATED ALWAYS AS ("round"((((("quoted_amount" + COALESCE("travel_fee", (0)::numeric)) + COALESCE("equipment_fee", (0)::numeric)) * "commission_rate_percent") / (100)::numeric), 2)) STORED,
    "total_client_price" numeric(12,2) GENERATED ALWAYS AS (((("quoted_amount" + COALESCE("travel_fee", (0)::numeric)) + COALESCE("equipment_fee", (0)::numeric)) + "round"((((("quoted_amount" + COALESCE("travel_fee", (0)::numeric)) + COALESCE("equipment_fee", (0)::numeric)) * "commission_rate_percent") / (100)::numeric), 2))) STORED,
    CONSTRAINT "chk_quote_amount_positive" CHECK (("quoted_amount" >= (0)::numeric)),
    CONSTRAINT "chk_quote_commission_rate" CHECK ((("commission_rate_percent" >= (0)::numeric) AND ("commission_rate_percent" <= (100)::numeric))),
    CONSTRAINT "chk_quote_equipment_fee" CHECK (("equipment_fee" >= (0)::numeric)),
    CONSTRAINT "chk_quote_status" CHECK (("quote_status" = ANY (ARRAY['pending'::"public"."quotation_status", 'accepted'::"public"."quotation_status", 'rejected'::"public"."quotation_status", 'expired'::"public"."quotation_status", 'countered'::"public"."quotation_status"]))),
    CONSTRAINT "chk_quote_travel_fee" CHECK (("travel_fee" >= (0)::numeric)),
    CONSTRAINT "quotes_amounts_positive" CHECK ((("quoted_amount" > (0)::numeric) AND (COALESCE("travel_fee", (0)::numeric) >= (0)::numeric) AND (COALESCE("equipment_fee", (0)::numeric) >= (0)::numeric))),
    CONSTRAINT "quotes_commission_rate_valid" CHECK ((("commission_rate_percent" >= (0)::numeric) AND ("commission_rate_percent" <= (100)::numeric))),
    CONSTRAINT "quotes_performer_count_valid" CHECK ((("performer_count" IS NULL) OR (("performer_count" >= 1) AND ("performer_count" <= 50))))
);

ALTER TABLE ONLY "public"."quotes" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."quotes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."quotes"."counter_used" IS 'True once client/venue has used their single allowed "ask for better offer". Enforced in application logic, not purely at DB level.';



CREATE TABLE IF NOT EXISTS "public"."revenue_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "revenue_type" "public"."revenue_type" NOT NULL,
    "amount" numeric NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_ledger_amount_nonzero" CHECK (("amount" <> (0)::numeric)),
    CONSTRAINT "chk_ledger_revenue_type" CHECK (("revenue_type" = ANY (ARRAY['commission'::"public"."revenue_type", 'subscription'::"public"."revenue_type", 'advert'::"public"."revenue_type", 'adjustment'::"public"."revenue_type", 'other'::"public"."revenue_type"])))
);

ALTER TABLE ONLY "public"."revenue_ledger" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."revenue_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews_star" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "reviewer_user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "reviewee_talent_id" "uuid",
    "rating" smallint NOT NULL,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewee_venue_id" "uuid",
    "overall_rating" numeric,
    "stage_presence_rating" numeric,
    "musical_ability_rating" numeric,
    "professionalism_rating" numeric,
    "sound_quality_rating" numeric,
    "audience_response_rating" numeric,
    "event_type" "public"."events_type",
    "would_book_again" boolean,
    "is_verified" boolean DEFAULT false NOT NULL,
    CONSTRAINT "check_rating_range" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
    CONSTRAINT "chk_review_audience_response" CHECK ((("audience_response_rating" >= (1)::numeric) AND ("audience_response_rating" <= (5)::numeric))),
    CONSTRAINT "chk_review_musical_ability" CHECK ((("musical_ability_rating" >= (1)::numeric) AND ("musical_ability_rating" <= (5)::numeric))),
    CONSTRAINT "chk_review_overall_rating" CHECK ((("overall_rating" >= (0)::numeric) AND ("overall_rating" <= (5)::numeric))),
    CONSTRAINT "chk_review_professionalism" CHECK ((("professionalism_rating" >= (1)::numeric) AND ("professionalism_rating" <= (5)::numeric))),
    CONSTRAINT "chk_review_rating" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
    CONSTRAINT "chk_review_sound_quality" CHECK ((("sound_quality_rating" >= (1)::numeric) AND ("sound_quality_rating" <= (5)::numeric))),
    CONSTRAINT "chk_review_stage_presence" CHECK ((("stage_presence_rating" >= (1)::numeric) AND ("stage_presence_rating" <= (5)::numeric)))
);

ALTER TABLE ONLY "public"."reviews_star" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews_star" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sensitive_asset_access_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "accessed_by_user_id" "uuid" NOT NULL,
    "asset_type" "text" NOT NULL,
    "object_key" "text" NOT NULL,
    "storage_bucket" "text" NOT NULL,
    "subject_talent_id" "uuid",
    "subject_entity_id" "uuid",
    "ip_address" "inet",
    "user_agent" "text",
    "accessed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sensitive_asset_access_log_asset_type_check" CHECK (("asset_type" = ANY (ARRAY['kyc_front'::"text", 'kyc_back'::"text", 'venue_document'::"text"])))
);


ALTER TABLE "public"."sensitive_asset_access_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_type" "public"."subscription_plan" NOT NULL,
    "monthly_fee" numeric DEFAULT 0.00,
    "start_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "end_date" "date",
    "subscription_status" "public"."subscription_status" NOT NULL,
    CONSTRAINT "chk_sub_date_range" CHECK (("end_date" > "start_date")),
    CONSTRAINT "chk_sub_fee" CHECK (("monthly_fee" >= (0)::numeric)),
    CONSTRAINT "chk_sub_plan_type" CHECK (("plan_type" = ANY (ARRAY['free'::"public"."subscription_plan", 'basic'::"public"."subscription_plan", 'pro'::"public"."subscription_plan", 'agency'::"public"."subscription_plan"]))),
    CONSTRAINT "chk_sub_status" CHECK (("subscription_status" = ANY (ARRAY['active'::"public"."subscription_status", 'cancelled'::"public"."subscription_status", 'expired'::"public"."subscription_status", 'trialing'::"public"."subscription_status", 'paused'::"public"."subscription_status"])))
);

ALTER TABLE ONLY "public"."subscriptions" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_favourites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "talent_id" "uuid" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "app_source" "text" DEFAULT 'En4tainment'::"text" NOT NULL,
    "visitor_id" "uuid",
    CONSTRAINT "talent_favourites_app_source_check" CHECK (("app_source" = ANY (ARRAY['en4tainment'::"text", 'en410'::"text"])))
);

ALTER TABLE ONLY "public"."talent_favourites" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_favourites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_hearts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."talent_hearts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_identity" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "nic_front_url" "text",
    "nic_back_url" "text",
    "kyc_status" "public"."kyc_status" DEFAULT 'pending'::"public"."kyc_status" NOT NULL,
    "verified_by" "uuid",
    "verified_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nic_front_public_id" "text",
    "nic_back_public_id" "text",
    "nic_storage_bucket" "text",
    "kyc_deletion_requested_at" timestamp with time zone,
    "kyc_retention_expires_at" timestamp with time zone,
    "kyc_legal_hold" boolean DEFAULT false NOT NULL,
    "nic_hash" "text",
    "nic_last_four" "text",
    CONSTRAINT "chk_kyc_status" CHECK (("kyc_status" = ANY (ARRAY['pending'::"public"."kyc_status", 'submitted'::"public"."kyc_status", 'verified'::"public"."kyc_status", 'rejected'::"public"."kyc_status"]))),
    CONSTRAINT "talent_identity_complete_when_submitted_check" CHECK ((("kyc_status" = 'pending'::"public"."kyc_status") OR (("nic_hash" IS NOT NULL) AND ("nic_last_four" IS NOT NULL) AND ("nic_front_public_id" IS NOT NULL) AND ("nic_back_public_id" IS NOT NULL))))
);

ALTER TABLE ONLY "public"."talent_identity" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_identity" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "cloudinary_public_id" "text" DEFAULT ''::"text" NOT NULL,
    "resource_type" "public"."talent_media_resource_type" NOT NULL,
    "format" "text",
    "folder" "text",
    "bytes" integer,
    "media_type" "public"."talent_media_type" NOT NULL,
    "title" "text",
    "is_featured" boolean DEFAULT false NOT NULL,
    "sort_order" smallint DEFAULT '0'::smallint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cloudinary_secure_url" "text",
    CONSTRAINT "chk_media_bytes" CHECK (("bytes" >= 0)),
    CONSTRAINT "chk_media_resource_type" CHECK (("resource_type" = 'image'::"public"."talent_media_resource_type")),
    CONSTRAINT "chk_media_sort_order" CHECK (("sort_order" >= 0))
);

ALTER TABLE ONLY "public"."talent_media" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_payout_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "payable_account_id" "text" DEFAULT ''::"text" NOT NULL,
    "account_display_name" "text" DEFAULT ''::"text" NOT NULL,
    "bank_name" "text" DEFAULT ''::"text" NOT NULL,
    "bank_account_last_4" "text" DEFAULT ''::"text" NOT NULL,
    "bank_country" "text" DEFAULT '''''LK''''::text'::"text",
    "currency" "text" DEFAULT '''''LKR''''::text'::"text",
    "is_default" boolean DEFAULT false NOT NULL,
    "is_verified" boolean DEFAULT false NOT NULL,
    "payable_onboarding_complete" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_payout_acct_currency" CHECK (("char_length"("currency") = 3))
);

ALTER TABLE ONLY "public"."talent_payout_accounts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_payout_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_payout_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "payout_account_id" "uuid" NOT NULL,
    "amount" numeric DEFAULT '0'::numeric NOT NULL,
    "currency" "text" DEFAULT ''::"text" NOT NULL,
    "payout_date" timestamp with time zone,
    "bank_reference" "text",
    "failure_reason" "text",
    "initiated_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "public"."payout_status" DEFAULT 'pending'::"public"."payout_status" NOT NULL,
    CONSTRAINT "chk_payout_txn_amount_positive" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "chk_payout_txn_currency" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_payout_txn_status" CHECK (("status" = ANY (ARRAY['pending'::"public"."payout_status", 'processing'::"public"."payout_status", 'completed'::"public"."payout_status", 'failed'::"public"."payout_status", 'reversed'::"public"."payout_status"])))
);

ALTER TABLE ONLY "public"."talent_payout_transactions" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_payout_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_pricing" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "label" "text" DEFAULT ''::"text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "price_amount" numeric DEFAULT '1000'::numeric NOT NULL,
    "currency" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "duration_minutes" smallint NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_pricing_amount_positive" CHECK (("price_amount" >= (0)::numeric)),
    CONSTRAINT "chk_pricing_currency_format" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_pricing_duration_positive" CHECK (("duration_minutes" > 0))
);

ALTER TABLE ONLY "public"."talent_pricing" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_pricing" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_profile_sync_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "talent_profile_sync_logs_event_type_check" CHECK (("event_type" = ANY (ARRAY['create'::"text", 'update'::"text", 'revoke'::"text"]))),
    CONSTRAINT "talent_profile_sync_logs_status_check" CHECK (("status" = ANY (ARRAY['success'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."talent_profile_sync_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_profile_view" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "viewer_user_id" "uuid" NOT NULL,
    "viewer_role" "public"."user_role",
    "source_page" "text",
    "viewed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE ONLY "public"."talent_profile_view" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_profile_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."talent_unavailability" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "talent_id" "uuid" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "talent_unavailability_ends_after_starts" CHECK (("ends_at" > "starts_at"))
);


ALTER TABLE "public"."talent_unavailability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_payment_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "display_label" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "currency" "text" DEFAULT 'LKR'::"text" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "is_verified" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "account_purpose" "public"."venue_account_purpose" DEFAULT 'payment'::"public"."venue_account_purpose" NOT NULL,
    "gateway_token" "text",
    "card_last_4" "text",
    "card_brand" "text",
    "card_expiry_month" smallint,
    "card_expiry_year" smallint,
    "payable_account_id" "text",
    "bank_name" "text",
    "bank_account_last_4" "text",
    CONSTRAINT "chk_vpa_card_last4" CHECK (("card_last_4" ~ '^[0-9]{4}$'::"text")),
    CONSTRAINT "chk_vpa_currency" CHECK (("char_length"("currency") = 3)),
    CONSTRAINT "chk_vpa_expiry_month" CHECK ((("card_expiry_month" >= 1) AND ("card_expiry_month" <= 12))),
    CONSTRAINT "chk_vpa_expiry_year" CHECK (("card_expiry_year" >= 2024)),
    CONSTRAINT "chk_vpa_purpose" CHECK (("account_purpose" = ANY (ARRAY['payment'::"public"."venue_account_purpose", 'payout'::"public"."venue_account_purpose"])))
);

ALTER TABLE ONLY "public"."venue_payment_accounts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."venue_payment_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhook_events_seen" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider" "text" NOT NULL,
    "event_key" "text" NOT NULL,
    "payload_hash" "text",
    "processed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."webhook_events_seen" OWNER TO "postgres";


























ALTER TABLE ONLY "public"."profiles_admin"
    ADD CONSTRAINT "Admin_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."authorization_codes"
    ADD CONSTRAINT "AuthorizationCodes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."availability"
    ADD CONSTRAINT "Availability_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_approvals"
    ADD CONSTRAINT "ClientApprovals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_payment_methods"
    ADD CONSTRAINT "Client_Payment_Methods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_clients"
    ADD CONSTRAINT "Clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."contracts"
    ADD CONSTRAINT "Contracts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "Documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "Events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."genres"
    ADD CONSTRAINT "Genres_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_favourites"
    ADD CONSTRAINT "HeartSystem_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "Notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "Payments_gateway_transaction_id_key" UNIQUE ("gateway_transaction_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "Payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "QuoteRequests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quotes"
    ADD CONSTRAINT "Quotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."revenue_ledger"
    ADD CONSTRAINT "RevenueLedger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "Reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "Subcriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_profile_view"
    ADD CONSTRAINT "TalentProfileView_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_media"
    ADD CONSTRAINT "Talent_Media_CloudinaryPublicID_key" UNIQUE ("cloudinary_public_id");



ALTER TABLE ONLY "public"."talent_media"
    ADD CONSTRAINT "Talent_Media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_payout_accounts"
    ADD CONSTRAINT "Talent_Payout_Accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_PayableTransactionID_key" UNIQUE ("bank_reference");



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_pricing"
    ADD CONSTRAINT "Talent_Pricing_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "Talent_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_users"
    ADD CONSTRAINT "Users_Email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles_users"
    ADD CONSTRAINT "Users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_payment_accounts"
    ADD CONSTRAINT "Venue_Payment_Accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_venues"
    ADD CONSTRAINT "Venues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_no_talent_double_booking" EXCLUDE USING "gist" ("talent_id" WITH =, "tstzrange"("starts_at", "ends_at") WITH &&) WHERE (("booking_status" <> 'cancelled'::"public"."booking_status"));







































































































































ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "profiles_talent_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "reviews_star_booking_reviewer_unique" UNIQUE ("booking_id", "reviewer_user_id");



ALTER TABLE ONLY "public"."sensitive_asset_access_log"
    ADD CONSTRAINT "sensitive_asset_access_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_favourites"
    ADD CONSTRAINT "talent_favourites_user_talent_unique" UNIQUE ("user_id", "talent_id");



ALTER TABLE ONLY "public"."talent_hearts"
    ADD CONSTRAINT "talent_hearts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_hearts"
    ADD CONSTRAINT "talent_hearts_talent_id_user_id_key" UNIQUE ("talent_id", "user_id");



ALTER TABLE ONLY "public"."talent_identity"
    ADD CONSTRAINT "talent_identity_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_identity"
    ADD CONSTRAINT "talent_identity_talent_id_key" UNIQUE ("talent_id");



ALTER TABLE ONLY "public"."talent_profile_sync_logs"
    ADD CONSTRAINT "talent_profile_sync_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_unavailability"
    ADD CONSTRAINT "talent_unavailability_no_overlap" EXCLUDE USING "gist" ("talent_id" WITH =, "tstzrange"("starts_at", "ends_at") WITH &&);



ALTER TABLE ONLY "public"."talent_unavailability"
    ADD CONSTRAINT "talent_unavailability_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."talent_media"
    ADD CONSTRAINT "uq_talent_media_slot" UNIQUE ("talent_id", "sort_order");



ALTER TABLE ONLY "public"."webhook_events_seen"
    ADD CONSTRAINT "webhook_events_seen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_events_seen"
    ADD CONSTRAINT "webhook_events_seen_unique" UNIQUE ("provider", "event_key");







































CREATE INDEX "idx_audit_deletes" ON "public"."audit_log" USING "btree" ("action", "created_at" DESC) WHERE ("action" = 'delete'::"public"."audit_action");



CREATE INDEX "idx_audit_record" ON "public"."audit_log" USING "btree" ("table_name", "record_id");



CREATE INDEX "idx_audit_table_time" ON "public"."audit_log" USING "btree" ("table_name", "created_at" DESC);



CREATE INDEX "idx_audit_user" ON "public"."audit_log" USING "btree" ("performed_by", "created_at" DESC);



CREATE INDEX "idx_bookings_talent_time" ON "public"."bookings" USING "btree" ("talent_id", "starts_at");



CREATE INDEX "idx_profiles_talent_en4_id" ON "public"."profiles_talent" USING "btree" ("en4tainment_profile_id") WHERE ("en4tainment_profile_id" IS NOT NULL);



CREATE INDEX "idx_saal_accessed_at" ON "public"."sensitive_asset_access_log" USING "btree" ("accessed_at" DESC);



CREATE INDEX "idx_talent_hearts_talent_id" ON "public"."talent_hearts" USING "btree" ("talent_id");



CREATE INDEX "idx_talent_unavailability_talent_time" ON "public"."talent_unavailability" USING "btree" ("talent_id", "starts_at");



CREATE UNIQUE INDEX "talent_favourites_visitor_talent_unique" ON "public"."talent_favourites" USING "btree" ("visitor_id", "talent_id") WHERE ("visitor_id" IS NOT NULL);



CREATE UNIQUE INDEX "talent_identity_nic_hash_key" ON "public"."talent_identity" USING "btree" ("nic_hash") WHERE ("nic_hash" IS NOT NULL);



CREATE OR REPLACE TRIGGER "quotes_set_expiry" BEFORE INSERT ON "public"."quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_quote_expiry"();



CREATE OR REPLACE TRIGGER "talent_pricing_cooldown" BEFORE UPDATE ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_pricing_cooldown"();



CREATE OR REPLACE TRIGGER "talent_pricing_required_before_submission" BEFORE INSERT OR UPDATE ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."check_talent_pricing_before_submission"();



CREATE OR REPLACE TRIGGER "trg_check_client_age" BEFORE INSERT OR UPDATE OF "date_of_birth", "role" ON "public"."profiles_users" FOR EACH ROW EXECUTE FUNCTION "public"."check_client_age"();



CREATE OR REPLACE TRIGGER "trg_check_talent_age" BEFORE INSERT OR UPDATE OF "date_of_birth" ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."check_talent_age"();



CREATE OR REPLACE TRIGGER "trg_client_approvals_venue_only" BEFORE INSERT OR UPDATE OF "venue_user_id" ON "public"."client_approvals" FOR EACH ROW EXECUTE FUNCTION "public"."check_client_approvals_venue_only"();



CREATE OR REPLACE TRIGGER "trg_enforce_featured_requires_admin" BEFORE INSERT OR UPDATE ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_featured_requires_admin"();



CREATE OR REPLACE TRIGGER "trg_quote_requests_rate_snapshot" BEFORE INSERT OR UPDATE ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."set_talent_rate_at_request"();



CREATE OR REPLACE TRIGGER "trg_require_client_dob" BEFORE INSERT OR UPDATE OF "approval_status" ON "public"."profiles_clients" FOR EACH ROW EXECUTE FUNCTION "public"."check_client_dob_before_submission"();



CREATE OR REPLACE TRIGGER "trg_require_talent_dob" BEFORE INSERT OR UPDATE OF "approval_status" ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."check_talent_dob_before_submission"();



CREATE OR REPLACE TRIGGER "trg_talent_approval" BEFORE UPDATE ON "public"."profiles_talent" FOR EACH ROW EXECUTE FUNCTION "public"."handle_talent_approval"();



ALTER TABLE ONLY "public"."authorization_codes"
    ADD CONSTRAINT "AuthorizationCodes_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."authorization_codes"
    ADD CONSTRAINT "AuthorizationCodes_client_approval_id_fkey" FOREIGN KEY ("client_approval_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."authorization_codes"
    ADD CONSTRAINT "AuthorizationCodes_client_user_id_fkey" FOREIGN KEY ("client_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."authorization_codes"
    ADD CONSTRAINT "AuthorizationCodes_used_in_payment_id_fkey" FOREIGN KEY ("used_in_payment_id") REFERENCES "public"."payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."availability"
    ADD CONSTRAINT "Availability_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_client_user_id_fkey" FOREIGN KEY ("client_user_id") REFERENCES "public"."profiles_users"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_contract_id_fkey" FOREIGN KEY ("contract_id") REFERENCES "public"."contracts"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."quotes"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "Bookings_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."profiles_venues"("id");



ALTER TABLE ONLY "public"."client_approvals"
    ADD CONSTRAINT "ClientApprovals_approved_by_user_id_fkey" FOREIGN KEY ("approved_by_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_approvals"
    ADD CONSTRAINT "ClientApprovals_client_user_id_fkey" FOREIGN KEY ("venue_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_payment_methods"
    ADD CONSTRAINT "Client_Payment_Methods_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."profiles_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contracts"
    ADD CONSTRAINT "Contracts_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contracts"
    ADD CONSTRAINT "Contracts_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contracts"
    ADD CONSTRAINT "Contracts_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."profiles_venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "Documents_related_entity_id_fkey" FOREIGN KEY ("related_entity_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "Documents_uploaded_by_user_id_fkey" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "Events_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "Events_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."profiles_venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "Notifications_related_entity_id_fkey" FOREIGN KEY ("related_entity_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "Notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "Payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "Payments_payer_user_id_fkey" FOREIGN KEY ("payer_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles_admin"
    ADD CONSTRAINT "Profiles_Admin_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles_clients"
    ADD CONSTRAINT "Profiles_Clients_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id");



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "Profiles_Talent_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id");



ALTER TABLE ONLY "public"."profiles_venues"
    ADD CONSTRAINT "Profiles_Venues_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "QuoteRequests_client_user_id_fkey" FOREIGN KEY ("client_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "QuoteRequests_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."profiles_venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quotes"
    ADD CONSTRAINT "Quotes_quote_request_id_fkey" FOREIGN KEY ("quote_request_id") REFERENCES "public"."quote_requests"("id");



ALTER TABLE ONLY "public"."quotes"
    ADD CONSTRAINT "Quotes_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id");



ALTER TABLE ONLY "public"."revenue_ledger"
    ADD CONSTRAINT "RevenueLedger_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_favourites"
    ADD CONSTRAINT "Reviews_Heart_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_favourites"
    ADD CONSTRAINT "Reviews_Heart_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "Reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "Reviews_reviewee_talent_id_fkey" FOREIGN KEY ("reviewee_talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "Reviews_reviewee_venue_id_fkey" FOREIGN KEY ("reviewee_venue_id") REFERENCES "public"."profiles_venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews_star"
    ADD CONSTRAINT "Reviews_reviewer_user_id_fkey" FOREIGN KEY ("reviewer_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "Subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_profile_view"
    ADD CONSTRAINT "TalentProfileView_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_profile_view"
    ADD CONSTRAINT "TalentProfileView_viewer_user_id_fkey" FOREIGN KEY ("viewer_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_media"
    ADD CONSTRAINT "Talent_Media_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_payout_accounts"
    ADD CONSTRAINT "Talent_Payout_Accounts_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_initiated_by_fkey" FOREIGN KEY ("initiated_by") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_payout_account_id_fkey" FOREIGN KEY ("payout_account_id") REFERENCES "public"."talent_payout_accounts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_payout_transactions"
    ADD CONSTRAINT "Talent_Payout_Transactions_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_pricing"
    ADD CONSTRAINT "Talent_Pricing_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_payment_accounts"
    ADD CONSTRAINT "Venue_Payment_Accounts_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."profiles_venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_performed_by_fkey" FOREIGN KEY ("performed_by") REFERENCES "public"."profiles_users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_completed_by_user_id_fkey" FOREIGN KEY ("completed_by_user_id") REFERENCES "public"."profiles_users"("id") ON DELETE SET NULL;





































































































































































ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles_users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_authorization_code_fkey" FOREIGN KEY ("authorization_code") REFERENCES "public"."authorization_codes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "profiles_talent_primary_genre_id_fkey" FOREIGN KEY ("primary_genre_id") REFERENCES "public"."genres"("id");



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "profiles_talent_secondary_genre_id_fkey" FOREIGN KEY ("secondary_genre_id") REFERENCES "public"."genres"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles_talent"
    ADD CONSTRAINT "profiles_talent_tertiary_genre_id_fkey" FOREIGN KEY ("tertiary_genre_id") REFERENCES "public"."genres"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles_users"
    ADD CONSTRAINT "profiles_users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_preferred_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id");



ALTER TABLE ONLY "public"."talent_hearts"
    ADD CONSTRAINT "talent_hearts_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_hearts"
    ADD CONSTRAINT "talent_hearts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_identity"
    ADD CONSTRAINT "talent_identity_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."talent_identity"
    ADD CONSTRAINT "talent_identity_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."profiles_users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."talent_unavailability"
    ADD CONSTRAINT "talent_unavailability_talent_id_fkey" FOREIGN KEY ("talent_id") REFERENCES "public"."profiles_talent"("id") ON DELETE CASCADE;



CREATE POLICY "admin_manages_all_unavailability" ON "public"."talent_unavailability" USING (("public"."get_my_role"() = 'admin'::"text")) WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "admin_profile_admin_only" ON "public"."profiles_admin" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_users"
  WHERE (("profiles_users"."id" = "auth"."uid"()) AND ("profiles_users"."role" = 'admin'::"text")))));



ALTER TABLE "public"."audit_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_log_admin_only" ON "public"."audit_log" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_users"
  WHERE (("profiles_users"."id" = "auth"."uid"()) AND ("profiles_users"."role" = 'admin'::"text")))));



CREATE POLICY "authcodes_read_own" ON "public"."authorization_codes" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "client_user_id"));



ALTER TABLE "public"."authorization_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."availability" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "availability_authenticated_read" ON "public"."availability" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "availability_manage_own" ON "public"."availability" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "availability"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "availability"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bookings_client_insert" ON "public"."bookings" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "client_user_id"));



CREATE POLICY "bookings_client_update" ON "public"."bookings" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "client_user_id"));



CREATE POLICY "bookings_participant_read" ON "public"."bookings" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "client_user_id") OR (EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "bookings"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "bookings"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."client_approvals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_approvals_read_own" ON "public"."client_approvals" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "venue_user_id"));



ALTER TABLE "public"."client_payment_methods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_profile_manage_own" ON "public"."profiles_clients" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."contracts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "contracts_participant_read" ON "public"."contracts" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "contracts"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "contracts"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"()))))));



CREATE POLICY "cpm_manage_own" ON "public"."client_payment_methods" TO "authenticated" USING (("auth"."uid"() = "client_id")) WITH CHECK (("auth"."uid"() = "client_id"));



ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documents_read_own" ON "public"."documents" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "uploaded_by_user_id"));



ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "events_public_read" ON "public"."events" FOR SELECT TO "authenticated", "anon" USING ((("is_public" = true) AND ("status" = ANY (ARRAY['published'::"public"."events_status", 'booked'::"public"."events_status", 'completed'::"public"."events_status"]))));



CREATE POLICY "events_venue_manage" ON "public"."events" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "events"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "events"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"())))));



CREATE POLICY "fav_anon_insert" ON "public"."talent_favourites" FOR INSERT TO "anon" WITH CHECK ((("user_id" IS NULL) AND ("visitor_id" IS NOT NULL) AND ("app_source" = 'en4tainment'::"text")));



CREATE POLICY "fav_client_insert" ON "public"."talent_favourites" FOR INSERT TO "authenticated" WITH CHECK ((("public"."get_my_role"() = 'client'::"text") AND ("auth"."uid"() = "user_id") AND ("app_source" = 'en4tainment'::"text")));



ALTER TABLE "public"."genres" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "genres_admin_write" ON "public"."genres" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_users"
  WHERE (("profiles_users"."id" = "auth"."uid"()) AND ("profiles_users"."role" = 'admin'::"text")))));



CREATE POLICY "genres_public_read" ON "public"."genres" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));



CREATE POLICY "ledger_admin_only" ON "public"."revenue_ledger" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_users"
  WHERE (("profiles_users"."id" = "auth"."uid"()) AND ("profiles_users"."role" = 'admin'::"text")))));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_participant_access" ON "public"."messages" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."bookings" "b"
  WHERE (("b"."id" = "messages"."booking_id") AND (("b"."client_user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."profiles_talent"
          WHERE (("profiles_talent"."id" = "b"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
           FROM "public"."profiles_venues"
          WHERE (("profiles_venues"."id" = "b"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"()))))))))) WITH CHECK (("auth"."uid"() = "sender_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_read_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_payer_read" ON "public"."payments" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "payer_user_id"));



CREATE POLICY "profile_view_read_own" ON "public"."talent_profile_view" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_profile_view"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."profiles_admin" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_clients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_talent" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_venues" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_talent_select_targeted" ON "public"."quote_requests" FOR SELECT TO "authenticated" USING (("auth"."uid"() IN ( SELECT "profiles_talent"."user_id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."id" = "quote_requests"."talent_id"))));



ALTER TABLE "public"."quote_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "quote_requests_client_manage" ON "public"."quote_requests" TO "authenticated" USING (("auth"."uid"() = "client_user_id")) WITH CHECK (("auth"."uid"() = "client_user_id"));



CREATE POLICY "quote_requests_talent_read" ON "public"."quote_requests" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."quotes" "q"
     JOIN "public"."profiles_talent" "pt" ON (("pt"."id" = "q"."talent_id")))
  WHERE (("q"."quote_request_id" = "quote_requests"."id") AND ("pt"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."quotes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "quotes_client_read" ON "public"."quotes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."quote_requests" "qr"
  WHERE (("qr"."id" = "quotes"."quote_request_id") AND ("qr"."client_user_id" = "auth"."uid"())))));



CREATE POLICY "quotes_talent_manage" ON "public"."quotes" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "quotes"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "quotes"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "rev_client_or_venue_insert" ON "public"."reviews_star" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "reviewer_user_id") AND ((("public"."get_my_role"() = 'client'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."bookings"
  WHERE (("bookings"."id" = "reviews_star"."booking_id") AND ("bookings"."client_user_id" = "auth"."uid"()) AND ("bookings"."booking_status" = 'completed'::"public"."booking_status"))))) OR (("public"."get_my_role"() = 'venue'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."bookings"
     JOIN "public"."profiles_venues" ON (("profiles_venues"."id" = "bookings"."venue_id")))
  WHERE (("bookings"."id" = "reviews_star"."booking_id") AND ("profiles_venues"."user_id" = "auth"."uid"()) AND ("bookings"."booking_status" = 'completed'::"public"."booking_status"))))))));



ALTER TABLE "public"."revenue_ledger" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews_star" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reviews_star_public_read" ON "public"."reviews_star" FOR SELECT TO "authenticated", "anon" USING (("is_verified" = true));



CREATE POLICY "rh_admin_all" ON "public"."talent_favourites" TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text")) WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "rh_client_delete" ON "public"."talent_favourites" FOR DELETE TO "authenticated" USING ((("public"."get_my_role"() = 'client'::"text") AND ("auth"."uid"() = "user_id")));



CREATE POLICY "rh_select_public" ON "public"."talent_favourites" FOR SELECT USING (true);



CREATE POLICY "rs_admin_all" ON "public"."reviews_star" TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text")) WITH CHECK (("public"."get_my_role"() = 'admin'::"text"));



CREATE POLICY "saal_admin_select" ON "public"."sensitive_asset_access_log" FOR SELECT TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



ALTER TABLE "public"."sensitive_asset_access_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "service_role_full_access" ON "public"."audit_log" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."authorization_codes" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."availability" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."bookings" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."client_approvals" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."client_payment_methods" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."contracts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."documents" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."events" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."genres" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."messages" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."notifications" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."payments" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."profiles_admin" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."profiles_clients" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."profiles_talent" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."profiles_users" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."profiles_venues" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."quote_requests" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."quotes" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."revenue_ledger" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."reviews_star" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."subscriptions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_favourites" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_identity" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_media" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_payout_accounts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_payout_transactions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_pricing" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."talent_profile_view" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_full_access" ON "public"."venue_payment_accounts" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "subscriptions_read_own" ON "public"."subscriptions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "sync_log_admin_select" ON "public"."talent_profile_sync_logs" FOR SELECT TO "authenticated" USING (("public"."get_my_role"() = 'admin'::"text"));



ALTER TABLE "public"."talent_favourites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_hearts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_identity" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "talent_identity_read_own" ON "public"."talent_identity" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_identity"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "talent_manages_own_unavailability" ON "public"."talent_unavailability" USING (("talent_id" IN ( SELECT "profiles_talent"."id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."user_id" = "auth"."uid"())))) WITH CHECK (("talent_id" IN ( SELECT "profiles_talent"."id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."talent_media" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "talent_media_manage_own" ON "public"."talent_media" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_media"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_media"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "talent_media_public_read" ON "public"."talent_media" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."talent_payout_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_payout_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_pricing" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "talent_pricing_manage_own" ON "public"."talent_pricing" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_pricing"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_pricing"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "talent_pricing_public_read" ON "public"."talent_pricing" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));



CREATE POLICY "talent_profile_manage_own" ON "public"."profiles_talent" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "talent_profile_read_own" ON "public"."profiles_talent" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."talent_profile_sync_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."talent_profile_view" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "talent_select_public" ON "public"."profiles_talent" FOR SELECT USING (("is_public" = true));



ALTER TABLE "public"."talent_unavailability" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "talent_update_own" ON "public"."profiles_talent" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "th_delete_own" ON "public"."talent_hearts" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "th_insert_own" ON "public"."talent_hearts" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "th_select_all" ON "public"."talent_hearts" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "ti_insert_own" ON "public"."talent_identity" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IN ( SELECT "profiles_talent"."user_id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."id" = "talent_identity"."talent_id"))));



CREATE POLICY "tm_talent_insert" ON "public"."talent_media" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IN ( SELECT "profiles_talent"."user_id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."id" = "talent_media"."talent_id"))));



CREATE POLICY "tm_talent_update" ON "public"."talent_media" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IN ( SELECT "profiles_talent"."user_id"
   FROM "public"."profiles_talent"
  WHERE ("profiles_talent"."id" = "talent_media"."talent_id"))));



CREATE POLICY "tpa_manage_own" ON "public"."talent_payout_accounts" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_payout_accounts"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_payout_accounts"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "tpt_read_own" ON "public"."talent_payout_transactions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_talent"
  WHERE (("profiles_talent"."id" = "talent_payout_transactions"."talent_id") AND ("profiles_talent"."user_id" = "auth"."uid"())))));



CREATE POLICY "users_read_own" ON "public"."profiles_users" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "users_update_own" ON "public"."profiles_users" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."venue_payment_accounts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "venue_profile_manage_own" ON "public"."profiles_venues" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "vpa_manage_own" ON "public"."venue_payment_accounts" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "venue_payment_accounts"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles_venues"
  WHERE (("profiles_venues"."id" = "venue_payment_accounts"."venue_id") AND ("profiles_venues"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."webhook_events_seen" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT ALL ON SCHEMA "public" TO "nocobase_admin";



GRANT ALL ON FUNCTION "public"."check_client_age"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_client_age"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_client_age"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_client_approvals_venue_only"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_client_approvals_venue_only"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_client_approvals_venue_only"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_client_dob_before_submission"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_client_dob_before_submission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_client_dob_before_submission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_talent_age"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_talent_age"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_talent_age"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_talent_dob_before_submission"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_talent_dob_before_submission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_talent_dob_before_submission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_talent_pricing_before_submission"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_talent_pricing_before_submission"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_talent_pricing_before_submission"() TO "service_role";



GRANT ALL ON FUNCTION "public"."distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."enforce_featured_requires_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enforce_featured_requires_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_pricing_cooldown"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_pricing_cooldown"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_pricing_cooldown"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_nic_hmac_key"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_nic_hmac_key"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_webhook_secret"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_webhook_secret"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_talent_approval"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_talent_approval"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_18_or_over"("dob" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."is_18_or_over"("dob" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_18_or_over"("dob" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_talent_available"("p_talent_id" "uuid", "p_starts_at" timestamp with time zone, "p_ends_at" timestamp with time zone, "p_buffer" interval) TO "anon";
GRANT ALL ON FUNCTION "public"."is_talent_available"("p_talent_id" "uuid", "p_starts_at" timestamp with time zone, "p_ends_at" timestamp with time zone, "p_buffer" interval) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_talent_available"("p_talent_id" "uuid", "p_starts_at" timestamp with time zone, "p_ends_at" timestamp with time zone, "p_buffer" interval) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_quote_expiry"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_quote_expiry"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_quote_expiry"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_talent_rate_at_request"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_talent_rate_at_request"() TO "service_role";



GRANT ALL ON TABLE "public"."audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_log" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."audit_log" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."authorization_codes" TO "anon";
GRANT ALL ON TABLE "public"."authorization_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."authorization_codes" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."authorization_codes" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."availability" TO "anon";
GRANT ALL ON TABLE "public"."availability" TO "authenticated";
GRANT ALL ON TABLE "public"."availability" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."availability" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."bookings" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."client_approvals" TO "anon";
GRANT ALL ON TABLE "public"."client_approvals" TO "authenticated";
GRANT ALL ON TABLE "public"."client_approvals" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."client_approvals" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."client_payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."client_payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."client_payment_methods" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."client_payment_methods" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."contracts" TO "anon";
GRANT ALL ON TABLE "public"."contracts" TO "authenticated";
GRANT ALL ON TABLE "public"."contracts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."contracts" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT ALL ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."documents" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."events" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."genres" TO "anon";
GRANT ALL ON TABLE "public"."genres" TO "authenticated";
GRANT ALL ON TABLE "public"."genres" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."genres" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."messages" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."notifications" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."payments" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."profiles_admin" TO "anon";
GRANT ALL ON TABLE "public"."profiles_admin" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_admin" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."profiles_admin" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."profiles_clients" TO "anon";
GRANT ALL ON TABLE "public"."profiles_clients" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_clients" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."profiles_clients" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."profiles_talent" TO "anon";
GRANT ALL ON TABLE "public"."profiles_talent" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_talent" TO "service_role";
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE "public"."profiles_talent" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."profiles_users" TO "anon";
GRANT ALL ON TABLE "public"."profiles_users" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_users" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."profiles_users" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."profiles_venues" TO "anon";
GRANT ALL ON TABLE "public"."profiles_venues" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_venues" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."profiles_venues" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."quote_requests" TO "anon";
GRANT ALL ON TABLE "public"."quote_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."quote_requests" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."quote_requests" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."quotes" TO "anon";
GRANT ALL ON TABLE "public"."quotes" TO "authenticated";
GRANT ALL ON TABLE "public"."quotes" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."quotes" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."revenue_ledger" TO "anon";
GRANT ALL ON TABLE "public"."revenue_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."revenue_ledger" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."revenue_ledger" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."reviews_star" TO "anon";
GRANT ALL ON TABLE "public"."reviews_star" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews_star" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."reviews_star" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."sensitive_asset_access_log" TO "anon";
GRANT ALL ON TABLE "public"."sensitive_asset_access_log" TO "authenticated";
GRANT ALL ON TABLE "public"."sensitive_asset_access_log" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."sensitive_asset_access_log" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."subscriptions" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_favourites" TO "anon";
GRANT ALL ON TABLE "public"."talent_favourites" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_favourites" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_favourites" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_hearts" TO "anon";
GRANT ALL ON TABLE "public"."talent_hearts" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_hearts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_hearts" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_identity" TO "anon";
GRANT ALL ON TABLE "public"."talent_identity" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_identity" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_identity" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_media" TO "anon";
GRANT ALL ON TABLE "public"."talent_media" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_media" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_media" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_payout_accounts" TO "anon";
GRANT ALL ON TABLE "public"."talent_payout_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_payout_accounts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_payout_accounts" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_payout_transactions" TO "anon";
GRANT ALL ON TABLE "public"."talent_payout_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_payout_transactions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_payout_transactions" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_pricing" TO "anon";
GRANT ALL ON TABLE "public"."talent_pricing" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_pricing" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_pricing" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_profile_sync_logs" TO "anon";
GRANT ALL ON TABLE "public"."talent_profile_sync_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_profile_sync_logs" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_profile_sync_logs" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_profile_view" TO "anon";
GRANT ALL ON TABLE "public"."talent_profile_view" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_profile_view" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_profile_view" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."talent_unavailability" TO "anon";
GRANT ALL ON TABLE "public"."talent_unavailability" TO "authenticated";
GRANT ALL ON TABLE "public"."talent_unavailability" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."talent_unavailability" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."venue_payment_accounts" TO "anon";
GRANT ALL ON TABLE "public"."venue_payment_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."venue_payment_accounts" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."venue_payment_accounts" TO "nocobase_admin";



GRANT ALL ON TABLE "public"."webhook_events_seen" TO "anon";
GRANT ALL ON TABLE "public"."webhook_events_seen" TO "authenticated";
GRANT ALL ON TABLE "public"."webhook_events_seen" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."webhook_events_seen" TO "nocobase_admin";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "nocobase_admin";








-- ── Function and table privilege lockdown ──────────────────────────────────
-- These REVOKEs exist in production but pg_dump does NOT emit them, so they
-- must be stated explicitly or a rebuilt database FAILS OPEN.
--
-- Why pg_dump misses them: Supabase grants EXECUTE on new functions in public
-- to anon and authenticated via ALTER DEFAULT PRIVILEGES FOR ROLE
-- supabase_admin. The Supabase CLI's dump filter comments that statement out,
-- so this file never declares those defaults -- and pg_dump, comparing against
-- a default it cannot see, treats the revoked state as unremarkable and emits
-- nothing. The lockdown evaporates silently.
--
-- Found 2026-08-28 by the first successful replay of the migration set. A
-- staging database built from these files WITHOUT this block would expose
-- get_nic_hmac_key() and get_webhook_secret() to anon over PostgREST -- the
-- NIC HMAC pepper and the webhook signing secret, readable by anyone.
-- get_webhook_secret was already exposed this way once and revoked 2026-08-15.
--
-- PUBLIC is revoked alongside the named roles deliberately. Revoking from anon
-- and authenticated alone leaves the PUBLIC grant intact, and both roles
-- inherit through it -- the revoke looks applied and does nothing.
--
-- All five are SECURITY DEFINER and owned by postgres, so they run with the
-- owner's rights. Reachability is the ONLY control on them.

REVOKE ALL ON FUNCTION "public"."get_nic_hmac_key"()                FROM PUBLIC, "anon", "authenticated";
REVOKE ALL ON FUNCTION "public"."get_webhook_secret"()              FROM PUBLIC, "anon", "authenticated";
REVOKE ALL ON FUNCTION "public"."handle_talent_approval"()          FROM PUBLIC, "anon", "authenticated";
REVOKE ALL ON FUNCTION "public"."enforce_featured_requires_admin"() FROM PUBLIC, "anon", "authenticated";
REVOKE ALL ON FUNCTION "public"."set_talent_rate_at_request"()      FROM PUBLIC, "anon", "authenticated";

-- audit_log must not be readable by anonymous callers.
REVOKE ALL ON TABLE "public"."audit_log" FROM "anon";

-- ── Realtime publication membership ────────────────────────────────────────
-- Which tables broadcast changes over Realtime is publication membership, set
-- through the Supabase dashboard and stored outside the schema. pg_dump does
-- not emit it here (the CLI's filter comments out CREATE PUBLICATION), so a
-- rebuilt database would have Realtime silently OFF for these three.
--
-- Not a data exposure -- Realtime enforces RLS. But anything depending on live
-- updates would appear broken on staging for a reason invisible in the schema.
--
-- Guarded on both sides: the publication may not exist on a bare shadow
-- database, and ADD TABLE errors if the table is already a member.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='bookings') THEN
      ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."bookings";
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='messages') THEN
      ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."messages";
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='notifications') THEN
      ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."notifications";
    END IF;
  END IF;
END
$$;
