import type { SystemCatalogItem, ServiceType, BarrierType } from '@/lib/types'

/**
 * System matching.
 *
 * Given an opening (barrier type, service type, dimensions, fire rating),
 * return the catalog systems that fit, so the form can suggest the right
 * fire-stopping system instead of making the admin hunt through the catalog.
 *
 * A missing dimension never excludes a system (we only filter on what we know).
 */

export interface MatchCriteria {
  barrierType?: BarrierType | null
  serviceType?: ServiceType | null
  widthMm?: number | null
  heightMm?: number | null
  diameterMm?: number | null
  fireRating?: number | null
}

function within(
  value: number | null | undefined,
  min: number | null | undefined,
  max: number | null | undefined
): boolean {
  if (value == null) return true // dimension not provided -> don't filter on it
  if (min != null && value < min) return false
  if (max != null && value > max) return false
  return true
}

function fitsDimensions(system: SystemCatalogItem, c: MatchCriteria): boolean {
  return (
    within(c.widthMm, system.min_width_mm, system.max_width_mm) &&
    within(c.heightMm, system.min_height_mm, system.max_height_mm) &&
    within(c.diameterMm, system.min_diameter_mm, system.max_diameter_mm)
  )
}

/** How specific the match is — higher means more criteria actually matched. */
function matchScore(system: SystemCatalogItem, c: MatchCriteria): number {
  let score = 0
  if (c.barrierType && system.barrier_type === c.barrierType) score += 2
  if (c.serviceType && system.service_type === c.serviceType) score += 2
  if (c.fireRating && system.fire_rating_options.includes(c.fireRating)) score += 1
  if (c.widthMm != null && (system.min_width_mm != null || system.max_width_mm != null)) score += 1
  if (c.diameterMm != null && (system.min_diameter_mm != null || system.max_diameter_mm != null)) score += 1
  return score
}

/**
 * Returns active systems that fit the criteria, best (most specific) match first.
 */
export function matchSystems(
  catalog: SystemCatalogItem[],
  c: MatchCriteria
): SystemCatalogItem[] {
  return catalog
    .filter((s) => s.is_active !== false)
    .filter((s) => !c.barrierType || s.barrier_type === c.barrierType)
    .filter((s) => !c.serviceType || s.service_type === c.serviceType)
    .filter((s) => !c.fireRating || s.fire_rating_options.includes(c.fireRating))
    .filter((s) => fitsDimensions(s, c))
    .sort((a, b) => matchScore(b, c) - matchScore(a, c))
}
