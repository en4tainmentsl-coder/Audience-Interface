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

Take a snapshot of a database rebuilt from the history, and one of live, with
the same query:

```
psql "$REBUILT_DB_URL" -At -c "copy ($(sed '$d' supabase/drift/snapshot.sql | grep -v '^--') select k, key, val from s) to stdout with (format csv)" > rebuilt.csv
```

```
psql "$LIVE_DB_URL" -At -c "copy ($(sed '$d' supabase/drift/snapshot.sql | grep -v '^--') select k, key, val from s) to stdout with (format csv)" > live.csv
```

```
python3 supabase/drift/compare.py rebuilt.csv live.csv
```

The rebuilt database is whatever `supabase db start` produces: it applies every
migration to an empty Postgres.

## What it does not cover

Only the `public` schema. Not `auth`, `storage`, `vault` or `cron` internals,
not role attributes (`nocobase_admin` has `BYPASSRLS` and a password on
production and deliberately neither in the baseline), not Realtime publication
membership, not object comments, and not column order.

## Status

Run by hand on 2026-11-16. **Not wired into CI.** Doing that needs a read-only
database credential for production stored as a repository secret, which is a
decision that has not been taken.
