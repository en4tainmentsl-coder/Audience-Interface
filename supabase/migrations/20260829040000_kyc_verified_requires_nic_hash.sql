-- A talent cannot be marked KYC-verified without a NIC hash on file.
--
-- upload-document (NIC images) and submit-nic (the hashed number) are
-- independent paths with nothing joining them. The NIC number field is
-- optional in ProfileEditor, so a talent can upload both images and never
-- submit a number -- which is the state the only live talent row is in.
--
-- Without this, a reviewer sees two valid NIC images and approves, and
-- ban-evasion prevention is silently absent for that talent forever.
-- nic_last_four is included because submit-nic always writes both, so a
-- row with one and not the other indicates a partial write.

ALTER TABLE public.talent_identity
  ADD CONSTRAINT talent_identity_verified_requires_hash
  CHECK (
    kyc_status <> 'verified'
    OR (nic_hash IS NOT NULL AND nic_last_four IS NOT NULL)
  );

SELECT 1;
