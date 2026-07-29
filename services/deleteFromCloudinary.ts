// ═══════════════════════════════════════════════════════════════════════════
// deleteFromCloudinary.ts  —  En4tainment / En410
// Deletes a PUBLIC Cloudinary asset and clears its reference in Supabase.
//
// Sensitive assets (KYC, venue documents) live in private R2 — delete those
// via the r2-delete Edge Function instead.
//
// Ownership is enforced server-side from the session JWT: a user can only
// delete their own assets, an admin can delete any.
//
// USAGE:
//   import { deleteFromCloudinary } from 'services/deleteFromCloudinary'
//
//   const result = await deleteFromCloudinary({
//     publicId:  'en410/avatars/abc123',
//     assetType: 'talent_avatar',
//   })
// ═══════════════════════════════════════════════════════════════════════════

import { supabase } from 'services/supabase.ts'
import type { AssetType } from 'services/uploadToCloudinary'

export interface DeleteOptions {
  publicId:  string
  assetType: AssetType
}

export interface DeleteResult {
  success: true
}

export interface DeleteError {
  success: false
  error:   string
}

export async function deleteFromCloudinary(
  options: DeleteOptions
): Promise<DeleteResult | DeleteError> {
  const { publicId, assetType } = options

  const { data, error } = await supabase.functions.invoke('cloudinary-delete', {
    body: {
      asset_type: assetType,
      public_id:  publicId,
    },
  })

  if (error || data?.error) {
    console.error('cloudinary-delete error:', error, data)
    return {
      success: false,
      error:   data?.error ?? error?.message ?? 'Failed to delete asset',
    }
  }

  return { success: true }
}