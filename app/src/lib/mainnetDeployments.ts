import { getAddress, isAddress } from 'viem'
import mainnetTxt from '../../contracts/deployments/mainnet.txt?raw'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const

export type MainnetDeploymentAddresses = {
  registry: `0x${string}`
  factory: `0x${string}`
  chamberImplementation: `0x${string}`
}

const EMPTY_MAINNET: MainnetDeploymentAddresses = {
  registry: ZERO_ADDRESS,
  factory: ZERO_ADDRESS,
  chamberImplementation: ZERO_ADDRESS,
}

const LINE_PARSERS: Array<{ key: keyof MainnetDeploymentAddresses; re: RegExp }> = [
  { key: 'registry', re: /^Registry \(proxy\)\s+(0x[a-fA-F0-9]{40})\s*$/i },
  { key: 'factory', re: /^Factory\s+(0x[a-fA-F0-9]{40})\s*$/i },
  { key: 'chamberImplementation', re: /^Chamber implementation\s+(0x[a-fA-F0-9]{40})\s*$/i },
]

function parseAddress(raw: string): `0x${string}` | undefined {
  if (!isAddress(raw)) return undefined
  return getAddress(raw)
}

/**
 * Last matching label in `contracts/deployments/mainnet.txt` wins.
 * TBD / missing / non-address values stay zero. Live LORE / NFT / Safe
 * lines are not Factory or Chamber and are ignored here.
 */
export function parseMainnetDeploymentAddresses(text: string): MainnetDeploymentAddresses {
  const out: MainnetDeploymentAddresses = { ...EMPTY_MAINNET }
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed) continue
    for (const { key, re } of LINE_PARSERS) {
      const match = trimmed.match(re)
      if (!match?.[1]) continue
      const addr = parseAddress(match[1])
      if (addr) out[key] = addr
    }
  }
  return out
}

/**
 * Committed mainnet Factory / impl / Registry from `mainnet.txt`.
 * The template ships with TBD — `getContractAddresses(1)` stays empty
 * until a human pastes a verified chain-id-1 receipt. Never copy Sepolia.
 */
export const mainnetDeploymentAddresses = parseMainnetDeploymentAddresses(mainnetTxt)
