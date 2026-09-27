-- 20260927081608_contact_submissions.sql
--
-- Stores public contact-form enquiries, and makes a failed notification visible.
--
-- WHY THIS EXISTS
-- ---------------
-- pages/Contact.tsx has been live on a public route with a handleSubmit that calls
-- setSubmitted(true) and nothing else. Every input is uncontrolled and unnamed, so
-- there was never any data to send. A visitor was told "Message Sent Successfully!"
-- and the message was discarded.
--
-- WHY A TABLE AND NOT JUST AN EMAIL (decided by Praveen 2026-09-27)
-- -----------------------------------------------------------------
-- Emailing straight from the form leaves no record when delivery fails, and Resend's
-- free tier caps at 100/day. The row is written first and the email second, so a
-- capped or failed send loses nothing. notify_error is the column that makes that
-- failure findable rather than silent:
--
--   select * from contact_submissions where notified_at is null and notify_error is not null;
--
-- NO BROWSER-REACHABLE WRITE PATH
-- -------------------------------
-- Rows arrive only through the `contact` Edge Function under service_role, which is
-- where validation, the honeypot and the per-IP rate limit live. Granting anon INSERT
-- would have put an unthrottled public write endpoint on a production table.
--
-- Supabase's default privileges grant anon and authenticated access to new tables in
-- public, and REVOKE FROM PUBLIC alone does not strip a role-specific grant, so the
-- revoke below names the roles explicitly. Verified after applying: the grant list for
-- this table contains no anon and no authenticated row.
--
-- service_role already holds ALL on new public tables by default, so the GRANT below
-- is documentation of intent rather than a privilege change. It neither adds nor
-- restricts anything.
--
-- PDPA
-- ----
-- Controller: REAP Holdings (Pvt) Ltd. Purpose: responding to the enquiry. Retention:
-- 6 months from created_at. submitter_ip is collected solely for abuse rate-limiting
-- and is personal data; it is purged with the row.
--
-- purge_contact_submissions() expresses the retention rule but NOTHING SCHEDULES IT.
-- pg_cron is not installed on this project. Retention is therefore defined and not yet
-- enforced, alongside the deletion deadline, booking auto-completion and the
-- abandoned-signup purge - all waiting on the same unsolved scheduling problem.
--
-- The form must not go public before a privacy notice exists to link it to.

begin;

create table public.contact_submissions (
  id            uuid primary key default gen_random_uuid(),
  first_name    text not null,
  last_name     text not null,
  email         text not null,
  message       text not null,
  submitter_ip  inet,
  user_agent    text,
  created_at    timestamptz not null default now(),
  notified_at   timestamptz,
  notify_error  text,
  handled_at    timestamptz,
  handled_by    uuid references public.profiles_users(id) on delete set null,

  constraint contact_first_name_len check (char_length(btrim(first_name)) between 1 and 100),
  constraint contact_last_name_len  check (char_length(btrim(last_name))  between 1 and 100),
  constraint contact_email_len      check (char_length(email) between 3 and 320),
  constraint contact_email_shape    check (email like '%_@_%'),
  constraint contact_message_len    check (char_length(btrim(message)) between 1 and 5000),
  constraint contact_user_agent_len check (user_agent is null or char_length(user_agent) <= 500),

  -- Both or neither. A row half-marked as handled is worse than one not marked at all.
  constraint contact_handled_pair   check (num_nonnulls(handled_at, handled_by) <> 1)
);

create index contact_submissions_created_idx
  on public.contact_submissions (created_at desc);

-- Serves the per-IP rate-limit lookup in the Edge Function.
create index contact_submissions_ip_created_idx
  on public.contact_submissions (submitter_ip, created_at desc)
  where submitter_ip is not null;

create index contact_submissions_unhandled_idx
  on public.contact_submissions (created_at desc)
  where handled_at is null;

alter table public.contact_submissions enable row level security;
alter table public.contact_submissions force row level security;

revoke all on public.contact_submissions from public, anon, authenticated;
grant select, insert, update on public.contact_submissions to service_role;

create policy contact_service_role_all on public.contact_submissions
  for all to service_role using (true) with check (true);

create or replace function public.purge_contact_submissions()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare n integer;
begin
  delete from public.contact_submissions
   where created_at < now() - interval '6 months';
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.purge_contact_submissions() from public, anon, authenticated;
grant execute on function public.purge_contact_submissions() to service_role;

comment on table public.contact_submissions is
  'Public contact-form enquiries. PDPA: controller REAP Holdings (Pvt) Ltd; purpose is responding to the enquiry; retention 6 months from created_at via purge_contact_submissions(). No anon or authenticated access - rows arrive only through the contact Edge Function under service_role.';

comment on column public.contact_submissions.submitter_ip is
  'Collected for abuse rate-limiting only. Personal data under PDPA; purged with the row at 6 months.';

comment on column public.contact_submissions.notify_error is
  'Set when the notification email failed. A row with notified_at NULL and notify_error set is an enquiry nobody has been told about - this is the column that makes a silent delivery failure visible.';

commit;