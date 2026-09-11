/** Sepolia (11155111). Same Factory as `getContractAddresses` / verify-sepolia-discovery. */
export const SEPOLIA_CHAIN_ID = 11155111
export const SEPOLIA_FACTORY = '0x43aA92c8A26392f21F63cdA88B6BaB5031C40550' as const

/**
 * Known Sepolia chamber from Factory / leftover Registry discovery
 * (`app/scripts/verify-sepolia-discovery.ts`). Override with PLAYWRIGHT_SEPOLIA_CHAMBER.
 */
export const KNOWN_SEPOLIA_CHAMBER = '0x0ad3205ecfa76cdb52be5ebe099b990c35489888' as const

export const DEFAULT_BASE_URL = 'https://app.loreum.org'

export function sepoliaPrivateKey(): string | undefined {
  const raw = (process.env.E2E_SEPOLIA_PRIVATE_KEY || process.env.SEPOLIA_PRIVATE_KEY || '').trim()
  return raw || undefined
}

/** Normalize to 0x-prefixed 32-byte hex. Never include the key in thrown messages. */
export function normalizePrivateKey(raw: string): string {
  const hex = raw.startsWith('0x') || raw.startsWith('0X') ? raw.slice(2) : raw
  if (!/^[0-9a-fA-F]{64}$/.test(hex)) {
    throw new Error('E2E_SEPOLIA_PRIVATE_KEY / SEPOLIA_PRIVATE_KEY must be a 32-byte hex private key')
  }
  return `0x${hex}`
}

export function targetChamberAddress(): string {
  const override = process.env.PLAYWRIGHT_SEPOLIA_CHAMBER?.trim()
  if (override) {
    if (!/^0x[a-fA-F0-9]{40}$/.test(override)) {
      throw new Error('PLAYWRIGHT_SEPOLIA_CHAMBER must be a 20-byte 0x address')
    }
    return override
  }
  return KNOWN_SEPOLIA_CHAMBER
}
