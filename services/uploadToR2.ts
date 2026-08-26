// ═══════════════════════════════════════════════════════════════════════════
// uploadToR2.ts  —  En4tainment / En410
// Uploads SENSITIVE assets (KYC images, venue documents) to the private
// Cloudflare R2 bucket.
//
// Scope: kyc_front, kyc_back, venue_document.
// Public assets (avatars, covers, portfolio) go via uploadToCloudinary.
//
// CHANGED: this now posts the file to `upload-document`, a single shared
// Edge Function used by both Talent_Interface and Audience-Interface. It
// receives the bytes, inspects them, and writes to R2 itself.
//
// The previous flow used `r2-sign-upload` (presigned PUT), which has been
// deleted. It could only pin the *declared* Content-Type header — a modified
// client could declare application/pdf and send anything — and it accepted
// a client-supplied talent_id/related_entity_id with no ownership check.
// Both problems are gone here: ownership is resolved from the JWT, and for
// venue_document the caller must actually own the named venue.
//
// There is deliberately NO mock fallback. A silent fake success on an
// identity document is worse than a visible error.
// ═══════════════════════════════════════════════════════════════════════════

import { supabase } from './supabase'

// ── Types ────────────────────────────────────────────────────────────────

export type R2AssetType = 'kyc_front' | 'kyc_back' | 'venue_document'

export interface R2UploadOptions {
  file:        File
  assetType:   R2AssetType
  venueId?:    string   // profiles_venues.id — required for venue_document
  onProgress?: (pct: number) => void
}

export interface R2UploadResult {
  success:        boolean
  objectKey?:     string
  storageBucket?: string
  kycStatus?:     string
  error?:         string
  stage?:         'validate' | 'upload'
}

// ── Client-side guards (first checkpoint, not the last — the server         ──
// re-checks both against the actual received bytes, and its answer is the
// one that counts) ──────────────────────────────────────────────────────

const ALLOWED_MIME = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]

// Must match MAX_BYTES in upload-document. That function enforces one cap
// for every asset_type it accepts — the old 8MB/15MB split no longer applies.
const MAX_BYTES = 2 * 1024 * 1024 // 2 MiB

// ── Main ─────────────────────────────────────────────────────────────────

export async function uploadToR2(
  opts: R2UploadOptions,
): Promise<R2UploadResult> {
  const { file, assetType, venueId, onProgress } = opts

  // ── 0. Validate locally ────────────────────────────────────────────────
  if (!ALLOWED_MIME.includes(file.type)) {
    return {
      success: false,
      error:   'Please upload a JPG, PNG, WEBP or PDF file.',
      stage:   'validate',
    }
  }

  if (file.size > MAX_BYTES) {
    return {
      success: false,
      error:   'File is too large. Maximum size is 2MB.',
      stage:   'validate',
    }
  }

  if (assetType === 'venue_document' && !venueId) {
    return { success: false, error: 'venueId is required', stage: 'validate' }
  }

  // ── 1. Single call: auth, ownership, size, content inspection, R2 write, ──
  // DB row. No talent_id or arbitrary related_entity_id is trusted from the
  // client for kyc_front/kyc_back — the talent is resolved from the JWT.
  // For venue_document, related_entity_id is checked against profiles_venues
  // ownership server-side before anything is written.
  onProgress?.(10)

  const form = new FormData()
  form.append('asset_type', assetType)
  form.append('file', file)
  form.append('file_name', file.name)
  if (assetType === 'venue_document' && venueId) {
    form.append('related_entity_id', venueId)
  }

  const { data, error } = await supabase.functions.invoke('upload-document', {
    body: form,
  })

  if (error || data?.error) {
    console.error('upload-document failed:', error, data)
    return {
      success: false,
      error:   data?.error ?? error?.message ?? 'Upload failed. Please try again.',
      stage:   'upload',
    }
  }

  onProgress?.(100)

  return {
    success:       true,
    objectKey:     data?.object_key,
    storageBucket: data?.storage_bucket,
    kycStatus:     data?.kyc_status,
  }
}
