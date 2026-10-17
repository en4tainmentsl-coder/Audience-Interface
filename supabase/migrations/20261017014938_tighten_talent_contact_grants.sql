-- talent_contact inherited the full default-privilege set for `authenticated`
-- at CREATE TABLE, so the explicit grant in 20261017014530 added nothing and
-- the table shipped with TRUNCATE, TRIGGER, REFERENCES and DELETE as well.
-- TRUNCATE is the one that matters: it is not subject to row level security,
-- so no policy on this table can restrain it.
--
-- Rows are removed by the ON DELETE CASCADE from profiles_talent, and by
-- service_role during PDPA erasure, so `authenticated` needs no DELETE either.

revoke truncate, trigger, references, delete
  on public.talent_contact from authenticated;
