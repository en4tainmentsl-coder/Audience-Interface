-- 20260928073952_pg_cron_scheduled_retention.sql
--
-- Installs pg_cron and schedules the retention rules that were, until now,
-- expressed but never enforced.
--
-- WHAT THIS DOES AND DOES NOT CLOSE
-- ---------------------------------
-- purge_contact_submissions() (6 months, D-045) and purge_email_deliveries()
-- (12 months, D-048) both existed as functions with nothing calling them. They
-- now run nightly.
--
-- The PDPA deletion deadline, booking auto-completion and the abandoned-signup
-- purge are NOT closed by this. Those were missing the function as well as the
-- scheduler - there is nothing to call. Installing pg_cron makes them cheap to
-- finish; it does not finish them.
--
-- THE FAILURE MODE THIS GUARDS AGAINST
-- ------------------------------------
-- A pg_cron job that fails writes a row to cron.job_run_details and notifies
-- nobody. That is the same shape as every silent failure this project has
-- produced: notified_at set on a bounced email, a migration ledger quietly
-- disagreeing with the repo, a trust guard returning 200 while changing nothing.
--
-- Scheduling a purge that errors nightly and reports nowhere would add a sixth.
-- So scheduled_job_health exists to be looked at:
--
--   select * from public.scheduled_job_health;
--
-- last_success carrying a recent date means the schedule is alive. NULL means it
-- never ran, which is the case that would otherwise be invisible.
--
-- A third job prunes cron.job_run_details, which grows without limit. A run log
-- nobody prunes becomes a run log nobody reads. 30 days is long enough to
-- investigate a failure.
--
-- TIMES ARE UTC. 19:30, 19:45 and 20:00 are 01:00, 01:15 and 01:30 in Colombo.
--
-- cron.schedule upserts by job name, so re-running this migration re-registers
-- the same three jobs rather than duplicating them.
--
-- VERIFIED AFTER APPLYING: all three jobs registered and active, running as
-- postgres against the postgres database; both purge functions execute cleanly
-- and correctly purge nothing, the existing rows being well inside their
-- windows. Whether pg_cron actually fires them cannot be known until the first
-- scheduled run - scheduled_job_health is how to check.

begin;

create extension if not exists pg_cron;

-- The cron schema must never be reachable by a browser role. Supabase's default
-- privileges are generous with new schemas, so name the roles explicitly - the
-- same reason every table in this schema carries an explicit revoke.
revoke all on schema cron from public, anon, authenticated;
revoke all on all tables in schema cron from public, anon, authenticated;

select cron.schedule(
  'purge-contact-submissions',
  '30 19 * * *',
  $$select public.purge_contact_submissions();$$
);

select cron.schedule(
  'purge-email-deliveries',
  '45 19 * * *',
  $$select public.purge_email_deliveries();$$
);

select cron.schedule(
  'prune-cron-history',
  '0 20 * * *',
  $$delete from cron.job_run_details where end_time < now() - interval '30 days';$$
);

create or replace view public.scheduled_job_health as
select j.jobname,
       j.schedule,
       j.active,
       max(d.end_time) filter (where d.status = 'succeeded') as last_success,
       max(d.end_time) filter (where d.status <> 'succeeded') as last_failure,
       count(*) filter (where d.status <> 'succeeded'
                          and d.start_time > now() - interval '7 days') as failures_7d,
       (select r.return_message
          from cron.job_run_details r
         where r.jobid = j.jobid and r.status <> 'succeeded'
         order by r.start_time desc limit 1) as last_failure_message
from cron.job j
left join cron.job_run_details d on d.jobid = j.jobid
group by j.jobid, j.jobname, j.schedule, j.active;

revoke all on public.scheduled_job_health from public, anon, authenticated;

comment on view public.scheduled_job_health is
  'Whether the scheduled retention jobs are actually running. A pg_cron job that fails writes a row to cron.job_run_details and notifies nobody; this is the query that surfaces it. Check last_failure and failures_7d.';

commit;