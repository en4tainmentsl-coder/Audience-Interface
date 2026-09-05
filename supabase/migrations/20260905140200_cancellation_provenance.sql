-- Cancellation provenance on bookings.
--
-- Verified live 2026-09-05: bookings had ZERO cancellation columns. Completion
-- provenance exists (completed_at, completed_by_user_id, auto_completed);
-- cancellation never got the same treatment, so a cancelled booking recorded
-- nothing about who cancelled it or why.
--
-- The status transition trigger already permits pending -> cancelled and
-- confirmed -> cancelled, and treats cancelled as terminal. This migration
-- gives that transition somewhere to write its reasons.

-- 1. Reason enum. One type, not three, with a role CHECK below keeping each
--    side to its own values -- one column keeps queries simple and stops a
--    talent-side reason appearing on a client cancellation.
CREATE TYPE public.cancellation_reason AS ENUM (
  -- client / venue
  'event_cancelled',
  'event_postponed',
  'venue_unavailable',
  'budget_withdrawn',
  'booked_alternative_talent',
  'talent_unresponsive',
  'details_not_agreed',
  'created_in_error',
  'client_other',
  -- talent
  'illness_or_injury',
  'family_emergency',
  'double_booked',
  'transport_failure',
  'equipment_failure',
  'band_member_unavailable',
  'event_terms_changed',
  'safety_concern',
  'talent_other',
  -- admin / platform
  'fraud_or_policy_violation',
  'payment_not_received',
  'duplicate_or_test',
  'admin_other'
);

-- 2. Provenance columns. cancelled_by_role reuses the existing user_role enum
--    (client, venue, talent, admin) rather than minting a parallel type.
ALTER TABLE public.bookings
  ADD COLUMN cancelled_at         timestamptz,
  ADD COLUMN cancelled_by_user_id uuid REFERENCES public.profiles_users(id) ON DELETE SET NULL,
  ADD COLUMN cancelled_by_role    public.user_role,
  ADD COLUMN cancellation_reason  public.cancellation_reason,
  ADD COLUMN cancellation_note    text;

-- 3. Money decided AT cancellation, before it actually moves.
--    Refunds go via HNB manually within 7 working days, so the decision and
--    the disbursement are days apart. These record the decision; the payments
--    table records the disbursement when it happens.
--
--    cancellation_fee_amount    retained from the client, or charged to the
--                               talent as a penalty. En4 revenue.
--    talent_compensation_amount the 20% portion of a client-side convenience
--                               fee. Belongs to the TALENT, not En4 -- kept
--                               separate so it is never booked as revenue.
--    refund_due_amount          what goes back to the client.
ALTER TABLE public.bookings
  ADD COLUMN cancellation_fee_amount    numeric NOT NULL DEFAULT 0.00,
  ADD COLUMN talent_compensation_amount numeric NOT NULL DEFAULT 0.00,
  ADD COLUMN refund_due_amount          numeric NOT NULL DEFAULT 0.00;

ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_fee_nonneg    CHECK (cancellation_fee_amount    >= 0),
  ADD CONSTRAINT chk_talent_compensation_nonneg CHECK (talent_compensation_amount >= 0),
  ADD CONSTRAINT chk_refund_due_nonneg          CHECK (refund_due_amount          >= 0);

-- 4. Status and provenance move together, in both directions.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancelled_status_has_provenance CHECK (
    (booking_status = 'cancelled'::booking_status) = (cancelled_at IS NOT NULL)
  );

-- 5. Completeness. Deliberately EXCLUDES cancelled_by_user_id: that FK is
--    ON DELETE SET NULL, so a PDPA erasure would otherwise retroactively
--    violate this constraint on a historical booking. Erasure must not break
--    the ledger. Role and reason survive erasure and carry the meaning.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_provenance_complete CHECK (
    (cancelled_at IS NULL
      AND cancelled_by_role   IS NULL
      AND cancellation_reason IS NULL)
    OR
    (cancelled_at IS NOT NULL
      AND cancelled_by_role   IS NOT NULL
      AND cancellation_reason IS NOT NULL)
  );

-- 6. Reason must belong to the cancelling side. Client and venue share a set.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_reason_matches_role CHECK (
    cancellation_reason IS NULL
    OR (cancelled_by_role IN ('client','venue') AND cancellation_reason IN (
          'event_cancelled','event_postponed','venue_unavailable',
          'budget_withdrawn','booked_alternative_talent','talent_unresponsive',
          'details_not_agreed','created_in_error','client_other'))
    OR (cancelled_by_role = 'talent' AND cancellation_reason IN (
          'illness_or_injury','family_emergency','double_booked',
          'transport_failure','equipment_failure','band_member_unavailable',
          'event_terms_changed','safety_concern','talent_other'))
    OR (cancelled_by_role = 'admin' AND cancellation_reason IN (
          'fraud_or_policy_violation','payment_not_received',
          'duplicate_or_test','admin_other'))
  );

-- 7. "Other" is not a reason on its own -- it requires the free text.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_note_required_for_other CHECK (
    cancellation_reason IS NULL
    OR cancellation_reason NOT IN ('client_other','talent_other','admin_other')
    OR (cancellation_note IS NOT NULL AND length(btrim(cancellation_note)) > 0)
  );