// ═══════════════════════════════════════════════════════════════════════════
// uploadToR2.ts  —  En4tainment / En410
// Uploads SENSITIVE assets to the private Cloudflare R2 bucket.
//
// Scope: kyc_front, kyc_back, venue_document.
// Public assets (avatars, covers, portfolio) go via uploadToCloudinary.
//
// FLOW:
//   1. r2-sign-upload  → presigned PUT URL + object key
//   2. PUT direct to R2
//   3. process-upload  → persist metadata in Supabase
//
// There is deliberately NO mock fallback. A silent fake success on an
// identity document is worse than a visible error.
// ═══════════════════════════════════════════════════════════════════════════

import { supabase } from 'services/supabase.ts'

// ── Types ────────────────────────────────────────────────────────────────

export type R2AssetType = 'kyc_front' | 'kyc_back' | 'venue_document'

export interface R2UploadOptions {
  file:        File
  assetType:   R2AssetType
  talentId?:   string   // profiles_talent.id — required for kyc_*
  venueId?:    string   // profiles_venues.id — required for venue_document
  onProgress?: (pct: number) => void
}

export interface R2UploadResult {
  success:        boolean
  objectKey?:     string
  storageBucket?: string
  error?:         string
  stage?:         'validate' | 'sign' | 'upload' | 'save'
}

// ── Client-side guards (first checkpoint, not the last) ──────────────────

const ALLOWED_MIME = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]

const MAX_BYTES: Record<R2AssetType, number> = {
  kyc_front:      8  * 1024 * 1024,
  kyc_back:       8  * 1024 * 1024,
  venue_document: 15 * 1024 * 1024,
}

// ── PUT with progress ────────────────────────────────────────────────────

function putWithProgress(
  url: string,
  file: File,
  contentType: string,
  onProgress?: (pct: number) => void,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('PUT', url, true)

    // Must match the Content-Type signed by r2-sign-upload, or R2
    // rejects with SignatureDoesNotMatch.
    xhr.setRequestHeader('Content-Type', contentType)

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress?.((e.loaded / e.total) * 100)
    }
    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? resolve()
        : reject(new Error(`R2 responded ${xhr.status}: ${xhr.responseText}`))
    xhr.onerror = () => reject(new Error('Network error during upload'))
    xhr.ontimeout = () => reject(new Error('Upload timed out'))

    xhr.timeout = 120_000
    xhr.send(file)
  })
}

// ── Main ─────────────────────────────────────────────────────────────────

export async function uploadToR2(
  opts: R2UploadOptions,
): Promise<R2UploadResult> {
  const { file, assetType, talentId, venueId, onProgress } = opts

  // ── 0. Validate locally ────────────────────────────────────────────────
  if (!ALLOWED_MIME.includes(file.type)) {
    return {
      success: false,
      error:   'Please upload a JPG, PNG, WEBP or PDF file.',
      stage:   'validate',
    }
  }

  if (file.size > MAX_BYTES[assetType]) {
    const mb = Math.round(MAX_BYTES[assetType] / 1048576)
    return {
      success: false,
      error:   `File is too large. Maximum size is ${mb}MB.`,
      stage:   'validate',
    }
  }

  if (assetType === 'venue_document' && !venueId) {
    return { success: false, error: 'venueId is required', stage: 'validate' }
  }
  if (assetType !== 'venue_document' && !talentId) {
    return { success: false, error: 'talentId is required', stage: 'validate' }
  }

  // ── 1. Sign ────────────────────────────────────────────────────────────
  onProgress?.(5)

  const { data: signData, error: signError } = await supabase.functions.invoke(
    'r2-sign-upload',
    {
      body: {
        asset_type:        assetType,
        content_type:      file.type,
        size_bytes:        file.size,
        talent_id:         talentId,
        related_entity_id: venueId,
        file_name:         file.name,
      },
    },
  )

  if (signError || !signData?.upload_url) {
    console.error('r2-sign-upload failed:', signError, signData)
    return {
      success: false,
      error:   signData?.error ?? signError?.message ?? 'Could not authorise upload',
      stage:   'sign',
    }
  }

  // ── 2. Direct PUT to R2 ────────────────────────────────────────────────
  try {
    await putWithProgress(
      signData.upload_url,
      file,
      signData.content_type,
      (p) => onProgress?.(5 + Math.round(p * 0.8)),
    )
  } catch (err) {
    console.error('R2 upload error:', err)
    return { success: false, error: 'Upload failed. Please try again.', stage: 'upload' }
  }

  onProgress?.(85)

  // ── 3. Persist metadata ────────────────────────────────────────────────
  const { data: saveData, error: saveError } = await supabase.functions.invoke(
    'process-upload',
    {
      body: {
        asset_type:        assetType,
        public_id:         signData.object_key,
        storage_bucket:    signData.storage_bucket,
        content_type:      file.type,
        bytes:             file.size,
        file_name:         file.name,
        related_entity_id: venueId,
      },
    },
  )

  if (saveError || saveData?.error) {
    console.error('process-upload failed:', saveError, saveData)
    return {
      success: false,
      error:   saveData?.error ?? saveError?.message ?? 'Failed to save upload',
      stage:   'save',
    }
  }

  onProgress?.(100)

  return {
    success:       true,
    objectKey:     signData.object_key,
    storageBucket: signData.storage_bucket,
  }
}