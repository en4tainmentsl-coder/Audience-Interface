-- Applied via Supabase SQL Editor 2026-08-22. The SQL was never captured at
-- the time; this file was reconstructed on 2026-08-28 from the delta between
-- 20260822000000_baseline.sql and live schema, with every other post-baseline
-- migration's effects subtracted so only this change remains. See the
-- reconstruction note at the foot of this file.
--
-- Replaces (event_date, start_time, duration_hours) on quote_requests and
-- (event_date, start_time, end_time) on bookings with explicit timestamptz
-- ranges.
--
-- Reason: a 21:00-01:00 gig cannot be expressed as date + time + duration
-- without wrap logic at every read site, and most live entertainment
-- bookings cross midnight. With a range, duration is plain subtraction,
-- overlap and availability checks are native, and midnight is a non-event.
--
-- duration_hours retained as GENERATED ALWAYS so it can never drift from
-- the range. Drives the 4-hour floor and proportional scaling above it.
--
-- NOTE: timestamptz stores UTC. Render in Asia/Colombo. Any ::date cast
-- must apply AT TIME ZONE 'Asia/Colombo' first, or a 21:00 Colombo event
-- reports as the following day.
--
-- Safe to drop columns: zero rows in all application tables, and no
-- function, policy or view referenced them.

-- ── quote_requests ─────────────────────────────────────────────────────────

-- duration_hours must be dropped and re-added rather than altered: Postgres
-- has no ALTER COLUMN ... SET GENERATED for turning an existing plain column
-- into a generated one.
--
-- chk_qreq_duration_positive is dropped with it. A CHECK on a generated
-- column is legal, but the constraint is now unreachable by construction --
-- ends_at > starts_at is enforced directly below, which makes a positive
-- duration a consequence rather than a separate rule.
ALTER TABLE public.quote_requests
  DROP CONSTRAINT chk_qreq_duration_positive;

ALTER TABLE public.quote_requests
  DROP COLUMN event_date,
  DROP COLUMN start_time,
  DROP COLUMN duration_hours;

ALTER TABLE public.quote_requests
  ADD COLUMN starts_at timestamptz NOT NULL,
  ADD COLUMN ends_at   timestamptz NOT NULL;

-- Nullable by definition: a generated column is not declared NOT NULL here
-- because starts_at and ends_at already are, so the expression can never
-- yield NULL.
ALTER TABLE public.quote_requests
  ADD COLUMN duration_hours numeric
    GENERATED ALWAYS AS (EXTRACT(epoch FROM (ends_at - starts_at)) / 3600) STORED;

ALTER TABLE public.quote_requests
  ADD CONSTRAINT quote_requests_ends_after_starts
    CHECK (ends_at > starts_at);

-- ── bookings ───────────────────────────────────────────────────────────────

-- chk_booking_time_order (end_time > start_time) is dropped implicitly with
-- its columns, but is dropped explicitly first so the intent is visible and
-- the migration does not rely on cascade behaviour.
ALTER TABLE public.bookings
  DROP CONSTRAINT chk_booking_time_order;

ALTER TABLE public.bookings
  DROP COLUMN event_date,
  DROP COLUMN start_time,
  DROP COLUMN end_time;

ALTER TABLE public.bookings
  ADD COLUMN starts_at timestamptz NOT NULL,
  ADD COLUMN ends_at   timestamptz NOT NULL;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_ends_after_starts
    CHECK (ends_at > starts_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- RECONSTRUCTION NOTE  (2026-08-28)
--
-- This file previously contained the comment block above and NO SQL AT ALL.
-- It was written as documentation of a change applied by hand in the SQL
-- Editor, and no statements were ever recorded -- not in the file, and not in
-- supabase_migrations.schema_migrations, which has no row for this version.
--
-- Consequence while it was empty: replaying the migration set from scratch
-- produced quote_requests and bookings with the OLD (event_date, start_time)
-- shape, differing from production on the two tables the entire booking flow
-- depends on. A rebuilt or staging database would have been silently wrong.
--
-- How the statements below were derived, and why they are trustworthy:
--
--   1. Baseline (20260822000000) was confirmed to hold the OLD shape:
--      event_date date, start_time time, duration_hours numeric NOT NULL,
--      plus chk_qreq_duration_positive and chk_booking_time_order.
--
--   2. Live schema was read for both tables -- columns, generation
--      expressions, CHECK and EXCLUDE constraints, and indexes.
--
--   3. Every other post-baseline migration touching these tables was read and
--      its effects subtracted:
--        20260822230000_location_coordinates       -> event_latitude,
--            event_longitude, event_address, quote_requests_coords_valid,
--            quote_requests_has_location
--        20260823000000_quote_fields_and_commission_base
--                                                  -> performer_count,
--            talent_rate_at_request, set_quote_expiry()
--        20260823010000_talent_availability        -> bookings_no_talent_
--            double_booking, idx_bookings_talent_time
--        20260824175259_..._rate_snapshot_trigger  -> trg_quote_requests_
--            rate_snapshot
--
--   4. What remained unattributed is exactly the statements above.
--
-- Two independent checks support the ordering: the exclusion constraint and
-- index added by 20260823010000_talent_availability both reference starts_at
-- and ends_at, so those columns must already exist by then -- which the
-- version ordering (20260822210000 < 20260823010000) gives.
--
-- NOT VERIFIED BY REPLAY. Until a fresh database built from files alone is
-- diffed against production, this reconstruction is careful inference, not
-- proof. Treat that replay as the acceptance test for this file.
-- ═══════════════════════════════════════════════════════════════════════════
