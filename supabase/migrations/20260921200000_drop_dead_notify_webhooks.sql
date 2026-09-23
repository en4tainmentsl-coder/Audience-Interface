-- 20260921200000_drop_dead_notify_webhooks.sql
--
-- Makes the repo match the database: the approval webhook functions are already gone
-- from production, but nothing in the repo records that.
--
-- WHY THIS EXISTS
-- ---------------
-- notify_talent_approved() and notify_profile_approved() fired when a profile became
-- public and active - i.e. on approval - and POSTed talent identifiers and stage names,
-- signed with a Vault secret, to a Railway subdomain that no longer resolved to a known
-- host. Todoist 6hJhMXvVvH4rV795.
--
-- Verified live 2026-09-21: neither function nor its trigger exists any more, and no
-- user-defined function anywhere references 'railway' or calls net.http_post (only
-- pg_net's own system functions do). Someone dropped them outside the migration set.
--
-- THE PROBLEM THAT LEAVES
-- -----------------------
-- If the functions were originally created by a migration in this repo, replaying the
-- migration set onto a fresh database RECREATES them - including the POST to an
-- unidentified host. Production is clean; a rebuild would not be. Replayability is
-- already listed as unproven in the staging deferral (6h979FccqVC5pfPX).
--
-- This migration is therefore a no-op against production and a real fix for any
-- future replay. IF EXISTS throughout, so it is safe either way.
--
-- CASCADE drops any trigger still bound to these functions. Verified 2026-09-21 that
-- none exists, so CASCADE has nothing to remove here - it is protection for the replay
-- case, where the trigger WOULD exist at this point in the sequence.
--
-- STILL OUTSTANDING, not doable in SQL: rotate `webhook_secret` in Supabase Vault.
-- It was used to sign payloads sent to a host nobody controls, so treat it as
-- disclosed. Tracked in 6hJhMXvVvH4rV795.

BEGIN;

DROP FUNCTION IF EXISTS public.notify_talent_approved() CASCADE;
DROP FUNCTION IF EXISTS public.notify_profile_approved() CASCADE;

COMMIT;
