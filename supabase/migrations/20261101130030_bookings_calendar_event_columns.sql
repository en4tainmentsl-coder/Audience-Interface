-- Give bookings somewhere to record the Google Calendar event they created.
-- Task 6hpJg4VVQmqGpHgX item 5.
--
-- BookingManager.tsx:100 writes google_calendar_event_link to a column that has
-- never existed. The Google event is created successfully; the write-back then
-- fails as a silent PostgREST error. Verified live 2026-11-01: zero columns
-- matching %calendar% or %gcal% anywhere in public.
--
-- Consequences being fixed:
--   * the "Open in Calendar" links can never render -- the field is never set
--   * deleteCalendarEvent cannot work -- deletion needs the event ID, which was
--     stored nowhere. Storing only the link is what made deletion impossible.
--
-- calendar_id is stored deliberately, decided by Praveen 2026-11-01. Events are
-- written to the talent's "primary" calendar, but a talent can change which
-- calendar is primary, or move the event. Deleting against the wrong calendar
-- 404s silently, so the calendar is recorded rather than assumed.
--
-- All three are nullable: sync is optional, and existing bookings have no event.

alter table public.bookings
  add column if not exists google_calendar_event_id   text,
  add column if not exists google_calendar_event_link text,
  add column if not exists google_calendar_id         text;

comment on column public.bookings.google_calendar_event_id is
  'Google Calendar event id, needed to update or delete the event. Null when no event has been created.';

comment on column public.bookings.google_calendar_event_link is
  'Google Calendar htmlLink, used for the "Open in Calendar" affordance. Null when no event has been created.';

comment on column public.bookings.google_calendar_id is
  'The calendar the event was written to, normally "primary". Recorded so deletion targets the right calendar rather than assuming.';
