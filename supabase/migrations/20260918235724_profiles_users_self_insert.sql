-- profiles_users: allow a signed-in user to create their own row, and make phone optional.
--
-- Why: no app path could create a profiles_users row. There was no INSERT policy
-- for authenticated and no trigger on auth.users, so a new Google OAuth user got no
-- row at all, and the venue signup insert (VenuePortal.tsx) failed on RLS every time.
--
-- Decided 2026-09-19:
--   * The app inserts the row on first sign-in (not a trigger on auth.users), because
--     OAuth cannot carry a trustworthy role.
--   * The role chosen at first insert is final for non-admins.
--     a_enforce_user_trust_fields already blocks self-assigned 'admin' on INSERT and
--     pins role to OLD on UPDATE; this policy repeats the admin exclusion as a
--     second layer.
--   * phone becomes nullable. Google sign-in supplies no phone. Each role supplies
--     one when completing its own profile (talent: profiles_talent.mobile). The
--     NOT NULL never guaranteed a verified number, since no OTP provider exists yet.

ALTER TABLE public.profiles_users
  ALTER COLUMN phone DROP NOT NULL;

DROP POLICY IF EXISTS users_insert_own ON public.profiles_users;

CREATE POLICY users_insert_own
  ON public.profiles_users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id
    AND role IN ('talent', 'client', 'venue')
    AND status = 'active'
  );