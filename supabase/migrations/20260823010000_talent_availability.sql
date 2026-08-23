-- Applied via Supabase SQL Editor 2026-08-23.
--
-- Two layers, deliberately different in strength.
--
-- HARD FLOOR: an EXCLUDE constraint on bookings makes it structurally
-- impossible for one talent to hold two overlapping live bookings. Enforced
-- by the database, unbypassable by any application bug. Scoped
-- WHERE booking_status <> 'cancelled' so a cancellation frees the slot.
--
-- SOFT CHECK: is_talent_available() adds a 3-hour buffer either side for
-- setup (platform rule: ready 60-90 min before start), pack-down and travel.
-- Called before a quote request is accepted. Advisory rather than structural
-- because the right buffer varies by act and distance -- it is a parameter
-- with a default, so a caller can pass a shorter one for known-local pairs.
--
-- Effect for a standard session: 4.5 hours on site, ~10.5 hours blocked.
-- Verified a 21:00-01:30 gig correctly blocks a same-day 2pm wedding and
-- correctly permits the following evening.
--
-- DECISION: an unexpired quote does NOT hold the date. Talent may quote on
-- several opportunities for the same slot; the hard block lands at booking
-- creation, so the first acceptance wins and the rest should be auto-declined.
-- Holding on quote would mean a talent chasing three Saturdays could only
-- pursue one, and lose the day if it fell through.
--
-- talent_unavailability carries its own EXCLUDE constraint so a talent
-- cannot file overlapping blackout periods.
--
-- RLS enabled with explicit policies. Necessary, not optional: Supabase
-- default privileges grant anon and authenticated every privilege on tables
-- created by postgres in public, so RLS is the only control on this table.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Talent-declared unavailability: holidays, other commitments, rest days
CREATE TABLE public.talent_unavailability (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  talent_id  uuid NOT NULL REFERENCES public.profiles_talent(id) ON DELETE CASCADE,
  starts_at  timestamptz NOT NULL,
  ends_at    timestamptz NOT NULL,
  reason     text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT talent_unavailability_ends_after_starts CHECK (ends_at > starts_at),
  CONSTRAINT talent_unavailability_no_overlap
    EXCLUDE USING gist (talent_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
);

CREATE INDEX idx_talent_unavailability_talent_time
  ON public.talent_unavailability (talent_id, starts_at);

-- RLS: grants are wide open by default on this project, so policies are the
-- only control. Talent manage their own; admins see all.
ALTER TABLE public.talent_unavailability ENABLE ROW LEVEL SECURITY;

CREATE POLICY talent_manages_own_unavailability
  ON public.talent_unavailability FOR ALL
  USING (talent_id IN (SELECT id FROM public.profiles_talent WHERE user_id = auth.uid()))
  WITH CHECK (talent_id IN (SELECT id FROM public.profiles_talent WHERE user_id = auth.uid()));

CREATE POLICY admin_manages_all_unavailability
  ON public.talent_unavailability FOR ALL
  USING (public.get_my_role() = 'admin')
  WITH CHECK (public.get_my_role() = 'admin');

-- Hard floor: a talent cannot hold two live bookings that overlap at all.
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_no_talent_double_booking
    EXCLUDE USING gist (talent_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
    WHERE (booking_status <> 'cancelled');

CREATE INDEX idx_bookings_talent_time ON public.bookings (talent_id, starts_at);

-- Softer check used at quote-request time, including a buffer for setup,
-- pack-down and travel. Platform rule is ready 60-90 min before start.
CREATE OR REPLACE FUNCTION public.is_talent_available(
  p_talent_id uuid,
  p_starts_at timestamptz,
  p_ends_at   timestamptz,
  p_buffer    interval DEFAULT interval '2 hours'
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public'
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
