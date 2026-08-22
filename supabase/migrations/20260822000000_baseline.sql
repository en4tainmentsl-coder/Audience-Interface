--
-- PostgreSQL database dump
--

\restrict KrPRMlCSXdrzjFfqUVz0diTKT7q1vAghX0IWI36LBvcNW67Yf1Wz6Ya12CZe7wE

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: admin_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.admin_level AS ENUM (
    'super_admin',
    'manager',
    'partner',
    'support',
    'executive'
);


--
-- Name: approval_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_status AS ENUM (
    'draft',
    'pending_approval',
    'approved',
    'rejected'
);


--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_action AS ENUM (
    'insert',
    'update',
    'delete',
    'login',
    'approve',
    'reject'
);


--
-- Name: auth_code_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.auth_code_types AS ENUM (
    'deposit',
    'full_payment',
    'credit_draw',
    'refund_credit'
);


--
-- Name: auth_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.auth_status AS ENUM (
    'active',
    'used',
    'expired',
    'cancelled'
);


--
-- Name: availability_blocked_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.availability_blocked_reason AS ENUM (
    'booking',
    'personal',
    'holiday',
    'travel',
    'other'
);


--
-- Name: booking_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled',
    'completed',
    'disputed'
);


--
-- Name: client_approval_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.client_approval_type AS ENUM (
    'credit_card',
    'deferred_payment',
    'corporate_account'
);


--
-- Name: client_payment_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.client_payment_type AS ENUM (
    'card',
    'bank_transfer',
    'authorization_code',
    'corporate_account'
);


--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_status AS ENUM (
    'draft',
    'sent',
    'signed_by_talent',
    'signed_by_venue',
    'fully_signed',
    'void'
);


--
-- Name: events_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.events_status AS ENUM (
    'draft',
    'published',
    'booked',
    'cancelled',
    'completed'
);


--
-- Name: events_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.events_type AS ENUM (
    'wedding',
    'corporate',
    'birthday',
    'concert',
    'private',
    'dinner_service',
    'lunch_service',
    'other'
);


--
-- Name: kyc_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.kyc_status AS ENUM (
    'pending',
    'submitted',
    'verified',
    'rejected'
);


--
-- Name: notifications_channel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notifications_channel AS ENUM (
    'push',
    'email',
    'sms',
    'in_app'
);


--
-- Name: notifications_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notifications_type AS ENUM (
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


--
-- Name: payments_flow; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payments_flow AS ENUM (
    'immediate',
    'deferred',
    'escrow'
);


--
-- Name: payments_methods; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payments_methods AS ENUM (
    'card',
    'bank_transfer',
    'payhere',
    'authorization_code'
);


--
-- Name: payments_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payments_status AS ENUM (
    'pending',
    'completed',
    'failed',
    'refunded',
    'disputed'
);


--
-- Name: payments_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payments_types AS ENUM (
    'deposit',
    'balance',
    'refund',
    'adjustment'
);


--
-- Name: payout_schedule; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payout_schedule AS ENUM (
    'daily',
    'weekly',
    'monthly',
    'manual'
);


--
-- Name: payout_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payout_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed',
    'reversed'
);


--
-- Name: quotation_request_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quotation_request_status AS ENUM (
    'open',
    'matched',
    'expired',
    'cancelled',
    'converted',
    'declined'
);


--
-- Name: quotation_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quotation_status AS ENUM (
    'pending',
    'accepted',
    'rejected',
    'expired',
    'countered'
);


--
-- Name: quote_decline_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quote_decline_reason AS ENUM (
    'schedule_conflict',
    'outside_service_area',
    'event_type_mismatch',
    'other'
);


--
-- Name: related_entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.related_entity_type AS ENUM (
    'talent',
    'booking',
    'contract',
    'venue',
    'payment'
);


--
-- Name: revenue_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.revenue_type AS ENUM (
    'commission',
    'subscription',
    'advert',
    'adjustment',
    'other'
);


--
-- Name: subscription_plan; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_plan AS ENUM (
    'free',
    'basic',
    'pro',
    'agency'
);


--
-- Name: subscription_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_status AS ENUM (
    'active',
    'cancelled',
    'expired',
    'trialing',
    'paused'
);


--
-- Name: talent_media_resource_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.talent_media_resource_type AS ENUM (
    'image',
    'video',
    'raw',
    'audio'
);


--
-- Name: talent_media_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.talent_media_type AS ENUM (
    'profile_photo',
    'gallery',
    'trailer',
    'live_performance',
    'press_kit',
    'document'
);


--
-- Name: talent_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.talent_status AS ENUM (
    'pending',
    'active',
    'suspended',
    'inactive'
);


--
-- Name: talent_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.talent_type AS ENUM (
    'solo',
    'duo',
    '3-piece',
    'full band',
    'dj'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'client',
    'venue',
    'talent',
    'admin'
);


--
-- Name: user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_status AS ENUM (
    'active',
    'suspended',
    'banned',
    'pending'
);


--
-- Name: venue_account_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.venue_account_purpose AS ENUM (
    'payment',
    'payout'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: check_client_age(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_client_age() RETURNS trigger
    LANGUAGE plpgsql
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


--
-- Name: check_client_approvals_venue_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_client_approvals_venue_only() RETURNS trigger
    LANGUAGE plpgsql
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


--
-- Name: check_client_dob_before_submission(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_client_dob_before_submission() RETURNS trigger
    LANGUAGE plpgsql
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


--
-- Name: check_talent_age(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_talent_age() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL AND NOT is_18_or_over(NEW.date_of_birth) THEN
    RAISE EXCEPTION 'Talent must be 18 or older. Registration cannot proceed with the provided date of birth.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: check_talent_dob_before_submission(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_talent_dob_before_submission() RETURNS trigger
    LANGUAGE plpgsql
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


--
-- Name: enforce_featured_requires_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_featured_requires_admin() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
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


--
-- Name: get_my_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT role::text
  FROM public.profiles_users
  WHERE id = auth.uid()
  LIMIT 1;
$$;


--
-- Name: get_nic_hmac_key(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_nic_hmac_key() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'vault'
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


--
-- Name: get_webhook_secret(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_webhook_secret() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: handle_null_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_null_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
        sequence_name text;
        schema_name text;
        id_column_exists boolean;
    BEGIN
      SELECT INTO id_column_exists
        EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = (SELECT nspname FROM pg_namespace JOIN pg_class ON pg_class.relnamespace = pg_namespace.oid WHERE pg_class.oid = TG_RELID)
            AND table_name = (SELECT relname FROM pg_class WHERE oid = TG_RELID)
            AND column_name = 'id'
        );

        IF NOT id_column_exists THEN
          RETURN NEW;
        END IF;

        SELECT INTO schema_name nspname FROM pg_namespace
        JOIN pg_class ON pg_class.relnamespace = pg_namespace.oid
        WHERE pg_class.oid = TG_RELID;

        SELECT INTO sequence_name pg_get_serial_sequence(quote_ident(schema_name) || '.' || quote_ident(pg_class.relname), 'id')
        FROM pg_class WHERE pg_class.oid = TG_RELID;

        IF sequence_name IS NOT NULL AND NEW.id IS NULL THEN
          NEW.id := nextval(sequence_name);
        END IF;

        RETURN NEW;
    END;
    $$;


--
-- Name: handle_talent_approval(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_talent_approval() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
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


--
-- Name: is_18_or_over(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_18_or_over(dob date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT dob IS NOT NULL AND dob <= (CURRENT_DATE - INTERVAL '18 years');
$$;


--
-- Name: notify_profile_approved(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_profile_approved() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  payload TEXT;
  signature TEXT;
  secret TEXT;
BEGIN
  IF NEW.profile_status = 'active' AND OLD.profile_status != 'active' THEN
    payload := json_build_object(
      'talent_id', NEW.id,
      'user_id', NEW.user_id,
      'event', 'talent.approved'
    )::text;

    SELECT decrypted_secret INTO secret
    FROM vault.decrypted_secrets
    WHERE name = 'webhook_secret'
    LIMIT 1;

    signature := encode(
      hmac(payload, secret, 'sha256'),
      'hex'
    );

    PERFORM net.http_post(
      url := 'en4-webhook-service-production.up.railway.app',
      headers := json_build_object(
        'Content-Type', 'application/json',
        'x-webhook-signature', 'sha256=' || signature
      )::jsonb,
      body := payload
    );
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: notify_talent_approved(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_talent_approved() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  webhook_url  TEXT := 'https://en4-webhook-service-production.up.railway.app/webhook/talent-approved';
  secret_val   TEXT;
  payload      JSONB;
  sig          TEXT;
BEGIN
  -- Only fire when profile is being published
  IF NEW.is_public = true AND NEW.profile_status = 'active' AND
     (OLD.is_public IS DISTINCT FROM true OR OLD.profile_status IS DISTINCT FROM 'active')
  THEN
    SELECT decrypted_secret INTO secret_val
    FROM vault.decrypted_secrets
    WHERE name = 'webhook_secret';

    payload := jsonb_build_object(
      'talent_id',    NEW.id,
      'user_id',      NEW.user_id,
      'stage_name',   NEW.stage_name,
      'approved_at',  now()
    );

    sig := 'sha256=' || encode(
      hmac(payload::text, secret_val, 'sha256'), 'hex'
    );

    PERFORM net.http_post(
      url     := webhook_url,
      body    := payload,
      headers := jsonb_build_object(
        'Content-Type',       'application/json',
        'x-webhook-signature', sig
      )
    );
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: show_create_table(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.show_create_table(p_schema text, p_table_name text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
SELECT 'CREATE TABLE ' || quote_ident(p_schema) || '.' || quote_ident(p_table_name) || ' (' || E'\n' || '' ||
    string_agg(column_list.column_expr, ', ' || E'\n' || '') ||
    '' || E'\n' || ');'
FROM (
  SELECT '    ' || quote_ident(column_name) || ' ' || data_type ||
       coalesce('(' || character_maximum_length || ')', '') ||
       case when is_nullable = 'YES' then '' else ' NOT NULL' end as column_expr
  FROM information_schema.columns
  WHERE table_schema = p_schema AND table_name = p_table_name
  ORDER BY ordinal_position) column_list;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_claims_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    performed_by uuid,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action public.audit_action NOT NULL,
    old_values jsonb,
    new_values jsonb,
    changed_fields text[],
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_audit_action CHECK ((action = ANY (ARRAY['insert'::public.audit_action, 'update'::public.audit_action, 'delete'::public.audit_action, 'login'::public.audit_action, 'approve'::public.audit_action, 'reject'::public.audit_action])))
);

ALTER TABLE ONLY public.audit_log FORCE ROW LEVEL SECURITY;


--
-- Name: authorization_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authorization_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_approval_id uuid NOT NULL,
    client_user_id uuid NOT NULL,
    booking_id uuid NOT NULL,
    code text,
    code_type public.auth_code_types NOT NULL,
    max_amount numeric,
    actual_amount numeric,
    is_used boolean DEFAULT false,
    used_in_payment_id uuid NOT NULL,
    used_at timestamp with time zone NOT NULL,
    generated_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    status public.auth_status,
    notes text,
    CONSTRAINT chk_authcode_actual_positive CHECK ((actual_amount >= (0)::numeric)),
    CONSTRAINT chk_authcode_max_positive CHECK ((max_amount > (0)::numeric)),
    CONSTRAINT chk_authcode_status CHECK ((status = ANY (ARRAY['active'::public.auth_status, 'used'::public.auth_status, 'expired'::public.auth_status, 'cancelled'::public.auth_status]))),
    CONSTRAINT chk_authcode_type CHECK ((code_type = ANY (ARRAY['deposit'::public.auth_code_types, 'full_payment'::public.auth_code_types, 'credit_draw'::public.auth_code_types, 'refund_credit'::public.auth_code_types])))
);

ALTER TABLE ONLY public.authorization_codes FORCE ROW LEVEL SECURITY;


--
-- Name: availability; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.availability (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    available_date_start date,
    start_time time without time zone NOT NULL,
    end_time time without time zone,
    is_blocked boolean DEFAULT false NOT NULL,
    notes text,
    available_date_end date,
    blocked_reason public.availability_blocked_reason,
    CONSTRAINT availability_blocked_reason_check CHECK ((((is_blocked = true) AND (blocked_reason IS NOT NULL)) OR ((is_blocked = false) AND (blocked_reason IS NULL)))),
    CONSTRAINT chk_availability_date_order CHECK ((available_date_end >= available_date_start)),
    CONSTRAINT chk_availability_time_order CHECK ((end_time > start_time))
);

ALTER TABLE ONLY public.availability FORCE ROW LEVEL SECURITY;


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quote_id uuid,
    client_user_id uuid NOT NULL,
    talent_id uuid NOT NULL,
    venue_id uuid,
    event_date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    agreed_gross_amount numeric DEFAULT 0.00 NOT NULL,
    commission_amount numeric DEFAULT 0.00 NOT NULL,
    talent_net_amount numeric,
    deposit_amount numeric DEFAULT 0.00,
    booking_status public.booking_status DEFAULT 'pending'::public.booking_status NOT NULL,
    contract_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_id uuid,
    message_to_talent text,
    currency text DEFAULT 'LKR'::text NOT NULL,
    payment_advanced boolean DEFAULT false NOT NULL,
    payment_advanced_at timestamp with time zone,
    completed_at timestamp with time zone,
    completed_by_user_id uuid,
    auto_completed boolean DEFAULT false NOT NULL,
    gateway_fee_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    bank_charge_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    vat_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    sscl_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    client_total_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT bookings_payment_advanced_check CHECK ((((payment_advanced = false) AND (payment_advanced_at IS NULL)) OR ((payment_advanced = true) AND (payment_advanced_at IS NOT NULL)))),
    CONSTRAINT bookings_total_adds_up_check CHECK (((client_total_amount = 0.00) OR (client_total_amount = (((((agreed_gross_amount + commission_amount) + gateway_fee_amount) + bank_charge_amount) + vat_amount) + sscl_amount)))),
    CONSTRAINT chk_booking_commission_positive CHECK ((commission_amount >= (0)::numeric)),
    CONSTRAINT chk_booking_currency_format CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_booking_deposit_positive CHECK ((deposit_amount >= (0)::numeric)),
    CONSTRAINT chk_booking_gross_positive CHECK ((agreed_gross_amount >= (0)::numeric)),
    CONSTRAINT chk_booking_net_positive CHECK ((talent_net_amount >= (0)::numeric)),
    CONSTRAINT chk_booking_status CHECK ((booking_status = ANY (ARRAY['pending'::public.booking_status, 'confirmed'::public.booking_status, 'cancelled'::public.booking_status, 'completed'::public.booking_status, 'disputed'::public.booking_status]))),
    CONSTRAINT chk_booking_time_order CHECK ((end_time > start_time))
);

ALTER TABLE ONLY public.bookings FORCE ROW LEVEL SECURITY;


--
-- Name: client_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_approvals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_user_id uuid,
    approved_by_user_id uuid NOT NULL,
    approval_type public.client_approval_type NOT NULL,
    credit_limit numeric DEFAULT 250000.00,
    current_balance numeric DEFAULT 0.00 NOT NULL,
    available_credit numeric DEFAULT 250000.00 NOT NULL,
    payment_terms_days smallint DEFAULT 30 NOT NULL,
    approval_status text DEFAULT 'pending'::text NOT NULL,
    approved_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    last_reviewed_at timestamp with time zone DEFAULT now(),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_approval_balance CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT chk_approval_credit_limit CHECK ((credit_limit >= (0)::numeric)),
    CONSTRAINT chk_approval_payment_terms CHECK ((payment_terms_days >= 0)),
    CONSTRAINT chk_approval_status CHECK ((approval_status = ANY (ARRAY['pending'::text, 'approved'::text, 'suspended'::text, 'revoked'::text]))),
    CONSTRAINT chk_approval_type CHECK ((approval_type = ANY (ARRAY['credit_card'::public.client_approval_type, 'deferred_payment'::public.client_approval_type, 'corporate_account'::public.client_approval_type])))
);

ALTER TABLE ONLY public.client_approvals FORCE ROW LEVEL SECURITY;


--
-- Name: client_payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_payment_methods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    method_type public.client_payment_type NOT NULL,
    gateway_token text NOT NULL,
    display_label text DEFAULT ''::text NOT NULL,
    card_brand text,
    card_last_4 text,
    card_expiry_month smallint NOT NULL,
    card_expiry_year smallint NOT NULL,
    bank_name text,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_cpm_card_last4 CHECK ((card_last_4 ~ '^[0-9]{4}$'::text)),
    CONSTRAINT chk_cpm_expiry_month CHECK (((card_expiry_month >= 1) AND (card_expiry_month <= 12))),
    CONSTRAINT chk_cpm_expiry_year CHECK ((card_expiry_year >= 2025)),
    CONSTRAINT chk_cpm_method_type CHECK ((method_type = ANY (ARRAY['card'::public.client_payment_type, 'bank_transfer'::public.client_payment_type, 'authorization_code'::public.client_payment_type, 'corporate_account'::public.client_payment_type])))
);

ALTER TABLE ONLY public.client_payment_methods FORCE ROW LEVEL SECURITY;


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    venue_id uuid NOT NULL,
    talent_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    storage_path text,
    content_text text,
    status public.contract_status NOT NULL,
    signed_by_talent_at timestamp with time zone,
    signed_by_venue_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_contract_status CHECK ((status = ANY (ARRAY['draft'::public.contract_status, 'sent'::public.contract_status, 'signed_by_talent'::public.contract_status, 'signed_by_venue'::public.contract_status, 'fully_signed'::public.contract_status, 'void'::public.contract_status])))
);

ALTER TABLE ONLY public.contracts FORCE ROW LEVEL SECURITY;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    related_entity_type public.related_entity_type NOT NULL,
    related_entity_id uuid NOT NULL,
    file_name text NOT NULL,
    storage_bucket text NOT NULL,
    file_path text NOT NULL,
    uploaded_by_user_id uuid NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.documents FORCE ROW LEVEL SECURITY;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    description text NOT NULL,
    event_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    capacity smallint NOT NULL,
    budget_min numeric NOT NULL,
    budget_max numeric NOT NULL,
    currency text DEFAULT 'LKR'::text NOT NULL,
    genre_tags text NOT NULL,
    status public.events_status DEFAULT 'draft'::public.events_status NOT NULL,
    is_public boolean DEFAULT true NOT NULL,
    booking_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_event_budget_min CHECK ((budget_min >= (0)::numeric)),
    CONSTRAINT chk_event_budget_range CHECK ((budget_max >= budget_min)),
    CONSTRAINT chk_event_capacity_positive CHECK ((capacity > 0)),
    CONSTRAINT chk_event_currency_format CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_event_status CHECK ((status = ANY (ARRAY['draft'::public.events_status, 'published'::public.events_status, 'booked'::public.events_status, 'cancelled'::public.events_status, 'completed'::public.events_status])))
);

ALTER TABLE ONLY public.events FORCE ROW LEVEL SECURITY;


--
-- Name: genres; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.genres (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    genre_name text NOT NULL,
    description text,
    icon_url text,
    display_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_lobby_safe boolean DEFAULT false NOT NULL,
    is_dinner_ambiance boolean DEFAULT false NOT NULL,
    is_pub_crowd boolean DEFAULT false NOT NULL,
    is_high_energy_club boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_genre_display_order CHECK ((display_order >= 0))
);

ALTER TABLE ONLY public.genres FORCE ROW LEVEL SECURITY;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    sender_id uuid DEFAULT auth.uid() NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    attachment_url text,
    attachment_type text,
    is_read boolean DEFAULT false NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_message_attachment_type CHECK ((attachment_type = ANY (ARRAY['image'::text, 'pdf'::text, 'audio'::text, 'video'::text, 'other'::text])))
);

ALTER TABLE ONLY public.messages FORCE ROW LEVEL SECURITY;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type public.notifications_type NOT NULL,
    related_entity_id uuid NOT NULL,
    message_preview text,
    is_read boolean DEFAULT false NOT NULL,
    sent_at timestamp with time zone DEFAULT now(),
    channel public.notifications_channel NOT NULL,
    CONSTRAINT chk_notification_channel CHECK ((channel = ANY (ARRAY['in_app'::public.notifications_channel, 'email'::public.notifications_channel, 'push'::public.notifications_channel, 'sms'::public.notifications_channel])))
);

ALTER TABLE ONLY public.notifications FORCE ROW LEVEL SECURITY;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    payer_user_id uuid DEFAULT auth.uid() NOT NULL,
    payment_type public.payments_types NOT NULL,
    payment_method public.payments_methods NOT NULL,
    gross_amount numeric NOT NULL,
    commission_portion numeric NOT NULL,
    net_to_talent numeric NOT NULL,
    platform_revenue numeric NOT NULL,
    transaction_reference text,
    payment_status public.payments_status NOT NULL,
    paid_at timestamp with time zone,
    payment_flow public.payments_flow NOT NULL,
    payment_gateway_provider text NOT NULL,
    gateway_transaction_id text,
    authorization_code uuid,
    authorization_code_expires_at timestamp with time zone,
    is_pre_approved boolean DEFAULT false NOT NULL,
    gateway_fee numeric DEFAULT 0.00 NOT NULL,
    currency text DEFAULT 'LKR'::text NOT NULL,
    gateway_order_id text DEFAULT ''::text NOT NULL,
    CONSTRAINT chk_payment_commission CHECK ((commission_portion >= (0)::numeric)),
    CONSTRAINT chk_payment_currency_format CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_payment_flow CHECK ((payment_flow = ANY (ARRAY['immediate'::public.payments_flow, 'deferred'::public.payments_flow, 'escrow'::public.payments_flow]))),
    CONSTRAINT chk_payment_gateway_fee CHECK ((gateway_fee >= (0)::numeric)),
    CONSTRAINT chk_payment_gross_positive CHECK ((gross_amount > (0)::numeric)),
    CONSTRAINT chk_payment_method CHECK ((payment_method = ANY (ARRAY['card'::public.payments_methods, 'bank_transfer'::public.payments_methods, 'payhere'::public.payments_methods, 'authorization_code'::public.payments_methods]))),
    CONSTRAINT chk_payment_net_client CHECK ((net_to_talent >= (0)::numeric)),
    CONSTRAINT chk_payment_platform_revenue CHECK ((platform_revenue >= (0)::numeric)),
    CONSTRAINT chk_payment_status CHECK ((payment_status = ANY (ARRAY['pending'::public.payments_status, 'completed'::public.payments_status, 'failed'::public.payments_status, 'refunded'::public.payments_status, 'disputed'::public.payments_status]))),
    CONSTRAINT chk_payment_type CHECK ((payment_type = ANY (ARRAY['deposit'::public.payments_types, 'balance'::public.payments_types, 'refund'::public.payments_types, 'adjustment'::public.payments_types])))
);

ALTER TABLE ONLY public.payments FORCE ROW LEVEL SECURITY;


--
-- Name: profiles_admin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_admin (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    admin_level public.admin_level,
    permissions text DEFAULT ''' { } '''::text,
    department text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_admin_level CHECK ((admin_level = ANY (ARRAY['super_admin'::public.admin_level, 'manager'::public.admin_level, 'partner'::public.admin_level, 'support'::public.admin_level, 'executive'::public.admin_level])))
);

ALTER TABLE ONLY public.profiles_admin FORCE ROW LEVEL SECURITY;


--
-- Name: profiles_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    full_name text DEFAULT ''::text NOT NULL,
    company_name text,
    address_row_1 text,
    preferred_genre text DEFAULT ''''' { } ''''::text''::text'::text,
    preferred_language text DEFAULT ''''' { } ''''::text''::text'::text,
    typical_budget_range text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    address_row_2 text,
    address_city text,
    address_country text,
    address_postal_code smallint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    avatar_url text,
    avatar_public_id text,
    approval_status public.approval_status DEFAULT 'draft'::public.approval_status NOT NULL
);

ALTER TABLE ONLY public.profiles_clients FORCE ROW LEVEL SECURITY;


--
-- Name: profiles_talent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_talent (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid DEFAULT auth.uid() NOT NULL,
    stage_name text DEFAULT ''::text,
    full_name text DEFAULT ''::text NOT NULL,
    email text,
    mobile text,
    url_trailer_video text,
    url_live_performace_video text,
    pricing_per_session numeric,
    primary_location text,
    optional_location_1 text,
    optional_location_2 text,
    optional_location_3 text,
    optional_location_4 text,
    languages text,
    type_of_performer public.talent_type DEFAULT 'solo'::public.talent_type NOT NULL,
    type_of_ensemble text DEFAULT ''::text,
    profile_photo_url text,
    bio text,
    rating numeric DEFAULT 0.00,
    profile_status public.talent_status DEFAULT 'pending'::public.talent_status NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    short_bio text,
    primary_genre_id uuid NOT NULL,
    secondary_genre_id uuid,
    tertiary_genre_id uuid,
    is_public boolean DEFAULT true NOT NULL,
    cover_photo_url text,
    profile_photo_public_id text,
    cover_photo_public_id text,
    en4tainment_profile_id text,
    is_featured boolean DEFAULT false,
    feature_sort_order integer,
    featured_by text,
    featured_at timestamp with time zone,
    featured_expires_at timestamp with time zone,
    approval_status public.approval_status DEFAULT 'draft'::public.approval_status NOT NULL,
    date_of_birth date,
    CONSTRAINT chk_talent_pricing_positive CHECK ((pricing_per_session >= (0)::numeric)),
    CONSTRAINT chk_talent_profile_status CHECK ((profile_status = ANY (ARRAY['pending'::public.talent_status, 'active'::public.talent_status, 'inactive'::public.talent_status, 'suspended'::public.talent_status]))),
    CONSTRAINT chk_talent_rating_range CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric))),
    CONSTRAINT profiles_talent_dob_sane CHECK (((date_of_birth IS NULL) OR ((date_of_birth > '1900-01-01'::date) AND (date_of_birth <= CURRENT_DATE)))),
    CONSTRAINT profiles_talent_genres_distinct_check CHECK ((((secondary_genre_id IS NULL) OR (secondary_genre_id <> primary_genre_id)) AND ((tertiary_genre_id IS NULL) OR (tertiary_genre_id <> primary_genre_id)) AND ((tertiary_genre_id IS NULL) OR (secondary_genre_id IS NULL) OR (tertiary_genre_id <> secondary_genre_id)) AND ((tertiary_genre_id IS NULL) OR (secondary_genre_id IS NOT NULL))))
);


--
-- Name: profiles_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_users (
    id uuid NOT NULL,
    email text DEFAULT ''::text NOT NULL,
    phone numeric NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.user_status DEFAULT 'active'::public.user_status NOT NULL,
    last_login_at timestamp with time zone,
    role text DEFAULT 'client'::text NOT NULL,
    date_of_birth date,
    CONSTRAINT chk_users_role CHECK ((role = ANY (ARRAY['talent'::text, 'client'::text, 'venue'::text, 'admin'::text]))),
    CONSTRAINT chk_users_status CHECK ((status = ANY (ARRAY['active'::public.user_status, 'suspended'::public.user_status, 'banned'::public.user_status, 'pending'::public.user_status]))),
    CONSTRAINT profiles_users_dob_sane CHECK (((date_of_birth IS NULL) OR ((date_of_birth > '1900-01-01'::date) AND (date_of_birth <= CURRENT_DATE)))),
    CONSTRAINT profiles_users_role_valid CHECK ((role = ANY (ARRAY['talent'::text, 'client'::text, 'venue'::text, 'admin'::text])))
);

ALTER TABLE ONLY public.profiles_users FORCE ROW LEVEL SECURITY;


--
-- Name: profiles_venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles_venues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name_of_venue text DEFAULT ''::text NOT NULL,
    name_of_location text DEFAULT ''::text NOT NULL,
    size_of_space integer,
    location_of_venue text,
    url_google_maps_pin text,
    address_row_1 text DEFAULT ''::text NOT NULL,
    required_time_slot text,
    performance_days text DEFAULT ''''''' { } ''''''::text'::text,
    allowed_breaks smallint,
    meals_for_talent boolean DEFAULT false,
    meal_details text,
    audience_age_range text,
    audience_nationality text DEFAULT ''''''' { } ''''''::text'::text,
    type_of_occasion text DEFAULT ''''''' { } ''''''::text'::text,
    music_genre_preference text DEFAULT ''''''' { } ''''''::text'::text,
    language_preference text DEFAULT ''''''' { } ''''''::text'::text,
    contact_person text,
    contact_email text,
    contact_phone text,
    contact_mobile text,
    url_venue_photo text,
    is_verified boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    address_row_2 text DEFAULT ''::text NOT NULL,
    address_city text DEFAULT ''::text NOT NULL,
    address_country text DEFAULT ''::text NOT NULL,
    address_postal_code text DEFAULT ''::text NOT NULL,
    time_per_break smallint,
    avatar_url text,
    avatar_public_id text,
    approval_status public.approval_status DEFAULT 'draft'::public.approval_status NOT NULL,
    CONSTRAINT chk_allowed_breaks CHECK ((allowed_breaks >= 0)),
    CONSTRAINT chk_time_per_break CHECK ((time_per_break >= 0))
);

ALTER TABLE ONLY public.profiles_venues FORCE ROW LEVEL SECURITY;


--
-- Name: quote_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_user_id uuid NOT NULL,
    venue_id uuid,
    event_type public.events_type NOT NULL,
    event_date date NOT NULL,
    start_time time without time zone NOT NULL,
    duration_hours numeric NOT NULL,
    location text,
    budget_min numeric,
    budget_max numeric,
    special_requirements text,
    status public.quotation_request_status,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    talent_id uuid NOT NULL,
    decline_reason public.quote_decline_reason,
    CONSTRAINT chk_qreq_budget_min CHECK ((budget_min >= (0)::numeric)),
    CONSTRAINT chk_qreq_budget_range CHECK ((budget_max >= budget_min)),
    CONSTRAINT chk_qreq_decline_reason_consistency CHECK ((((status = 'declined'::public.quotation_request_status) AND (decline_reason IS NOT NULL)) OR ((status <> 'declined'::public.quotation_request_status) AND (decline_reason IS NULL)))),
    CONSTRAINT chk_qreq_duration_positive CHECK ((duration_hours > (0)::numeric)),
    CONSTRAINT chk_qreq_status CHECK ((status = ANY (ARRAY['open'::public.quotation_request_status, 'matched'::public.quotation_request_status, 'declined'::public.quotation_request_status, 'expired'::public.quotation_request_status, 'cancelled'::public.quotation_request_status, 'converted'::public.quotation_request_status])))
);

ALTER TABLE ONLY public.quote_requests FORCE ROW LEVEL SECURITY;


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quote_request_id uuid NOT NULL,
    talent_id uuid NOT NULL,
    quoted_amount numeric NOT NULL,
    travel_fee numeric DEFAULT 0.00,
    equipment_fee numeric DEFAULT 0.00,
    commission_rate_percent numeric DEFAULT 21.00,
    commission_amount numeric,
    total_client_price numeric,
    talent_net_earnings numeric,
    quote_status public.quotation_status,
    sent_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    notes_to_client text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    counter_used boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_quote_amount_positive CHECK ((quoted_amount >= (0)::numeric)),
    CONSTRAINT chk_quote_commission_amount CHECK ((commission_amount >= (0)::numeric)),
    CONSTRAINT chk_quote_commission_rate CHECK (((commission_rate_percent >= (0)::numeric) AND (commission_rate_percent <= (100)::numeric))),
    CONSTRAINT chk_quote_equipment_fee CHECK ((equipment_fee >= (0)::numeric)),
    CONSTRAINT chk_quote_status CHECK ((quote_status = ANY (ARRAY['pending'::public.quotation_status, 'accepted'::public.quotation_status, 'rejected'::public.quotation_status, 'expired'::public.quotation_status, 'countered'::public.quotation_status]))),
    CONSTRAINT chk_quote_travel_fee CHECK ((travel_fee >= (0)::numeric))
);

ALTER TABLE ONLY public.quotes FORCE ROW LEVEL SECURITY;


--
-- Name: revenue_ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revenue_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    revenue_type public.revenue_type NOT NULL,
    amount numeric NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ledger_amount_nonzero CHECK ((amount <> (0)::numeric)),
    CONSTRAINT chk_ledger_revenue_type CHECK ((revenue_type = ANY (ARRAY['commission'::public.revenue_type, 'subscription'::public.revenue_type, 'advert'::public.revenue_type, 'adjustment'::public.revenue_type, 'other'::public.revenue_type])))
);

ALTER TABLE ONLY public.revenue_ledger FORCE ROW LEVEL SECURITY;


--
-- Name: reviews_star; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews_star (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    reviewer_user_id uuid DEFAULT auth.uid() NOT NULL,
    reviewee_talent_id uuid,
    rating smallint NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewee_venue_id uuid,
    overall_rating numeric,
    stage_presence_rating numeric,
    musical_ability_rating numeric,
    professionalism_rating numeric,
    sound_quality_rating numeric,
    audience_response_rating numeric,
    event_type public.events_type,
    would_book_again boolean,
    is_verified boolean DEFAULT false NOT NULL,
    CONSTRAINT check_rating_range CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT chk_review_audience_response CHECK (((audience_response_rating >= (1)::numeric) AND (audience_response_rating <= (5)::numeric))),
    CONSTRAINT chk_review_musical_ability CHECK (((musical_ability_rating >= (1)::numeric) AND (musical_ability_rating <= (5)::numeric))),
    CONSTRAINT chk_review_overall_rating CHECK (((overall_rating >= (0)::numeric) AND (overall_rating <= (5)::numeric))),
    CONSTRAINT chk_review_professionalism CHECK (((professionalism_rating >= (1)::numeric) AND (professionalism_rating <= (5)::numeric))),
    CONSTRAINT chk_review_rating CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT chk_review_sound_quality CHECK (((sound_quality_rating >= (1)::numeric) AND (sound_quality_rating <= (5)::numeric))),
    CONSTRAINT chk_review_stage_presence CHECK (((stage_presence_rating >= (1)::numeric) AND (stage_presence_rating <= (5)::numeric)))
);

ALTER TABLE ONLY public.reviews_star FORCE ROW LEVEL SECURITY;


--
-- Name: sensitive_asset_access_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensitive_asset_access_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accessed_by_user_id uuid NOT NULL,
    asset_type text NOT NULL,
    object_key text NOT NULL,
    storage_bucket text NOT NULL,
    subject_talent_id uuid,
    subject_entity_id uuid,
    ip_address inet,
    user_agent text,
    accessed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sensitive_asset_access_log_asset_type_check CHECK ((asset_type = ANY (ARRAY['kyc_front'::text, 'kyc_back'::text, 'venue_document'::text])))
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    plan_type public.subscription_plan NOT NULL,
    monthly_fee numeric DEFAULT 0.00,
    start_date date DEFAULT CURRENT_DATE NOT NULL,
    end_date date,
    subscription_status public.subscription_status NOT NULL,
    CONSTRAINT chk_sub_date_range CHECK ((end_date > start_date)),
    CONSTRAINT chk_sub_fee CHECK ((monthly_fee >= (0)::numeric)),
    CONSTRAINT chk_sub_plan_type CHECK ((plan_type = ANY (ARRAY['free'::public.subscription_plan, 'basic'::public.subscription_plan, 'pro'::public.subscription_plan, 'agency'::public.subscription_plan]))),
    CONSTRAINT chk_sub_status CHECK ((subscription_status = ANY (ARRAY['active'::public.subscription_status, 'cancelled'::public.subscription_status, 'expired'::public.subscription_status, 'trialing'::public.subscription_status, 'paused'::public.subscription_status])))
);

ALTER TABLE ONLY public.subscriptions FORCE ROW LEVEL SECURITY;


--
-- Name: talent_favourites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_favourites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    talent_id uuid NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    app_source text DEFAULT 'En4tainment'::text NOT NULL,
    visitor_id uuid,
    CONSTRAINT talent_favourites_app_source_check CHECK ((app_source = ANY (ARRAY['en4tainment'::text, 'en410'::text])))
);

ALTER TABLE ONLY public.talent_favourites FORCE ROW LEVEL SECURITY;


--
-- Name: talent_hearts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_hearts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: talent_identity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_identity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    nic_front_url text,
    nic_back_url text,
    kyc_status public.kyc_status DEFAULT 'pending'::public.kyc_status NOT NULL,
    verified_by uuid,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    nic_front_public_id text,
    nic_back_public_id text,
    nic_storage_bucket text,
    kyc_deletion_requested_at timestamp with time zone,
    kyc_retention_expires_at timestamp with time zone,
    kyc_legal_hold boolean DEFAULT false NOT NULL,
    nic_hash text,
    nic_last_four text,
    CONSTRAINT chk_kyc_status CHECK ((kyc_status = ANY (ARRAY['pending'::public.kyc_status, 'submitted'::public.kyc_status, 'verified'::public.kyc_status, 'rejected'::public.kyc_status]))),
    CONSTRAINT talent_identity_complete_when_submitted_check CHECK (((kyc_status = 'pending'::public.kyc_status) OR ((nic_hash IS NOT NULL) AND (nic_last_four IS NOT NULL) AND (nic_front_public_id IS NOT NULL) AND (nic_back_public_id IS NOT NULL))))
);

ALTER TABLE ONLY public.talent_identity FORCE ROW LEVEL SECURITY;


--
-- Name: talent_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_media (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    cloudinary_public_id text DEFAULT ''::text NOT NULL,
    resource_type public.talent_media_resource_type NOT NULL,
    format text,
    folder text,
    bytes integer,
    media_type public.talent_media_type NOT NULL,
    title text,
    is_featured boolean DEFAULT false NOT NULL,
    sort_order smallint DEFAULT '0'::smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cloudinary_secure_url text,
    CONSTRAINT chk_media_bytes CHECK ((bytes >= 0)),
    CONSTRAINT chk_media_resource_type CHECK ((resource_type = 'image'::public.talent_media_resource_type)),
    CONSTRAINT chk_media_sort_order CHECK ((sort_order >= 0))
);

ALTER TABLE ONLY public.talent_media FORCE ROW LEVEL SECURITY;


--
-- Name: talent_payout_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_payout_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    payable_account_id text DEFAULT ''::text NOT NULL,
    account_display_name text DEFAULT ''::text NOT NULL,
    bank_name text DEFAULT ''::text NOT NULL,
    bank_account_last_4 text DEFAULT ''::text NOT NULL,
    bank_country text DEFAULT '''''LK''''::text'::text,
    currency text DEFAULT '''''LKR''''::text'::text,
    is_default boolean DEFAULT false NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    payable_onboarding_complete boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_payout_acct_currency CHECK ((char_length(currency) = 3))
);

ALTER TABLE ONLY public.talent_payout_accounts FORCE ROW LEVEL SECURITY;


--
-- Name: talent_payout_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_payout_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    booking_id uuid NOT NULL,
    payout_account_id uuid NOT NULL,
    amount numeric DEFAULT '0'::numeric NOT NULL,
    currency text DEFAULT ''::text NOT NULL,
    payout_date timestamp with time zone,
    bank_reference text,
    failure_reason text,
    initiated_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.payout_status DEFAULT 'pending'::public.payout_status NOT NULL,
    CONSTRAINT chk_payout_txn_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT chk_payout_txn_currency CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_payout_txn_status CHECK ((status = ANY (ARRAY['pending'::public.payout_status, 'processing'::public.payout_status, 'completed'::public.payout_status, 'failed'::public.payout_status, 'reversed'::public.payout_status])))
);

ALTER TABLE ONLY public.talent_payout_transactions FORCE ROW LEVEL SECURITY;


--
-- Name: talent_pricing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_pricing (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    label text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text,
    price_amount numeric DEFAULT '1000'::numeric NOT NULL,
    currency text DEFAULT 'LKR'::text NOT NULL,
    duration_minutes smallint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_pricing_amount_positive CHECK ((price_amount >= (0)::numeric)),
    CONSTRAINT chk_pricing_currency_format CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_pricing_duration_positive CHECK ((duration_minutes > 0))
);

ALTER TABLE ONLY public.talent_pricing FORCE ROW LEVEL SECURITY;


--
-- Name: talent_profile_sync_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_profile_sync_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    event_type text NOT NULL,
    status text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT talent_profile_sync_logs_event_type_check CHECK ((event_type = ANY (ARRAY['create'::text, 'update'::text, 'revoke'::text]))),
    CONSTRAINT talent_profile_sync_logs_status_check CHECK ((status = ANY (ARRAY['success'::text, 'failed'::text])))
);


--
-- Name: talent_profile_view; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_profile_view (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    talent_id uuid NOT NULL,
    viewer_user_id uuid NOT NULL,
    viewer_role public.user_role,
    source_page text,
    viewed_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.talent_profile_view FORCE ROW LEVEL SECURITY;


--
-- Name: venue_payment_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_payment_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    display_label text DEFAULT 'LKR'::text NOT NULL,
    currency text DEFAULT 'LKR'::text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    account_purpose public.venue_account_purpose DEFAULT 'payment'::public.venue_account_purpose NOT NULL,
    gateway_token text,
    card_last_4 text,
    card_brand text,
    card_expiry_month smallint,
    card_expiry_year smallint,
    payable_account_id text,
    bank_name text,
    bank_account_last_4 text,
    CONSTRAINT chk_vpa_card_last4 CHECK ((card_last_4 ~ '^[0-9]{4}$'::text)),
    CONSTRAINT chk_vpa_currency CHECK ((char_length(currency) = 3)),
    CONSTRAINT chk_vpa_expiry_month CHECK (((card_expiry_month >= 1) AND (card_expiry_month <= 12))),
    CONSTRAINT chk_vpa_expiry_year CHECK ((card_expiry_year >= 2024)),
    CONSTRAINT chk_vpa_purpose CHECK ((account_purpose = ANY (ARRAY['payment'::public.venue_account_purpose, 'payout'::public.venue_account_purpose])))
);

ALTER TABLE ONLY public.venue_payment_accounts FORCE ROW LEVEL SECURITY;


--
-- Name: webhook_events_seen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_events_seen (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider text NOT NULL,
    event_key text NOT NULL,
    payload_hash text,
    processed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: profiles_admin Admin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_admin
    ADD CONSTRAINT "Admin_pkey" PRIMARY KEY (id);


--
-- Name: authorization_codes AuthorizationCodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_codes
    ADD CONSTRAINT "AuthorizationCodes_pkey" PRIMARY KEY (id);


--
-- Name: availability Availability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability
    ADD CONSTRAINT "Availability_pkey" PRIMARY KEY (id);


--
-- Name: bookings Bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_pkey" PRIMARY KEY (id);


--
-- Name: client_approvals ClientApprovals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_approvals
    ADD CONSTRAINT "ClientApprovals_pkey" PRIMARY KEY (id);


--
-- Name: client_payment_methods Client_Payment_Methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_methods
    ADD CONSTRAINT "Client_Payment_Methods_pkey" PRIMARY KEY (id);


--
-- Name: profiles_clients Clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_clients
    ADD CONSTRAINT "Clients_pkey" PRIMARY KEY (id);


--
-- Name: contracts Contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT "Contracts_pkey" PRIMARY KEY (id);


--
-- Name: documents Documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT "Documents_pkey" PRIMARY KEY (id);


--
-- Name: events Events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT "Events_pkey" PRIMARY KEY (id);


--
-- Name: genres Genres_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT "Genres_pkey" PRIMARY KEY (id);


--
-- Name: talent_favourites HeartSystem_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_favourites
    ADD CONSTRAINT "HeartSystem_pkey" PRIMARY KEY (id);


--
-- Name: notifications Notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT "Notifications_pkey" PRIMARY KEY (id);


--
-- Name: payments Payments_gateway_transaction_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT "Payments_gateway_transaction_id_key" UNIQUE (gateway_transaction_id);


--
-- Name: payments Payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT "Payments_pkey" PRIMARY KEY (id);


--
-- Name: quote_requests QuoteRequests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_requests
    ADD CONSTRAINT "QuoteRequests_pkey" PRIMARY KEY (id);


--
-- Name: quotes Quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT "Quotes_pkey" PRIMARY KEY (id);


--
-- Name: revenue_ledger RevenueLedger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenue_ledger
    ADD CONSTRAINT "RevenueLedger_pkey" PRIMARY KEY (id);


--
-- Name: reviews_star Reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT "Reviews_pkey" PRIMARY KEY (id);


--
-- Name: subscriptions Subcriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT "Subcriptions_pkey" PRIMARY KEY (id);


--
-- Name: talent_profile_view TalentProfileView_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_profile_view
    ADD CONSTRAINT "TalentProfileView_pkey" PRIMARY KEY (id);


--
-- Name: talent_media Talent_Media_CloudinaryPublicID_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_media
    ADD CONSTRAINT "Talent_Media_CloudinaryPublicID_key" UNIQUE (cloudinary_public_id);


--
-- Name: talent_media Talent_Media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_media
    ADD CONSTRAINT "Talent_Media_pkey" PRIMARY KEY (id);


--
-- Name: talent_payout_accounts Talent_Payout_Accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_accounts
    ADD CONSTRAINT "Talent_Payout_Accounts_pkey" PRIMARY KEY (id);


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_PayableTransactionID_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_PayableTransactionID_key" UNIQUE (bank_reference);


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_pkey" PRIMARY KEY (id);


--
-- Name: talent_pricing Talent_Pricing_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_pricing
    ADD CONSTRAINT "Talent_Pricing_pkey" PRIMARY KEY (id);


--
-- Name: profiles_talent Talent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT "Talent_pkey" PRIMARY KEY (id);


--
-- Name: profiles_users Users_Email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_users
    ADD CONSTRAINT "Users_Email_key" UNIQUE (email);


--
-- Name: profiles_users Users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_users
    ADD CONSTRAINT "Users_pkey" PRIMARY KEY (id);


--
-- Name: venue_payment_accounts Venue_Payment_Accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payment_accounts
    ADD CONSTRAINT "Venue_Payment_Accounts_pkey" PRIMARY KEY (id);


--
-- Name: profiles_venues Venues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_venues
    ADD CONSTRAINT "Venues_pkey" PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: profiles_talent profiles_talent_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT profiles_talent_user_id_key UNIQUE (user_id);


--
-- Name: reviews_star reviews_star_booking_reviewer_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT reviews_star_booking_reviewer_unique UNIQUE (booking_id, reviewer_user_id);


--
-- Name: sensitive_asset_access_log sensitive_asset_access_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensitive_asset_access_log
    ADD CONSTRAINT sensitive_asset_access_log_pkey PRIMARY KEY (id);


--
-- Name: talent_favourites talent_favourites_user_talent_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_favourites
    ADD CONSTRAINT talent_favourites_user_talent_unique UNIQUE (user_id, talent_id);


--
-- Name: talent_hearts talent_hearts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_hearts
    ADD CONSTRAINT talent_hearts_pkey PRIMARY KEY (id);


--
-- Name: talent_hearts talent_hearts_talent_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_hearts
    ADD CONSTRAINT talent_hearts_talent_id_user_id_key UNIQUE (talent_id, user_id);


--
-- Name: talent_identity talent_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_identity
    ADD CONSTRAINT talent_identity_pkey PRIMARY KEY (id);


--
-- Name: talent_identity talent_identity_talent_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_identity
    ADD CONSTRAINT talent_identity_talent_id_key UNIQUE (talent_id);


--
-- Name: talent_profile_sync_logs talent_profile_sync_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_profile_sync_logs
    ADD CONSTRAINT talent_profile_sync_logs_pkey PRIMARY KEY (id);


--
-- Name: talent_media uq_talent_media_slot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_media
    ADD CONSTRAINT uq_talent_media_slot UNIQUE (talent_id, sort_order);


--
-- Name: webhook_events_seen webhook_events_seen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events_seen
    ADD CONSTRAINT webhook_events_seen_pkey PRIMARY KEY (id);


--
-- Name: webhook_events_seen webhook_events_seen_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events_seen
    ADD CONSTRAINT webhook_events_seen_unique UNIQUE (provider, event_key);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: idx_audit_deletes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_deletes ON public.audit_log USING btree (action, created_at DESC) WHERE (action = 'delete'::public.audit_action);


--
-- Name: idx_audit_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_record ON public.audit_log USING btree (table_name, record_id);


--
-- Name: idx_audit_table_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_table_time ON public.audit_log USING btree (table_name, created_at DESC);


--
-- Name: idx_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_user ON public.audit_log USING btree (performed_by, created_at DESC);


--
-- Name: idx_profiles_talent_en4_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_talent_en4_id ON public.profiles_talent USING btree (en4tainment_profile_id) WHERE (en4tainment_profile_id IS NOT NULL);


--
-- Name: idx_saal_accessed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_saal_accessed_at ON public.sensitive_asset_access_log USING btree (accessed_at DESC);


--
-- Name: idx_talent_hearts_talent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_talent_hearts_talent_id ON public.talent_hearts USING btree (talent_id);


--
-- Name: talent_favourites_visitor_talent_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX talent_favourites_visitor_talent_unique ON public.talent_favourites USING btree (visitor_id, talent_id) WHERE (visitor_id IS NOT NULL);


--
-- Name: talent_identity_nic_hash_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX talent_identity_nic_hash_key ON public.talent_identity USING btree (nic_hash) WHERE (nic_hash IS NOT NULL);


--
-- Name: profiles_talent set_default_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_default_id BEFORE INSERT ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.handle_null_id();


--
-- Name: profiles_talent talent_approval_webhook; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER talent_approval_webhook AFTER UPDATE ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.notify_talent_approved();


--
-- Name: profiles_users trg_check_client_age; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_client_age BEFORE INSERT OR UPDATE OF date_of_birth, role ON public.profiles_users FOR EACH ROW EXECUTE FUNCTION public.check_client_age();


--
-- Name: profiles_talent trg_check_talent_age; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_talent_age BEFORE INSERT OR UPDATE OF date_of_birth ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.check_talent_age();


--
-- Name: client_approvals trg_client_approvals_venue_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_client_approvals_venue_only BEFORE INSERT OR UPDATE OF venue_user_id ON public.client_approvals FOR EACH ROW EXECUTE FUNCTION public.check_client_approvals_venue_only();


--
-- Name: profiles_talent trg_enforce_featured_requires_admin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_featured_requires_admin BEFORE INSERT OR UPDATE ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.enforce_featured_requires_admin();


--
-- Name: profiles_clients trg_require_client_dob; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_require_client_dob BEFORE INSERT OR UPDATE OF approval_status ON public.profiles_clients FOR EACH ROW EXECUTE FUNCTION public.check_client_dob_before_submission();


--
-- Name: profiles_talent trg_require_talent_dob; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_require_talent_dob BEFORE INSERT OR UPDATE OF approval_status ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.check_talent_dob_before_submission();


--
-- Name: profiles_talent trg_talent_approval; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_talent_approval BEFORE UPDATE ON public.profiles_talent FOR EACH ROW EXECUTE FUNCTION public.handle_talent_approval();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: authorization_codes AuthorizationCodes_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_codes
    ADD CONSTRAINT "AuthorizationCodes_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: authorization_codes AuthorizationCodes_client_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_codes
    ADD CONSTRAINT "AuthorizationCodes_client_approval_id_fkey" FOREIGN KEY (client_approval_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: authorization_codes AuthorizationCodes_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_codes
    ADD CONSTRAINT "AuthorizationCodes_client_user_id_fkey" FOREIGN KEY (client_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: authorization_codes AuthorizationCodes_used_in_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorization_codes
    ADD CONSTRAINT "AuthorizationCodes_used_in_payment_id_fkey" FOREIGN KEY (used_in_payment_id) REFERENCES public.payments(id) ON DELETE CASCADE;


--
-- Name: availability Availability_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability
    ADD CONSTRAINT "Availability_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: bookings Bookings_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_client_user_id_fkey" FOREIGN KEY (client_user_id) REFERENCES public.profiles_users(id);


--
-- Name: bookings Bookings_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_contract_id_fkey" FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: bookings Bookings_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: bookings Bookings_quote_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_quote_id_fkey" FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: bookings Bookings_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id);


--
-- Name: bookings Bookings_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT "Bookings_venue_id_fkey" FOREIGN KEY (venue_id) REFERENCES public.profiles_venues(id);


--
-- Name: client_approvals ClientApprovals_approved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_approvals
    ADD CONSTRAINT "ClientApprovals_approved_by_user_id_fkey" FOREIGN KEY (approved_by_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: client_approvals ClientApprovals_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_approvals
    ADD CONSTRAINT "ClientApprovals_client_user_id_fkey" FOREIGN KEY (venue_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: client_payment_methods Client_Payment_Methods_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_methods
    ADD CONSTRAINT "Client_Payment_Methods_client_id_fkey" FOREIGN KEY (client_id) REFERENCES public.profiles_clients(id) ON DELETE CASCADE;


--
-- Name: contracts Contracts_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT "Contracts_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: contracts Contracts_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT "Contracts_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: contracts Contracts_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT "Contracts_venue_id_fkey" FOREIGN KEY (venue_id) REFERENCES public.profiles_venues(id) ON DELETE CASCADE;


--
-- Name: documents Documents_related_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT "Documents_related_entity_id_fkey" FOREIGN KEY (related_entity_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: documents Documents_uploaded_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT "Documents_uploaded_by_user_id_fkey" FOREIGN KEY (uploaded_by_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: events Events_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT "Events_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: events Events_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT "Events_venue_id_fkey" FOREIGN KEY (venue_id) REFERENCES public.profiles_venues(id) ON DELETE CASCADE;


--
-- Name: notifications Notifications_related_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT "Notifications_related_entity_id_fkey" FOREIGN KEY (related_entity_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: notifications Notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT "Notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: payments Payments_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT "Payments_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: payments Payments_payer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT "Payments_payer_user_id_fkey" FOREIGN KEY (payer_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: profiles_admin Profiles_Admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_admin
    ADD CONSTRAINT "Profiles_Admin_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: profiles_clients Profiles_Clients_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_clients
    ADD CONSTRAINT "Profiles_Clients_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id);


--
-- Name: profiles_talent Profiles_Talent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT "Profiles_Talent_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id);


--
-- Name: profiles_venues Profiles_Venues_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_venues
    ADD CONSTRAINT "Profiles_Venues_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: quote_requests QuoteRequests_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_requests
    ADD CONSTRAINT "QuoteRequests_client_user_id_fkey" FOREIGN KEY (client_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: quote_requests QuoteRequests_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_requests
    ADD CONSTRAINT "QuoteRequests_venue_id_fkey" FOREIGN KEY (venue_id) REFERENCES public.profiles_venues(id) ON DELETE CASCADE;


--
-- Name: quotes Quotes_quote_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT "Quotes_quote_request_id_fkey" FOREIGN KEY (quote_request_id) REFERENCES public.quote_requests(id);


--
-- Name: quotes Quotes_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT "Quotes_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id);


--
-- Name: revenue_ledger RevenueLedger_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenue_ledger
    ADD CONSTRAINT "RevenueLedger_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: talent_favourites Reviews_Heart_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_favourites
    ADD CONSTRAINT "Reviews_Heart_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_favourites Reviews_Heart_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_favourites
    ADD CONSTRAINT "Reviews_Heart_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: reviews_star Reviews_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT "Reviews_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: reviews_star Reviews_reviewee_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT "Reviews_reviewee_talent_id_fkey" FOREIGN KEY (reviewee_talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: reviews_star Reviews_reviewee_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT "Reviews_reviewee_venue_id_fkey" FOREIGN KEY (reviewee_venue_id) REFERENCES public.profiles_venues(id) ON DELETE CASCADE;


--
-- Name: reviews_star Reviews_reviewer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews_star
    ADD CONSTRAINT "Reviews_reviewer_user_id_fkey" FOREIGN KEY (reviewer_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: subscriptions Subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT "Subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: talent_profile_view TalentProfileView_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_profile_view
    ADD CONSTRAINT "TalentProfileView_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_profile_view TalentProfileView_viewer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_profile_view
    ADD CONSTRAINT "TalentProfileView_viewer_user_id_fkey" FOREIGN KEY (viewer_user_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: talent_media Talent_Media_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_media
    ADD CONSTRAINT "Talent_Media_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_payout_accounts Talent_Payout_Accounts_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_accounts
    ADD CONSTRAINT "Talent_Payout_Accounts_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_booking_id_fkey" FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_initiated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_initiated_by_fkey" FOREIGN KEY (initiated_by) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_payout_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_payout_account_id_fkey" FOREIGN KEY (payout_account_id) REFERENCES public.talent_payout_accounts(id) ON DELETE CASCADE;


--
-- Name: talent_payout_transactions Talent_Payout_Transactions_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_payout_transactions
    ADD CONSTRAINT "Talent_Payout_Transactions_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_pricing Talent_Pricing_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_pricing
    ADD CONSTRAINT "Talent_Pricing_talent_id_fkey" FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: venue_payment_accounts Venue_Payment_Accounts_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payment_accounts
    ADD CONSTRAINT "Venue_Payment_Accounts_venue_id_fkey" FOREIGN KEY (venue_id) REFERENCES public.profiles_venues(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_performed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.profiles_users(id) ON DELETE SET NULL;


--
-- Name: bookings bookings_completed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_completed_by_user_id_fkey FOREIGN KEY (completed_by_user_id) REFERENCES public.profiles_users(id) ON DELETE SET NULL;


--
-- Name: messages messages_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles_users(id) ON DELETE CASCADE;


--
-- Name: payments payments_authorization_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_authorization_code_fkey FOREIGN KEY (authorization_code) REFERENCES public.authorization_codes(id) ON DELETE CASCADE;


--
-- Name: profiles_talent profiles_talent_primary_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT profiles_talent_primary_genre_id_fkey FOREIGN KEY (primary_genre_id) REFERENCES public.genres(id);


--
-- Name: profiles_talent profiles_talent_secondary_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT profiles_talent_secondary_genre_id_fkey FOREIGN KEY (secondary_genre_id) REFERENCES public.genres(id) ON DELETE SET NULL;


--
-- Name: profiles_talent profiles_talent_tertiary_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_talent
    ADD CONSTRAINT profiles_talent_tertiary_genre_id_fkey FOREIGN KEY (tertiary_genre_id) REFERENCES public.genres(id) ON DELETE SET NULL;


--
-- Name: profiles_users profiles_users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles_users
    ADD CONSTRAINT profiles_users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: quote_requests quote_requests_preferred_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_requests
    ADD CONSTRAINT quote_requests_preferred_talent_id_fkey FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id);


--
-- Name: talent_hearts talent_hearts_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_hearts
    ADD CONSTRAINT talent_hearts_talent_id_fkey FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_hearts talent_hearts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_hearts
    ADD CONSTRAINT talent_hearts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: talent_identity talent_identity_talent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_identity
    ADD CONSTRAINT talent_identity_talent_id_fkey FOREIGN KEY (talent_id) REFERENCES public.profiles_talent(id) ON DELETE CASCADE;


--
-- Name: talent_identity talent_identity_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_identity
    ADD CONSTRAINT talent_identity_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.profiles_users(id) ON DELETE SET NULL;


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_admin admin_profile_admin_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_profile_admin_only ON public.profiles_admin TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_users
  WHERE ((profiles_users.id = auth.uid()) AND (profiles_users.role = 'admin'::text)))));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_log_admin_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_admin_only ON public.audit_log FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_users
  WHERE ((profiles_users.id = auth.uid()) AND (profiles_users.role = 'admin'::text)))));


--
-- Name: authorization_codes authcodes_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authcodes_read_own ON public.authorization_codes FOR SELECT TO authenticated USING ((auth.uid() = client_user_id));


--
-- Name: authorization_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.authorization_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: availability; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;

--
-- Name: availability availability_authenticated_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY availability_authenticated_read ON public.availability FOR SELECT TO authenticated USING (true);


--
-- Name: availability availability_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY availability_manage_own ON public.availability TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = availability.talent_id) AND (profiles_talent.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = availability.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: bookings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

--
-- Name: bookings bookings_client_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_client_insert ON public.bookings FOR INSERT TO authenticated WITH CHECK ((auth.uid() = client_user_id));


--
-- Name: bookings bookings_client_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_client_update ON public.bookings FOR UPDATE TO authenticated USING ((auth.uid() = client_user_id));


--
-- Name: bookings bookings_participant_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_participant_read ON public.bookings FOR SELECT TO authenticated USING (((auth.uid() = client_user_id) OR (EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = bookings.talent_id) AND (profiles_talent.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = bookings.venue_id) AND (profiles_venues.user_id = auth.uid()))))));


--
-- Name: client_approvals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: client_approvals client_approvals_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_approvals_read_own ON public.client_approvals FOR SELECT TO authenticated USING ((auth.uid() = venue_user_id));


--
-- Name: client_payment_methods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_payment_methods ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_clients client_profile_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_profile_manage_own ON public.profiles_clients TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: contracts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;

--
-- Name: contracts contracts_participant_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contracts_participant_read ON public.contracts FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = contracts.talent_id) AND (profiles_talent.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = contracts.venue_id) AND (profiles_venues.user_id = auth.uid()))))));


--
-- Name: client_payment_methods cpm_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cpm_manage_own ON public.client_payment_methods TO authenticated USING ((auth.uid() = client_id)) WITH CHECK ((auth.uid() = client_id));


--
-- Name: documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: documents documents_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documents_read_own ON public.documents FOR SELECT TO authenticated USING ((auth.uid() = uploaded_by_user_id));


--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

--
-- Name: events events_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY events_public_read ON public.events FOR SELECT TO authenticated, anon USING (((is_public = true) AND (status = ANY (ARRAY['published'::public.events_status, 'booked'::public.events_status, 'completed'::public.events_status]))));


--
-- Name: events events_venue_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY events_venue_manage ON public.events TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = events.venue_id) AND (profiles_venues.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = events.venue_id) AND (profiles_venues.user_id = auth.uid())))));


--
-- Name: talent_favourites fav_anon_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fav_anon_insert ON public.talent_favourites FOR INSERT TO anon WITH CHECK (((user_id IS NULL) AND (visitor_id IS NOT NULL) AND (app_source = 'en4tainment'::text)));


--
-- Name: talent_favourites fav_client_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fav_client_insert ON public.talent_favourites FOR INSERT TO authenticated WITH CHECK (((public.get_my_role() = 'client'::text) AND (auth.uid() = user_id) AND (app_source = 'en4tainment'::text)));


--
-- Name: genres; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.genres ENABLE ROW LEVEL SECURITY;

--
-- Name: genres genres_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY genres_admin_write ON public.genres TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_users
  WHERE ((profiles_users.id = auth.uid()) AND (profiles_users.role = 'admin'::text)))));


--
-- Name: genres genres_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY genres_public_read ON public.genres FOR SELECT TO authenticated, anon USING ((is_active = true));


--
-- Name: revenue_ledger ledger_admin_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ledger_admin_only ON public.revenue_ledger FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_users
  WHERE ((profiles_users.id = auth.uid()) AND (profiles_users.role = 'admin'::text)))));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages_participant_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_participant_access ON public.messages TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.bookings b
  WHERE ((b.id = messages.booking_id) AND ((b.client_user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.profiles_talent
          WHERE ((profiles_talent.id = b.talent_id) AND (profiles_talent.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
           FROM public.profiles_venues
          WHERE ((profiles_venues.id = b.venue_id) AND (profiles_venues.user_id = auth.uid()))))))))) WITH CHECK ((auth.uid() = sender_id));


--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_read_own ON public.notifications FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: notifications notifications_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_update_own ON public.notifications FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: payments payments_payer_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payments_payer_read ON public.payments FOR SELECT TO authenticated USING ((auth.uid() = payer_user_id));


--
-- Name: talent_profile_view profile_view_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profile_view_read_own ON public.talent_profile_view FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_profile_view.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: profiles_admin; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles_admin ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_clients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles_clients ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_talent; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles_talent ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles_users ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_venues; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles_venues ENABLE ROW LEVEL SECURITY;

--
-- Name: quote_requests qr_talent_select_targeted; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY qr_talent_select_targeted ON public.quote_requests FOR SELECT TO authenticated USING ((auth.uid() IN ( SELECT profiles_talent.user_id
   FROM public.profiles_talent
  WHERE (profiles_talent.id = quote_requests.talent_id))));


--
-- Name: quote_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quote_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: quote_requests quote_requests_client_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quote_requests_client_manage ON public.quote_requests TO authenticated USING ((auth.uid() = client_user_id)) WITH CHECK ((auth.uid() = client_user_id));


--
-- Name: quote_requests quote_requests_talent_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quote_requests_talent_read ON public.quote_requests FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.quotes q
     JOIN public.profiles_talent pt ON ((pt.id = q.talent_id)))
  WHERE ((q.quote_request_id = quote_requests.id) AND (pt.user_id = auth.uid())))));


--
-- Name: quotes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

--
-- Name: quotes quotes_client_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_client_read ON public.quotes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.quote_requests qr
  WHERE ((qr.id = quotes.quote_request_id) AND (qr.client_user_id = auth.uid())))));


--
-- Name: quotes quotes_talent_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_talent_manage ON public.quotes TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = quotes.talent_id) AND (profiles_talent.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = quotes.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: reviews_star rev_client_or_venue_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rev_client_or_venue_insert ON public.reviews_star FOR INSERT TO authenticated WITH CHECK (((auth.uid() = reviewer_user_id) AND (((public.get_my_role() = 'client'::text) AND (EXISTS ( SELECT 1
   FROM public.bookings
  WHERE ((bookings.id = reviews_star.booking_id) AND (bookings.client_user_id = auth.uid()) AND (bookings.booking_status = 'completed'::public.booking_status))))) OR ((public.get_my_role() = 'venue'::text) AND (EXISTS ( SELECT 1
   FROM (public.bookings
     JOIN public.profiles_venues ON ((profiles_venues.id = bookings.venue_id)))
  WHERE ((bookings.id = reviews_star.booking_id) AND (profiles_venues.user_id = auth.uid()) AND (bookings.booking_status = 'completed'::public.booking_status))))))));


--
-- Name: revenue_ledger; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.revenue_ledger ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews_star; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews_star ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews_star reviews_star_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_star_public_read ON public.reviews_star FOR SELECT TO authenticated, anon USING ((is_verified = true));


--
-- Name: talent_favourites rh_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rh_admin_all ON public.talent_favourites TO authenticated USING ((public.get_my_role() = 'admin'::text)) WITH CHECK ((public.get_my_role() = 'admin'::text));


--
-- Name: talent_favourites rh_client_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rh_client_delete ON public.talent_favourites FOR DELETE TO authenticated USING (((public.get_my_role() = 'client'::text) AND (auth.uid() = user_id)));


--
-- Name: talent_favourites rh_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rh_select_public ON public.talent_favourites FOR SELECT USING (true);


--
-- Name: reviews_star rs_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_admin_all ON public.reviews_star TO authenticated USING ((public.get_my_role() = 'admin'::text)) WITH CHECK ((public.get_my_role() = 'admin'::text));


--
-- Name: sensitive_asset_access_log saal_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saal_admin_select ON public.sensitive_asset_access_log FOR SELECT TO authenticated USING ((public.get_my_role() = 'admin'::text));


--
-- Name: sensitive_asset_access_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sensitive_asset_access_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.audit_log TO service_role USING (true) WITH CHECK (true);


--
-- Name: authorization_codes service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.authorization_codes TO service_role USING (true) WITH CHECK (true);


--
-- Name: availability service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.availability TO service_role USING (true) WITH CHECK (true);


--
-- Name: bookings service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.bookings TO service_role USING (true) WITH CHECK (true);


--
-- Name: client_approvals service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.client_approvals TO service_role USING (true) WITH CHECK (true);


--
-- Name: client_payment_methods service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.client_payment_methods TO service_role USING (true) WITH CHECK (true);


--
-- Name: contracts service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.contracts TO service_role USING (true) WITH CHECK (true);


--
-- Name: documents service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.documents TO service_role USING (true) WITH CHECK (true);


--
-- Name: events service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.events TO service_role USING (true) WITH CHECK (true);


--
-- Name: genres service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.genres TO service_role USING (true) WITH CHECK (true);


--
-- Name: messages service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.messages TO service_role USING (true) WITH CHECK (true);


--
-- Name: notifications service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.notifications TO service_role USING (true) WITH CHECK (true);


--
-- Name: payments service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.payments TO service_role USING (true) WITH CHECK (true);


--
-- Name: profiles_admin service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.profiles_admin TO service_role USING (true) WITH CHECK (true);


--
-- Name: profiles_clients service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.profiles_clients TO service_role USING (true) WITH CHECK (true);


--
-- Name: profiles_talent service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.profiles_talent TO service_role USING (true) WITH CHECK (true);


--
-- Name: profiles_users service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.profiles_users TO service_role USING (true) WITH CHECK (true);


--
-- Name: profiles_venues service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.profiles_venues TO service_role USING (true) WITH CHECK (true);


--
-- Name: quote_requests service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.quote_requests TO service_role USING (true) WITH CHECK (true);


--
-- Name: quotes service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.quotes TO service_role USING (true) WITH CHECK (true);


--
-- Name: revenue_ledger service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.revenue_ledger TO service_role USING (true) WITH CHECK (true);


--
-- Name: reviews_star service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.reviews_star TO service_role USING (true) WITH CHECK (true);


--
-- Name: subscriptions service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.subscriptions TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_favourites service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_favourites TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_identity service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_identity TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_media service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_media TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_payout_accounts service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_payout_accounts TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_payout_transactions service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_payout_transactions TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_pricing service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_pricing TO service_role USING (true) WITH CHECK (true);


--
-- Name: talent_profile_view service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.talent_profile_view TO service_role USING (true) WITH CHECK (true);


--
-- Name: venue_payment_accounts service_role_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access ON public.venue_payment_accounts TO service_role USING (true) WITH CHECK (true);


--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: subscriptions subscriptions_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subscriptions_read_own ON public.subscriptions FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: talent_profile_sync_logs sync_log_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_log_admin_select ON public.talent_profile_sync_logs FOR SELECT TO authenticated USING ((public.get_my_role() = 'admin'::text));


--
-- Name: talent_favourites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_favourites ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_hearts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_hearts ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_identity; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_identity ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_identity talent_identity_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_identity_read_own ON public.talent_identity FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_identity.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: talent_media; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_media ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_media talent_media_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_media_manage_own ON public.talent_media TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_media.talent_id) AND (profiles_talent.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_media.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: talent_media talent_media_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_media_public_read ON public.talent_media FOR SELECT TO authenticated, anon USING (true);


--
-- Name: talent_payout_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_payout_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_payout_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_payout_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_pricing; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_pricing ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_pricing talent_pricing_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_pricing_manage_own ON public.talent_pricing TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_pricing.talent_id) AND (profiles_talent.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_pricing.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: talent_pricing talent_pricing_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_pricing_public_read ON public.talent_pricing FOR SELECT TO authenticated, anon USING ((is_active = true));


--
-- Name: profiles_talent talent_profile_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_profile_manage_own ON public.profiles_talent TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles_talent talent_profile_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_profile_read_own ON public.profiles_talent FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: talent_profile_sync_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_profile_sync_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: talent_profile_view; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.talent_profile_view ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_talent talent_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_select_public ON public.profiles_talent FOR SELECT USING ((is_public = true));


--
-- Name: profiles_talent talent_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY talent_update_own ON public.profiles_talent FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: talent_hearts th_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY th_delete_own ON public.talent_hearts FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: talent_hearts th_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY th_insert_own ON public.talent_hearts FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: talent_hearts th_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY th_select_all ON public.talent_hearts FOR SELECT TO authenticated, anon USING (true);


--
-- Name: talent_identity ti_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ti_insert_own ON public.talent_identity FOR INSERT TO authenticated WITH CHECK ((auth.uid() IN ( SELECT profiles_talent.user_id
   FROM public.profiles_talent
  WHERE (profiles_talent.id = talent_identity.talent_id))));


--
-- Name: talent_media tm_talent_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tm_talent_insert ON public.talent_media FOR INSERT TO authenticated WITH CHECK ((auth.uid() IN ( SELECT profiles_talent.user_id
   FROM public.profiles_talent
  WHERE (profiles_talent.id = talent_media.talent_id))));


--
-- Name: talent_media tm_talent_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tm_talent_update ON public.talent_media FOR UPDATE TO authenticated USING ((auth.uid() IN ( SELECT profiles_talent.user_id
   FROM public.profiles_talent
  WHERE (profiles_talent.id = talent_media.talent_id))));


--
-- Name: talent_payout_accounts tpa_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tpa_manage_own ON public.talent_payout_accounts TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_payout_accounts.talent_id) AND (profiles_talent.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_payout_accounts.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: talent_payout_transactions tpt_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tpt_read_own ON public.talent_payout_transactions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_talent
  WHERE ((profiles_talent.id = talent_payout_transactions.talent_id) AND (profiles_talent.user_id = auth.uid())))));


--
-- Name: profiles_users users_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_read_own ON public.profiles_users FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: profiles_users users_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_own ON public.profiles_users FOR UPDATE TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: venue_payment_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venue_payment_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles_venues venue_profile_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY venue_profile_manage_own ON public.profiles_venues TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: venue_payment_accounts vpa_manage_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vpa_manage_own ON public.venue_payment_accounts TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = venue_payment_accounts.venue_id) AND (profiles_venues.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles_venues
  WHERE ((profiles_venues.id = venue_payment_accounts.venue_id) AND (profiles_venues.user_id = auth.uid())))));


--
-- Name: webhook_events_seen; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.webhook_events_seen ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict KrPRMlCSXdrzjFfqUVz0diTKT7q1vAghX0IWI36LBvcNW67Yf1Wz6Ya12CZe7wE

