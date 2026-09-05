-- Require a short explanation on every talent-side cancellation.
--
-- WHY
--   The cancellation penalty is UNIFORM regardless of reason (decided
--   2026-09-05). That removes any incentive to misreport the reason, but it
--   also means the enum no longer drives any money -- it is purely analytical.
--   The note is therefore the only real signal: it is what an admin reads when
--   deciding whether to waive, what surfaces a talent cancelling every third
--   booking, and what constitutes a written record if a safety_concern ever
--   becomes a dispute.
--
--   Talent side only. Client and venue keep the existing rule (note required
--   for client_other alone).

ALTER TABLE public.bookings
  DROP CONSTRAINT chk_cancellation_note_required_for_other;

-- Presence: required for all nine talent reasons, plus the two remaining
-- *_other values on the client and admin sides.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_note_required CHECK (
    cancellation_reason IS NULL
    OR cancellation_reason NOT IN (
         'illness_or_injury','family_emergency','double_booked',
         'transport_failure','equipment_failure','band_member_unavailable',
         'event_terms_changed','safety_concern','talent_other',
         'client_other','admin_other')
    OR (cancellation_note IS NOT NULL AND length(btrim(cancellation_note)) > 0)
  );

-- Length: short by design. Applies wherever a note is present, including the
-- optional client-side ones.
ALTER TABLE public.bookings
  ADD CONSTRAINT chk_cancellation_note_length CHECK (
    cancellation_note IS NULL OR length(btrim(cancellation_note)) <= 200
  );

-- Record the settled reading of event_terms_changed in the database itself,
-- so it survives this conversation.
COMMENT ON TYPE public.cancellation_reason IS
'Cancellation reasons. Penalty is UNIFORM across all values -- the reason is analytical, not pricing input.
NOTE ON event_terms_changed: a client CANNOT alter a booking in-system. bookings has no UPDATE policy for authenticated, and there is no amendment or change-request table. This value therefore means "the client asked for changes out-of-band (messages or off-platform) and we could not agree", NOT that the booking record changed. The booking row will still show the original terms, so cancellation_note is the only evidence. A proper amendment flow is v2.';

COMMENT ON COLUMN public.bookings.cancellation_note IS
'Short free-text detail. Mandatory for all talent-side reasons and for client_other/admin_other. Max 200 characters.';