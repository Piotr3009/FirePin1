import type { SystemCatalogItem, PricingMethod } from '@/lib/types'

/**
 * FirePin pricing engine.
 *
 * Ported and improved from the Codex prototype. Unlike that version (which
 * treated unit_price as price-per-mm²), the area and linear models here use
 * real-world units: £ per m² and £ per linear metre.
 *
 * Every calculation returns a human-readable `basis` string which the app
 * stores in markers.price_calculation_json, so a price can always be explained
 * on the report and in audits.
 */

export interface PriceInput {
  method: PricingMethod
  unitPrice?: number | null
  basePrice?: number | null
  includedAreaMm2?: number | null
  includedLengthMm?: number | null
  overageUnitPrice?: number | null
  widthMm?: number | null
  heightMm?: number | null
  diameterMm?: number | null
  quantity?: number | null
  /** Used only by manual_override (admin-entered price). */
  manualPrice?: number | null
}

export interface PriceResult {
  method: PricingMethod
  /** Net price in GBP, rounded to pence. */
  net: number
  /** Plain-English explanation of how the price was derived. */
  basis: string
}

const round2 = (n: number): number => Math.round(n * 100) / 100

export function calculatePrice(input: PriceInput): PriceResult {
  const unitPrice = input.unitPrice ?? 0

  switch (input.method) {
    case 'per_unit':
      return {
        method: input.method,
        net: round2(unitPrice),
        basis: `Flat £${unitPrice.toFixed(2)} per pin`,
      }

    case 'quantity_based': {
      const qty = input.quantity ?? 1
      return {
        method: input.method,
        net: round2(qty * unitPrice),
        basis: `${qty} × £${unitPrice.toFixed(2)}`,
      }
    }

    case 'per_m2': {
      const w = input.widthMm ?? 0
      const h = input.heightMm ?? 0
      const m2 = (w * h) / 1_000_000
      return {
        method: input.method,
        net: round2(m2 * unitPrice),
        basis: `${w}×${h} mm = ${m2.toFixed(4)} m² × £${unitPrice.toFixed(2)}/m²`,
      }
    }

    case 'per_metre': {
      const mm = input.diameterMm ?? Math.max(input.widthMm ?? 0, input.heightMm ?? 0)
      const m = mm / 1000
      return {
        method: input.method,
        net: round2(m * unitPrice),
        basis: `${mm} mm = ${m.toFixed(3)} m × £${unitPrice.toFixed(2)}/m`,
      }
    }

    case 'base_plus_overage': {
      const base = input.basePrice ?? 0
      const area = (input.widthMm ?? 0) * (input.heightMm ?? 0)
      const included = input.includedAreaMm2 ?? 0
      const over = Math.max(0, area - included)
      const overPrice = input.overageUnitPrice ?? 0
      return {
        method: input.method,
        net: round2(base + over * overPrice),
        basis: `£${base.toFixed(2)} base + ${over} mm² over × £${overPrice.toFixed(2)}/mm²`,
      }
    }

    case 'manual_override':
      return {
        method: input.method,
        net: round2(input.manualPrice ?? 0),
        basis: 'Manual price entered by admin',
      }

    default:
      return { method: input.method, net: 0, basis: 'Unknown pricing method' }
  }
}

/**
 * Convenience wrapper: price a marker straight from its chosen catalog system
 * plus the marker's dimensions/quantity.
 */
export function priceForMarker(
  system: Pick<
    SystemCatalogItem,
    | 'pricing_method'
    | 'unit_price'
    | 'base_price'
    | 'included_area_mm2'
    | 'included_length_mm'
    | 'overage_unit_price'
  >,
  dims: {
    widthMm?: number | null
    heightMm?: number | null
    diameterMm?: number | null
    quantity?: number | null
    manualPrice?: number | null
  }
): PriceResult {
  return calculatePrice({
    method: system.pricing_method,
    unitPrice: system.unit_price,
    basePrice: system.base_price,
    includedAreaMm2: system.included_area_mm2,
    includedLengthMm: system.included_length_mm,
    overageUnitPrice: system.overage_unit_price,
    widthMm: dims.widthMm,
    heightMm: dims.heightMm,
    diameterMm: dims.diameterMm,
    quantity: dims.quantity,
    manualPrice: dims.manualPrice,
  })
}
