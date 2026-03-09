import type { SystemCatalogItem } from '@/lib/types'

/**
 * Calculate estimated price based on system catalog item.
 */
export function calculatePrice(
  system: SystemCatalogItem,
  quantity: number = 1
): number {
  if (!system.unit_price) return 0
  return system.unit_price * quantity
}
