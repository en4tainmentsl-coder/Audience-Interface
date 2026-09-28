-- 20260928091608_restore_enforce_talent_trust_fields.sql
--
-- Repairs damage introduced by 20260928031427. Read this before trusting any
-- "verified after applying" note in that migration's header.
--
-- WHAT WENT WRONG
-- ---------------
-- 20260928031427 needed to remove TWO LINES from enforce_talent_trust_fields,
-- the ones referencing pricing_updated_at, because that column was being
-- dropped. Instead of a surgical edit it replaced the whole function body,
-- written from assumption after grepping only the two matching lines. The
-- original was never read in full.
--
-- The rewrite:
--
--   INVENTED columns that do not exist on profiles_talent - total_bookings,
--   is_featured, approved_at, approved_by. This broke EVERY non-admin update to
--   a talent profile with "record new has no field total_bookings", and is the
--   only reason any of this was noticed.
--
--   SILENTLY DROPPED the guards on is_public, profile_status, rating,
--   reviewed_at, reviewed_by and deletion_requested_at. A talent could have set
--   their own is_public, their own profile_status, their own rating.
--
--   REMOVED the deletion-request path entirely, including the rule that a
--   profile with deletion_requested_at set cannot walk back into the review
--   queue.
--
--   REVERTED PR #129 - the resubmission-after-rejection logic that clears
--   rejection_reason and rejection_note, which a constraint requires.
--
--   CHANGED the outer condition. The original skips the guard when auth.uid()
--   is NULL, so service_role writes pass through; the rewrite applied it.
--
-- Had the invented column names happened to be real, all of the above would
-- have shipped silently under a header claiming verification. The checks run
-- after that migration were about the dropped columns - none touched the
-- function that had been rewritten.
--
-- THE FIX
-- -------
-- This restores the body from 20260926094547 verbatim, with only the two
-- pricing_updated_at lines removed - which is what 20260928031427 should have
-- done.
--
-- WHAT GENERALISES
-- ----------------
-- Rewriting a function to change two lines means re-deriving every line you did
-- not intend to change. Read the whole definition first, or edit surgically.
-- And a verification note is only worth what it actually checked: "verified
-- after applying" listed the dropped columns and said nothing about the
-- function body, while reading as though the whole migration had been proven.
--
-- VERIFIED AFTER APPLYING, on the function body specifically: no reference to
-- total_bookings, is_featured or pricing_updated_at; guards present for
-- is_public, profile_status, deletion_requested_at and reviewed_by; the PR #129
-- resubmission comment and logic restored.

begin;

create or replace function public.enforce_talent_trust_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  IF auth.uid() IS NOT NULL AND get_my_role() IS DISTINCT FROM 'admin' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.is_verified           := false;
      NEW.is_public             := false;
      NEW.profile_status        := 'pending'::talent_status;
      NEW.rating                := 0.00;
      NEW.deletion_requested_at := NULL;
      NEW.rejection_reason      := NULL;
      NEW.rejection_note        := NULL;
      NEW.reviewed_at           := NULL;
      NEW.reviewed_by           := NULL;
      IF NEW.approval_status NOT IN ('draft', 'pending_approval') THEN
        NEW.approval_status := 'draft'::approval_status;
      END IF;
    ELSE
      NEW.is_verified        := OLD.is_verified;
      NEW.is_public          := OLD.is_public;
      NEW.profile_status     := OLD.profile_status;
      NEW.rating             := OLD.rating;
      NEW.reviewed_at        := OLD.reviewed_at;
      NEW.reviewed_by        := OLD.reviewed_by;
      NEW.rejection_reason   := OLD.rejection_reason;
      NEW.rejection_note     := OLD.rejection_note;

      IF OLD.deletion_requested_at IS NOT NULL THEN
        NEW.deletion_requested_at := OLD.deletion_requested_at;
      ELSIF NEW.deletion_requested_at IS NOT NULL THEN
        NEW.deletion_requested_at := now();
        NEW.is_public             := false;
      END IF;

      -- The talent may submit for review from draft, or resubmit after a
      -- rejection. Barred once deletion has been requested, so a profile on its
      -- way out cannot walk back into the review queue.
      IF OLD.approval_status IN ('draft', 'rejected')
         AND NEW.approval_status = 'pending_approval'
         AND NEW.deletion_requested_at IS NULL THEN
        -- Resubmission clears the previous rejection; the constraint requires it.
        NEW.rejection_reason := NULL;
        NEW.rejection_note   := NULL;
      ELSE
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

commit;