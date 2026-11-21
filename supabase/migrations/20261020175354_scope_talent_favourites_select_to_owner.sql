-- talent_favourites: remove world-readable SELECT, scope reads to the owning client.
--
-- The problem:
--   policy rh_select_public granted SELECT to PUBLIC with USING (true), so the entire
--   table -- including user_id and the client's private `notes` -- was readable by
--   anyone holding the anon key, signed in or not.
--
--   The `rh_` prefix dates the policy to the talent_hearts -> talent_favourites rename.
--   The matching anon INSERT policy was deliberately dropped 2026-10-04; this read
--   policy was left behind. It reads as an oversight from the anon-heart era rather
--   than a decision.
--
-- Safe: verified 2026-10-20 that talent_favourites holds 0 rows and that neither
-- Audience-Interface nor Talent_Interface queries the table. HeartRating.tsx is a
-- stub returning null and is imported nowhere.
--
-- Not covered here: whether a talent may see heart COUNTS for their own profile.
-- That is still open (see the hearts/stars task) and should be served by a
-- SECURITY DEFINER aggregate, not by widening this policy.

DROP POLICY IF EXISTS rh_select_public ON public.talent_favourites;

CREATE POLICY fav_owner_select
  ON public.talent_favourites
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Post-condition. Fails the migration rather than leaving a rebuilt database open.
DO $$
DECLARE
  n_open int;
BEGIN
  SELECT count(*) INTO n_open
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename  = 'talent_favourites'
    AND cmd IN ('SELECT', 'ALL')
    AND (roles::text LIKE '%public%' OR roles::text LIKE '%anon%');

  IF n_open > 0 THEN
    RAISE EXCEPTION
      'talent_favourites still has % SELECT-capable policy/policies granted to public or anon',
      n_open;
  END IF;
END
$$;