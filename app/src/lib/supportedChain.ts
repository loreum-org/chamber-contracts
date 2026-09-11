/** Sepolia — preferred when a Factory or Registry is already configured. */
export const SEPOLIA_CHAIN_ID = 11_155_111

/** Display name for wallet/config banners. Does not invent chain metadata. */
export function getNetworkName(chainId: number, configuredName?: string): string {
  switch (chainId) {
    case 1:
      return 'Mainnet'
    case SEPOLIA_CHAIN_ID:
      return 'Sepolia'
    case 8453:
      return 'Base'
    case 42161:
      return 'Arbitrum'
    case 31337:
      return 'Localhost'
    default:
      return configuredName ?? `Chain ${chainId}`
  }
}

/**
 * Prefer Sepolia when it is in the configured-and-supported list, otherwise the
 * first entry. Callers must pass only chains that already have a Factory or
 * Registry — this does not invent addresses.
 */
export function pickPreferredSupportedChainId(
  configuredSupportedIds: readonly number[],
  prefer: number = SEPOLIA_CHAIN_ID,
): number | undefined {
  if (configuredSupportedIds.includes(prefer)) return prefer
  return configuredSupportedIds[0]
}

export function showMainnetUnsupportedBanner(
  chainId: number,
  mainnetConfigured: boolean,
): boolean {
  return chainId === 1 && !mainnetConfigured
}

export function switchToSupportedChainLabel(chainId: number | undefined): string {
  return chainId == null ? 'Switch network' : `Switch to ${getNetworkName(chainId)}`
}

/** DEV-only `?simulateChainId=1` so the mainnet banner can be exercised without a mainnet wallet. */
export function readSimulatedChainId(search: string, enabled: boolean): number | undefined {
  if (!enabled) return undefined
  const raw = new URLSearchParams(search.startsWith('?') ? search : `?${search}`).get('simulateChainId')
  if (!raw) return undefined
  const id = Number(raw)
  return Number.isInteger(id) && id > 0 ? id : undefined
}
