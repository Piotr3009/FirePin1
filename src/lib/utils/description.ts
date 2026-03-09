import type { Marker } from '@/lib/types'

/**
 * Auto-generate description text from marker data.
 * User never types this manually.
 */
export function generateDescription(marker: Partial<Marker>): string {
  const parts: string[] = []

  if (marker.service_type === 'pipe') {
    parts.push(
      `There was a ${marker.opening_size || ''} ${marker.wall_material || ''} pipe penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`
    )
  } else if (marker.service_type === 'cable') {
    parts.push(
      `There were cables penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`
    )
  } else if (marker.service_type === 'duct') {
    parts.push(
      `There was a ${marker.opening_size || ''} duct penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`
    )
  } else if (marker.service_type) {
    parts.push(
      `There was a ${marker.service_type} service penetrating a ${marker.fire_rating || ''} minute fire rated ${marker.barrier_type || ''}.`
    )
  }

  if (marker.wall_thickness) {
    parts.push(`The wall thickness is ${marker.wall_thickness}.`)
  }

  if (marker.system_reference && marker.manufacturer) {
    parts.push(`CE marked ${marker.manufacturer} materials have been used.`)
    parts.push(
      `The installed apparatus is therefore in accordance with ${marker.manufacturer}'s approved and tested detail no. ${marker.system_reference}, and restores the appropriate fire rating to the compartment.`
    )
  }

  return parts.join(' ')
}
