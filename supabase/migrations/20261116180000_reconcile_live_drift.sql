-- Reconcile the migration history with the live database.
-- Task 6hvJJhMfPrGxFmfX.
--
-- WHAT THIS IS
-- Every statement below describes a change that is ALREADY LIVE but was made
-- directly against production with no migration. Against production this file
-- is a no-op by construction: each statement is guarded so that it does
-- nothing where the target state already holds. Against a database rebuilt
-- from this history (CI, staging, a disaster-recovery rebuild) it is the
-- difference between a schema that matches production and one that does not.
--
-- HOW THE LIST WAS DERIVED -- verified 2026-11-16
-- Not by grepping CREATE POLICY / DROP POLICY, which is how the task's
-- original list was built. All 106 migrations were replayed into an empty
-- Postgres, and a catalog snapshot of the public schema (policies, RLS flags,
-- columns, constraints, indexes, triggers, function bodies and attributes,
-- function and table ACLs, column ACLs, views, enums, cron jobs: 1,438
-- objects) was compared row by row with the same snapshot taken from live.
--
-- That method changed the finding in both directions:
--
--   * quote_requests_owner_insert, quote_requests_owner_update and
--     users_insert_own are NOT drift. The history creates all three
--     (20260901160000, 20260911165534, 20260918235724). The grep missed them
--     because they are written unquoted and across several lines. A rebuild
--     DOES get an INSERT policy for quote requests and a self-insert for
--     profiles_users.
--   * fav_anon_insert is no longer drift. 20261101103311 drops it.
--   * Six differences the grep could not see are real, and one of them breaks
--     the booking flow on a rebuild. They are sections 2 to 6 below.
--
-- For every item the decision is the same and was the task's own expectation:
-- LIVE IS CORRECT, the history is what is wrong.
--
-- NOT FIXED HERE, because they are not differences in behaviour:
--   * 22 function bodies differ as text and not as code: 12 on live carry
--     CRLF line endings where the history has LF, 9 have had their comments
--     stripped, 1 differs in whitespace. Compared with comments and whitespace
--     removed, all 22 are identical.
--   * A rebuilt quote_requests has audience_capacity as its LAST column; on
--     live it sits between talent_rate_at_request and responds_by. Column
--     order is not something a forward migration can or should change.

-- ── 1. talent_favourites: the client-only policies were replaced live ───────
-- The baseline restricts favouriting and un-favouriting to role 'client'.
-- Live replaced both with policies open to any signed-in user acting on their
-- own row. D-053 already names fav_auth_insert as the policy in force.

drop policy if exists fav_client_insert on public.talent_favourites;
drop policy if exists rh_client_delete  on public.talent_favourites;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'talent_favourites'
                    and policyname = 'fav_auth_insert') then
    create policy fav_auth_insert on public.talent_favourites
      for insert to authenticated
      with check ((auth.uid() = user_id) and (app_source = 'en4tainment'::text));
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'talent_favourites'
                    and policyname = 'rh_auth_delete') then
    create policy rh_auth_delete on public.talent_favourites
      for delete to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;

-- ── 2. talent_favourites.user_id: NOT NULL, and the FK points at auth.users ─
-- Both follow from removing anonymous hearts on 2026-10-04: a favourite always
-- has an owner, and the owner is the signed-in account. The baseline still has
-- the column nullable and the FK pointing at profiles_users under its
-- pre-rename name.

do $$
begin
  if exists (select 1 from pg_constraint
              where conrelid = 'public.talent_favourites'::regclass
                and conname = 'Reviews_Heart_user_id_fkey') then
    alter table public.talent_favourites
      drop constraint "Reviews_Heart_user_id_fkey";
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.talent_favourites'::regclass
                    and conname = 'talent_favourites_user_id_fkey') then
    alter table public.talent_favourites
      add constraint talent_favourites_user_id_fkey
      foreign key (user_id) references auth.users (id) on delete cascade;
  end if;

  if exists (select 1 from pg_attribute
              where attrelid = 'public.talent_favourites'::regclass
                and attname = 'user_id' and not attnotnull) then
    alter table public.talent_favourites alter column user_id set not null;
  end if;
end $$;

-- ── 3. quote_requests.audience_capacity and its enum ───────────────────────
-- THE ONE THAT BREAKS A REBUILD. The column and the enum exist on live and in
-- no migration. RequestQuote.tsx writes audience_capacity on every quote
-- request, and enforce_quote_request_writes (20261018115132) reads
-- NEW.audience_capacity. On a database rebuilt from the history the insert
-- fails and no quote request can be created at all.
--
-- NOT NULL with no default, exactly as live. On a rebuild quote_requests is
-- empty at this point. If this ever runs somewhere that holds rows but lacks
-- the column it fails loudly, which is correct: a value cannot be invented.

do $$
begin
  if not exists (select 1 from pg_type t
                   join pg_namespace n on n.oid = t.typnamespace
                  where n.nspname = 'public' and t.typname = 'audience_capacity_band') then
    create type public.audience_capacity_band as enum
      ('under_100', '100_to_300', '301_to_750', '751_to_1500', 'over_1500');
  end if;
end $$;

alter table public.quote_requests
  add column if not exists audience_capacity public.audience_capacity_band not null;

-- ── 4. profiles_users: a client row must carry a date of birth ──────────────
-- Present and validated on live, in no migration. trg_check_client_age (in the
-- baseline) rejects a client under 18 but lets a NULL date of birth through;
-- this constraint is what closes that gap.

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.profiles_users'::regclass
                    and conname = 'chk_users_client_requires_dob') then
    alter table public.profiles_users
      add constraint chk_users_client_requires_dob
      check ((role <> 'client'::text) or (date_of_birth is not null));
  end if;
end $$;

-- ── 5. is_18_or_over is STABLE on live, IMMUTABLE in the baseline ───────────
-- Live is right. The body reads CURRENT_DATE, so the result changes from one
-- day to the next and the function must not be marked IMMUTABLE: the planner
-- is entitled to fold an immutable call into a constant.

alter function public.is_18_or_over(date) stable;

-- ── 6. nocobase_admin (Directus) holds narrower grants on live ──────────────
-- The baseline grants Directus write access to both append-only logs and the
-- TRIGGER privilege on profiles_talent. Live has SELECT only on the two logs
-- and no TRIGGER privilege. This role carries BYPASSRLS on production, so its
-- table grants are the only thing between the admin panel and these tables.
--
-- These are the three statements docs/corrections.md has carried since
-- 2026-08-29 as "exist ONLY in production", kept out of the history because
-- nocobase_admin did not exist in a fresh database. The baseline now creates
-- the role, so that reason has gone and they can be a migration.

revoke insert, update, delete on table public.audit_log                  from nocobase_admin;
revoke insert, update, delete on table public.sensitive_asset_access_log from nocobase_admin;
revoke trigger                on table public.profiles_talent            from nocobase_admin;
