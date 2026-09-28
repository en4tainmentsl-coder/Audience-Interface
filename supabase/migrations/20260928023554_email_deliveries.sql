-- 20260928023554_email_deliveries.sql
--
-- Records whether an email was actually DELIVERED. Nothing previously did.
--
-- WHY
-- ---
-- On 2026-09-27 a contact-form test stored its row, called send-email, got a
-- 2xx from Resend, set notified_at and left notify_error NULL - every signal
-- the platform had said success - and the message bounced. info@en4tainment.com
-- had no Cloudflare routing rule and had never been able to receive mail.
--
-- The two test rows were INDISTINGUISHABLE in contact_submissions. Both showed
-- notified_at set and notify_error NULL; one arrived and one did not.
--
-- This is not a contact-form problem. send-email logs the Resend message ID to
-- console and discards it, so NO email the platform sends can be traced to an
-- outcome - not talent approvals, not rejections, not the deletion alert that
-- starts the 14-day PDPA erasure clock. That bounce was caught only because
-- someone happened to be watching.
--
-- SHAPE
-- -----
-- One row per send, keyed by the Resend message ID, so contact_submissions gains
-- the truth by joining rather than by duplicating it. A webhook reaching into
-- one feature's table is coupling that gets forgotten by the next feature that
-- sends mail.
--
-- template and recipient are NULLABLE because a webhook event can arrive before
-- send-email has written its row. Both sides upsert; whichever lands first
-- creates it. Do not add NOT NULL here without solving that race.
--
-- WHAT IS DELIBERATELY NOT STORED
-- -------------------------------
-- Resend also emits opened and clicked. Those are behavioural tracking of talent
-- and clients, they answer no operational question, and they would make this
-- table considerably more sensitive under PDPA. Delivery is the question.
--
-- PDPA
-- ----
-- recipient is personal data. Retention 12 months - longer than the contact
-- form's 6, because a bounce log is operational and a domain failing quietly
-- takes time to spot. purge_email_deliveries() expresses it and NOTHING
-- SCHEDULES IT; pg_cron is still not installed, so this joins the deletion
-- deadline, booking auto-completion, the abandoned-signup purge and
-- purge_contact_submissions() on the same unsolved problem.
--
-- NOT PUBLICLY READABLE
-- ---------------------
-- No anon or authenticated grant - this is a log of who was emailed and when.
-- Verified after applying.

begin;

create table public.email_deliveries (
  resend_id      text primary key,
  template       text,
  recipient      text,
  sent_at        timestamptz,
  delivered_at   timestamptz,
  delayed_at     timestamptz,
  bounced_at     timestamptz,
  complained_at  timestamptz,
  bounce_type    text,
  bounce_reason  text,
  last_event_at  timestamptz not null default now(),
  created_at     timestamptz not null default now(),

  constraint email_deliveries_id_len      check (char_length(resend_id) between 1 and 200),
  constraint email_deliveries_template_len check (template is null or char_length(template) <= 100),
  constraint email_deliveries_recipient_len check (recipient is null or char_length(recipient) <= 320),
  constraint email_deliveries_bounce_type_len check (bounce_type is null or char_length(bounce_type) <= 100),
  constraint email_deliveries_bounce_reason_len check (bounce_reason is null or char_length(bounce_reason) <= 2000),
  constraint email_deliveries_bounce_pair check (bounce_reason is null or bounced_at is not null)
);

create index email_deliveries_bounced_idx
  on public.email_deliveries (bounced_at desc) where bounced_at is not null;

-- "Sent, and nothing came back." The query that would have caught the info@
-- bounce without anyone watching.
create index email_deliveries_undelivered_idx
  on public.email_deliveries (sent_at desc)
  where delivered_at is null and bounced_at is null;

create index email_deliveries_template_idx
  on public.email_deliveries (template, sent_at desc);

create index email_deliveries_recipient_idx
  on public.email_deliveries (recipient, sent_at desc) where recipient is not null;

alter table public.email_deliveries enable row level security;
alter table public.email_deliveries force row level security;

revoke all on public.email_deliveries from public, anon, authenticated;

create policy email_deliveries_service on public.email_deliveries
  for all to service_role using (true) with check (true);

create or replace function public.purge_email_deliveries()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare n integer;
begin
  delete from public.email_deliveries
   where created_at < now() - interval '12 months';
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.purge_email_deliveries() from public, anon, authenticated;
grant execute on function public.purge_email_deliveries() to service_role;

comment on table public.email_deliveries is
  'One row per email the platform sends, keyed by the Resend message ID. Records DELIVERY OUTCOME, which nothing previously did: a 2xx from Resend means accepted, not received, so a bounced message and a delivered one were indistinguishable everywhere. template and recipient are nullable because a webhook event can arrive before send-email has written its row - both sides upsert and whichever lands first creates it. Open and click events are deliberately NOT stored: they are behavioural tracking of talent and clients, they answer no operational question, and they would make this table considerably more sensitive. PDPA: recipient is personal data; retention 12 months via purge_email_deliveries(), which nothing schedules.';

comment on column public.email_deliveries.bounce_reason is
  'The receiving server reason, verbatim. This is what distinguishes a missing routing rule from an SPF failure from a full mailbox - three different fixes that look identical without it.';

commit;