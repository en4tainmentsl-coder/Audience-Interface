-- talent_identity: drop the dead nic_front_url / nic_back_url pair.
--
-- Residue from the pre-R2 design, when NIC images were expected to have public URLs.
-- R2 is private, so these must stay NULL -- `r2-deliver` issues a 120s presigned URL
-- per view instead, logged to sensitive_asset_access_log. The live completeness gate
-- uses nic_front_public_id / nic_back_public_id.
--
-- Why remove rather than ignore: left in place they surface in any admin UI as two
-- permanently empty "NIC Front URL" fields beside the real documents. At best confusing;
-- at worst an invitation to paste a URL into one, which would mean a publicly reachable
-- identity document with no sensitive_asset_access_log row -- exactly the exposure
-- r2-deliver exists to prevent.
--
-- Verified 2026-10-21 before writing, per the standing check in 6hmmq9XgpC7fGcw5:
--   * pg_proc.prosrc across ALL schemas: the only match is a COMMENT at line 59 of
--     check_talent_completeness_before_submission. Zero code references.
--   * pg_views definitions: no matches.
--   * constraints and indexes on talent_identity: no matches.
--   * data: 3 rows, both columns NULL in every row.
--   * application code, both repos, correct paths: only type declarations --
--     Talent_Interface/src/supabase.ts:48-49 and the generated database.types.ts files.
--
-- Column count drops 17 -> 15. That number is the DDL canary used while configuring
-- the Directus KYC collection.

ALTER TABLE public.talent_identity
  DROP COLUMN nic_front_url,
  DROP COLUMN nic_back_url;

-- Post-condition: both columns gone, the rest of the table untouched.
DO $$
DECLARE
  n_cols int;
  n_dead int;
BEGIN
  SELECT count(*) INTO n_cols FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'talent_identity';

  SELECT count(*) INTO n_dead FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'talent_identity'
     AND column_name IN ('nic_front_url', 'nic_back_url');

  IF n_dead > 0 THEN
    RAISE EXCEPTION 'drop incomplete: % legacy NIC url column(s) remain', n_dead;
  ELSIF n_cols <> 15 THEN
    RAISE EXCEPTION 'talent_identity has % columns, expected 15 -- schema drifted since this migration was written', n_cols;
  END IF;
END
$$;