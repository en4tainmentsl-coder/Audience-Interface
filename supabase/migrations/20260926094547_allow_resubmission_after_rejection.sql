-- A rejected talent must be able to fix their profile and resubmit: the
-- rejection email says there is no limit on resubmissions. The trust guard
-- allowed only draft -> pending_approval, so rejected -> pending_approval was
-- silently reverted; and chk_rejection_reason_presence requires the reason to
-- be NULL once the status leaves 'rejected', which a talent cannot do because
-- the reason is pinned. Both are handled here: the transition is permitted, and
-- resubmitting clears the previous rejection.
--
-- reviewed_at / reviewed_by are deliberately NOT cleared. They record who last
-- reviewed the profile, which stays true until someone reviews it again.

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
      NEW.pricing_updated_at    := NULL;
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
      NEW.pricing_updated_at := OLD.pricing_updated_at;
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