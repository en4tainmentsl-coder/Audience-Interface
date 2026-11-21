-- profiles_talent.short_bio: enforce the 200-character cap at the database.
--
-- Why: the frontend already enforces 200 characters at three layers --
--   ProfileEditor.tsx:123  zod .max(200, 'Short bio should be 200 characters or fewer')
--   ProfileEditor.tsx:894  maxLength={200} on the textarea
--   ProfileEditor.tsx:900  live counter reading {length}/200
-- but nothing stops a write that bypasses ProfileEditor -- Directus admin edits,
-- a direct PostgREST call, or a future import. short_bio is the description shown
-- on artist cards (Home, Artists, ArtistDetail), so an overlong value breaks layout
-- on the client-facing site.
--
-- 200 CHARACTERS, not 200 words. The 3 Oct meeting note says words; Praveen settled
-- this as characters on 2026-10-21. 200 words would be roughly 1,200 characters --
-- six times what the card design and the existing UI allow.
--
-- Safe: verified 2026-10-21 that profiles_talent holds 3 rows, max short_bio length
-- is 57, and no row exceeds 200. The constraint validates without a backfill.
--
-- NULL passes by design: short_bio is nullable and a CHECK is satisfied by NULL.
-- A minimum length is deliberately NOT included -- zod enforces min(20) at submit,
-- and a database minimum would reject an administrator clearing the field to ''.

ALTER TABLE public.profiles_talent
  ADD CONSTRAINT chk_short_bio_max_200
  CHECK (char_length(short_bio) <= 200);

-- Post-condition: the constraint must exist AND be validated, not merely declared.
DO $$
DECLARE
  ok boolean;
BEGIN
  SELECT convalidated INTO ok
  FROM pg_constraint
  WHERE conrelid = 'public.profiles_talent'::regclass
    AND conname  = 'chk_short_bio_max_200';

  IF ok IS NULL THEN
    RAISE EXCEPTION 'chk_short_bio_max_200 was not created';
  ELSIF NOT ok THEN
    RAISE EXCEPTION 'chk_short_bio_max_200 exists but is NOT VALID';
  END IF;
END
$$;