-- The extension owns the approve/reject transition (decided 2026-09-26).
-- Reason: approval was TWO uncoupled fields. approval_status = 'approved' does
-- not publish anyone; only profile_status = 'active' sets is_public, via
-- handle_talent_approval. An admin setting one dropdown and not the other
-- produced an approved-but-invisible or active-but-unapproved talent, silently.
-- One action now sets both, plus kyc_status, plus the reviewer trail, and
-- refuses to approve unless the reviewer actually opened both NIC images.

create type public.talent_rejection_reason as enum (
  'documents_unclear',
  'identity_mismatch',
  'incomplete_profile',
  'unsuitable_content',
  'duplicate_account',
  'other'
);

alter table public.profiles_talent
  add column if not exists rejection_reason public.talent_rejection_reason,
  add column if not exists rejection_note   text,
  add column if not exists reviewed_at      timestamptz,
  add column if not exists reviewed_by      uuid references public.profiles_users(id) on delete set null;

comment on column public.profiles_talent.rejection_reason is
  'Why the profile was rejected. Required when approval_status = rejected, forbidden otherwise. Shown to the talent in the rejection email.';
comment on column public.profiles_talent.rejection_note is
  'Free-text detail accompanying rejection_reason. Required when the reason is ''other'', since ''other'' alone tells the talent nothing.';

alter table public.profiles_talent
  add constraint chk_rejection_reason_presence check (
    (approval_status = 'rejected' and rejection_reason is not null)
    or (approval_status <> 'rejected' and rejection_reason is null)
  ),
  add constraint chk_rejection_other_needs_note check (
    rejection_reason is distinct from 'other'
    or (rejection_note is not null and btrim(rejection_note) <> '')
  );

-- Pin the new columns against the talent, exactly as deletion_requested_at is.
-- Without this a talent could write their own rejection_reason and reviewed_by.
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
      NEW.rejection_reason   := OLD.rejection_reason;
      NEW.rejection_note     := OLD.rejection_note;
      NEW.reviewed_at        := OLD.reviewed_at;
      NEW.reviewed_by        := OLD.reviewed_by;

      IF OLD.deletion_requested_at IS NOT NULL THEN
        NEW.deletion_requested_at := OLD.deletion_requested_at;
      ELSIF NEW.deletion_requested_at IS NOT NULL THEN
        NEW.deletion_requested_at := now();
        NEW.is_public             := false;
      END IF;

      IF NOT (OLD.approval_status = 'draft'
              AND NEW.approval_status = 'pending_approval'
              AND NEW.deletion_requested_at IS NULL) THEN
        NEW.approval_status := OLD.approval_status;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;