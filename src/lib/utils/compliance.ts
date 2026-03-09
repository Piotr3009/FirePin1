import type { ComplianceStatus, Marker } from '@/lib/types'

export function checkCompliance(marker: Marker): ComplianceStatus {
  const hasAfterPhoto = marker.photos?.some(p => p.photo_type === 'after')
  const hasSystem = !!marker.system_reference && !!marker.manufacturer
  const hasRating = !!marker.fire_rating
  const hasInstaller = !!marker.assigned_to

  if (marker.status === 'approved') {
    if (!hasAfterPhoto || !hasSystem || !hasRating || !hasInstaller) return 'non_compliant'
    return 'compliant'
  }

  if (!hasSystem || !hasRating || !hasInstaller) return 'incomplete'
  if (hasAfterPhoto && hasSystem && hasRating && hasInstaller) return 'compliant'
  return 'incomplete'
}
