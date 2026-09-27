-- 20260927162423_events_type_add_club_pub_and_spot_performance.sql
--
-- Adds the two event types the eight-category rate model needs (D-038).
-- 'concert' already existed; these were the only two missing.
--
-- WHY THIS IS ITS OWN MIGRATION
-- -----------------------------
-- Postgres allows ALTER TYPE ... ADD VALUE inside a transaction from 12 onward,
-- but the new value CANNOT BE USED until that transaction commits. So anything
-- referencing 'club_pub' or 'spot_performance' - the rate_category mapping, a
-- CHECK, a seed - has to be a separate migration.
--
-- This fails in a way worth knowing about: applied one statement at a time here
-- it looks fine, and it breaks on `db push` against a fresh database, where the
-- whole file runs as one transaction.
--
-- Appended rather than positioned. Enum sort order is display order in some
-- clients, but reordering an enum means recreating the type, and nothing in the
-- schema depends on these sorting anywhere in particular.

begin;

alter type public.events_type add value if not exists 'club_pub';
alter type public.events_type add value if not exists 'spot_performance';

commit;