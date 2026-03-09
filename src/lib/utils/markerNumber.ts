/**
 * Generate the next marker number for a project.
 * Format: P-001, P-002, etc.
 */
export function generateMarkerNumber(existingNumbers: string[]): string {
  if (existingNumbers.length === 0) return 'P-001'

  const maxNum = existingNumbers.reduce((max, num) => {
    const match = num.match(/P-(\d+)/)
    if (match) {
      const n = parseInt(match[1], 10)
      return n > max ? n : max
    }
    return max
  }, 0)

  return `P-${String(maxNum + 1).padStart(3, '0')}`
}
