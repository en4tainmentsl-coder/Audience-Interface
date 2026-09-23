-- 20260921210300_require_18_before_submission.sql
--
-- A talent must be at least 18 to submit a profile for approval.
--
-- WHY
-- ---
-- Nothing enforced an age anywhere. check_talent_dob_before_submission required only
-- that date_of_birth was NOT NULL, and the only other rule, profiles_talent_dob_sane,
-- accepts any date between 1900-01-01 and today. A talent born in 2015 would have
-- passed both.
--
-- The talent form had no date-of-birth field at all, so the column was NULL for every
-- talent and nobody could reach submission to discover it. Found 2026-09-21 on the
-- first profile ever to satisfy the completeness gate. Todoist 6h979J6cCrpr6wGX
-- ("Enforce hard 18+ age gate") described this and sat at P2 while being both
-- unenforced and a hard blocker.
--
-- The matching form field ships alongside this in Talent_Interface. A form check alone
-- would be advisory - PostgREST is reachable directly with any signed-in session - so
-- the rule belongs here, where it cannot be bypassed.
--
-- WHEN IT FIRES
-- -------------
-- Only on a transition into 'pending_approval' or 'approved', like the existing
-- checks. A draft profile may hold any sane date, or none: a talent can start filling
-- in a profile before this matters, and is stopped at submission.
--
-- Someone whose eighteenth birthday is today passes: the test is
-- date_of_birth > CURRENT_DATE - INTERVAL '18 years', so exactly 18 years is allowed.
--
-- NOT DONE HERE
--   * Client and venue signup. The task covers those too; they have no equivalent
--     submission step, so the gate has to sit elsewhere in that flow.
--   * Backfilling existing rows. All three talent have date_of_birth NULL and none is
--     approved, so there is nothing to correct.
--   * Anything about verifying the date against the NIC. This is a self-declared date;
--     KYC review is where a document actually confirms it.

BEGIN;

CREATE OR REPLACE FUNCTION public.check_talent_dob_before_submission()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  transitioning boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    transitioning := true;
  ELSE
    transitioning := NEW.approval_status IS DISTINCT FROM OLD.approval_status;
  END IF;

  IF NOT (transitioning
          AND NEW.approval_status IN ('pending_approval', 'approved')) THEN
    RETURN NEW;
  END IF;

  IF NEW.date_of_birth IS NULL THEN
    RAISE EXCEPTION 'Date of birth is required before a talent profile can be submitted for approval.'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.date_of_birth > (CURRENT_DATE - INTERVAL '18 years') THEN
    RAISE EXCEPTION 'You must be at least 18 years old to submit a talent profile for approval.'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

COMMIT;

-- No trigger changes: CREATE OR REPLACE FUNCTION keeps the existing binding
-- (trg_require_talent_dob).
