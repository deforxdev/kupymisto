export const START_PASS_BONUS = 100
export const CASINO_OUTCOMES = [-150, -100, -50, 50, 100, 150] as const
export const DEFAULT_ROUND_LIMIT = 30

export function houseCost(existingHouses: number): number {
  return 100 + Math.max(existingHouses, 0) * 50
}

export function propertyRent(price: number, houses: number): number {
  return Math.max(Math.floor(price / 3) + Math.max(houses, 0) * 50, 25)
}
