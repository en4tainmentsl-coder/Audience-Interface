-- 20260824180000_drop_railway_talent_approval_webhook.sql
--
-- APPLIED TO PRODUCTION 2026-08-24 by hand via the Supabase SQL Editor.
-- NOT recorded in supabase_migrations.schema_migrations. This file is the only
-- version-controlled record of the change.
--
-- WHY
-- notify_talent_approved() POSTed talent identifiers and stage names, HMAC-signed
-- with the Vault webhook_secret, to a hardcoded Railway URL:
--
--   https://en4-webhook-service-production.up.railway.app/webhook/talent-approved
--
-- Railway was decommissioned when the free trial ended and the webhook service
-- moved to the VPS. That subdomain resolves to 69.46.46.27, which is NOT the VPS
-- (104.168.62.20) and is not under our control. up.railway.app is Railway-managed
-- DNS, so the hostname cannot be repointed. The consuming Edge Function
-- (talent-approved) was deleted 2026-08-15, so nothing consumed it either.
--
-- net.http_post is fire-and-forget, so every failure since decommissioning was
-- silent.
--
-- EXPOSURE ASSESSMENT (verified 2026-08-24, and smaller than first feared)
-- The trigger fired only on the transition into
-- (is_public = true AND profile_status = 'active'). At the time of removal:
--   - zero talent rows were in that state
--   - only one talent row existed at all
--   - net._http_response and net.http_request_queue were both empty
-- pg_net prunes its response log, so the empty log is weak evidence alone; the
-- absence of any ever-published talent is the stronger signal. Conclusion: this
-- most likely never fired with real data. webhook_secret rotation is therefore
-- hygiene rather than incident response, but remains advisable.
--
-- notify_profile_approved() is dropped in the same change. It was an ORPHAN --
-- no trigger referenced it, so it could never fire. It also had a URL with no
-- scheme ('en4-webhook-service-production.up.railway.app'), which net.http_post
-- rejects, and passed a text body where jsonb was expected. It was broken from
-- the day it was written and never worked.
--
-- KEPT DELIBERATELY
-- vault secret 'webhook_secret' and public.get_webhook_secret() are retained for
-- the VPS webhook path. Contrary to earlier project notes, get_webhook_secret()
-- was never deleted -- it was REVOKEd. Verified ACL is
-- {postgres=X/postgres, service_role=X/postgres}: no PUBLIC, anon or
-- authenticated grant. That is correct; leave it.
--
-- VERIFIED AFTER APPLYING
--   dead functions remaining ................ 0
--   talent_approval_webhook trigger ......... 0
--   trigger functions mentioning 'railway' .. 0
--   legitimate triggers on profiles_talent .. 6 (age, DOB, pricing cooldown,
--                                                featured guard, approval handler)

drop trigger if exists talent_approval_webhook on public.profiles_talent;

drop function if exists public.notify_talent_approved();

drop function if exists public.notify_profile_approved();
