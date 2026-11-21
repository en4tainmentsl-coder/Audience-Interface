-- talent_favourites.app_source: fix the default's casing so it is actually usable.
--
-- The problem:
--   DEFAULT  'En4tainment'::text                                   -- capital E
--   CHECK    app_source = ANY (ARRAY['en4tainment','en410'])       -- lowercase only
--
-- The column is NOT NULL, so there is no escape: any INSERT that omits app_source
-- takes the default and is then rejected by the CHECK. The default has never been
-- usable.
--
-- Why nothing has broken: every current insert path passes the value explicitly.
-- Policy fav_auth_insert requires app_source = 'en4tainment' in its WITH CHECK, and
-- all four Audience-Interface insert sites (ArtistCard, FlexArtistCard, ArtistDetail,
-- ClientDashboard) pass the literal. So this is a latent trap rather than a live
-- outage -- the next insert path that trusts the default fails, with an error naming
-- the CHECK rather than the default.
--
-- Default remains the website rather than En410, matching fav_auth_insert. An En410
-- insert path would need its own policy and would pass its value explicitly anyway.
--
-- Verified 2026-10-21: talent_favourites holds 0 rows, so no backfill is required and
-- no existing value needs correcting.

ALTER TABLE public.talent_favourites
  ALTER COLUMN app_source SET DEFAULT 'en4tainment';

-- Post-condition: the default must now satisfy the CHECK, not merely differ from before.
DO $$
DECLARE
  d text;
BEGIN
  SELECT column_default INTO d
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'talent_favourites'
    AND column_name  = 'app_source';

  IF d IS NULL THEN
    RAISE EXCEPTION 'app_source has no default after the change';
  ELSIF btrim(split_part(d, '::', 1), '''') NOT IN ('en4tainment', 'en410') THEN
    RAISE EXCEPTION 'app_source default % does not satisfy the app_source CHECK', d;
  END IF;
END
$$;