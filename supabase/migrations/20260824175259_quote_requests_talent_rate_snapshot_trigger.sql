-- 20260824175259_quote_requests_talent_rate_snapshot_trigger.sql
--
-- APPLIED TO PRODUCTION 2026-08-24 via MCP apply_migration.
-- Already recorded in supabase_migrations.schema_migrations under version
-- 20260824175259. This file is the version-controlled definition of that
-- change; the filename timestamp deliberately matches the recorded version so
-- the two records reconcile.
--
-- WHY
-- quote_requests.talent_rate_at_request is a price snapshot taken when a client
-- requests a quote. It had no trigger populating it, which left two problems:
--
--   1. The value could only arrive from the browser. A client-supplied price on
--      a row that later drives a quote is the same class of bug as trusting a
--      browser-reported payment amount.
--   2. quote_requests_client_manage is FOR ALL to authenticated (scoped to
--      auth.uid() = client_user_id). That grants UPDATE on every column, so
--      even a correct insert-time value could be rewritten afterwards.
--
-- Hence BEFORE INSERT OR UPDATE, not BEFORE INSERT.
--
-- VERIFIED (rolled-back probe, 2026-08-24), talent rate 45000:
--   insert omitting the column      -> 45000.00  (populated from profiles_talent)
--   insert spoofing the value as 1  -> 45000.00  (browser value discarded)
--   update setting the value to 1   -> 45000.00  (refused)
--   talent raises rate to 99000     -> 45000.00  (in-flight request immune)
--
-- NOTES
-- - SET search_path = 'public' is required (see the 13 functions pinned in
--   20260822120000). No unqualified extension calls here, so 'public' alone is
--   correct; do NOT blanket-copy this to functions calling hmac(), which lives
--   in the extensions schema.
-- - profiles_talent has relforcerowsecurity = false, so the SECURITY DEFINER
--   owner reads it without RLS interference. Re-check if that ever changes.
-- - The REVOKE names PUBLIC explicitly. Revoking only from named roles leaves
--   the PUBLIC grant intact and silently defeats the intent.
-- - Trigger functions fire regardless of EXECUTE privilege, so the revoke closes
--   the RPC surface without disabling the trigger.

create or replace function public.set_talent_rate_at_request()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  if TG_OP = 'INSERT' then
    select pt.pricing_per_session
      into new.talent_rate_at_request
      from public.profiles_talent pt
     where pt.id = new.talent_id;
  else
    -- Immutable after creation. Protects in-flight requests from later rate
    -- changes, and stops the client rewriting it through the FOR ALL policy.
    new.talent_rate_at_request := old.talent_rate_at_request;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_quote_requests_rate_snapshot on public.quote_requests;

create trigger trg_quote_requests_rate_snapshot
before insert or update on public.quote_requests
for each row
execute function public.set_talent_rate_at_request();

revoke execute on function public.set_talent_rate_at_request()
  from public, anon, authenticated;
