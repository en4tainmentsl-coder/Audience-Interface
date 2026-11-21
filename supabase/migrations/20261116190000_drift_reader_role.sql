-- A read-only role for the scheduled schema drift check.
-- Task 6hvJJhMfPrGxFmfX, step 5. Decided by Praveen 2026-11-16: the comparison
-- between a database rebuilt from this history and production runs in CI.
--
-- WHAT THE ROLE CAN DO
-- Read the system catalogs, which every role can, and nothing else. It is
-- granted no privilege on any table, view, sequence or function, and none is
-- needed: supabase/drift/snapshot.sql reads only pg_catalog. It cannot read a
-- single row of application data. Every transaction it opens is read-only by
-- default, and it may hold two connections at most.
--
-- WHAT IS DELIBERATELY NOT HERE
-- LOGIN and the password. Created NOLOGIN, exactly as the baseline creates
-- nocobase_admin, and for the same reason: a password in a committed
-- migration is a credential in source control. On production, enable it out
-- of band:
--
--   alter role drift_reader login password '<generated>';
--
-- and store the connection string as the repository secret DRIFT_DB_URL.
-- Role attributes are cluster-level and outside what the drift check
-- compares, so setting them by hand creates no drift.
--
-- KNOWN LIMIT
-- cron.job is protected by a row-level policy (username = CURRENT_USER) and
-- the cron schema grants USAGE to postgres only, so this role cannot see the
-- scheduled jobs. The CI comparison leaves cron jobs out. A comparison run by
-- hand as postgres still covers them.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'drift_reader') then
    create role drift_reader nologin connection limit 2;
  end if;
end $$;

alter role drift_reader set default_transaction_read_only = on;
alter role drift_reader set statement_timeout = '30s';
