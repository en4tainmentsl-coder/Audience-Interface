# Schema drift check

Answers one question: **does the migration history rebuild the live schema?**

The backup and the weekly restore test prove the data comes back. They do not
prove that a database built from `supabase/migrations/` is the same database
as production. Before 2026-11-16 nothing checked that, and it was not true —
see "The migration history did not rebuild the live schema" in
[`docs/corrections.md`](../../docs/corrections.md).

## What is here

- `snapshot.sql` — one read-only query. Emits a row per object in the `public`
  schema: policies, RLS flags, columns, constraints, indexes, triggers,
  functions, function and table grants, column grants, views, enums and cron
  jobs.
- `compare.py` — compares two snapshots. Exits 1 on any difference in
  behaviour.

## How to run it

**It runs by itself.** `.github/workflows/schema-drift.yml` runs every day at
07:47 Colombo time and can be started by hand from the Actions tab. It
rebuilds a database from the history, takes the same snapshot from production
as the read-only role `drift_reader`, and fails on any difference in
behaviour.

A failure means one of two things:

- **Something was changed on production without a migration.** Write the
  migration that describes it, guarded so it is a no-op against production.
- **A migration was merged and `supabase db push` has not been run.** Run it.

It is deliberately not a pull-request check: a PR that adds a migration is
ahead of production until it is pushed, so it would fail every time.

To run the comparison by hand, with `psql` and two connection strings:

```
psql "$REBUILT_DB_URL" --csv -t -f supabase/drift/snapshot.sql > rebuilt.csv
```

```
psql "$LIVE_DB_URL" --csv -t -f supabase/drift/snapshot.sql > live.csv
```

```
python3 supabase/drift/compare.py rebuilt.csv live.csv
```

## One-time setup on production

The role is created by `20261116190000_drift_reader_role` with no login and no
password. Enable it once, in the Supabase SQL editor, with a generated
password:

```sql
alter role drift_reader login password '<generated>';
```

Then add the repository secret `DRIFT_DB_URL` (Settings, Secrets and
variables, Actions). GitHub's runners have no IPv6, so it must be the session
pooler address, and the pooler wants the project ref in the username:

```
postgresql://drift_reader.sqovyodycuyajmumcjnn:<password>@aws-1-ap-south-1.pooler.supabase.com:5432/postgres
```

The role has no privilege on any table and cannot read application data. It
reads the system catalogs, which every role can.

## Reading a green run

A passing run still prints two things, and both are expected:

- **22 functions "differ in text only".** Line endings, stripped comments and
  whitespace. The code is the same.
- **3 constraints "differ only in parentheses".** The coordinate CHECKs on
  `profiles_talent`, `profiles_venues` and `quote_requests`. Same meaning,
  stored one level flatter on a rebuild. Not a Postgres version difference.

If either number changes, read the list.

## What it does not cover

Only the `public` schema. Not `auth`, `storage`, `vault` or `cron` internals,
not role attributes (`nocobase_admin` has `BYPASSRLS` and a password on
production and deliberately neither in the baseline), not Realtime publication
membership, not object comments, and not column order.

The scheduled run also leaves out cron jobs: `cron.job` is hidden from
`drift_reader` by a row-level policy. A run by hand as `postgres` covers them.

## Status

Run by hand on 2026-11-16, with no difference in behaviour. Scheduled in CI
from the same day, by Praveen's decision.
