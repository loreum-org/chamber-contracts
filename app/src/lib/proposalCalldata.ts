/**
 * Calldata archive for Chamber proposals.
 * Ordinary txs store keccak256(calldata) only; L-04 also persists full bytes
 * for self-calls (`getTransactionCalldata`). Fallbacks: localStorage,
 * metadata URI, SubmitTransaction logs.
 */

import {
  decodeFunctionData,
  erc20Abi,
  formatUnits,
  keccak256,
  parseAbiItem,
  type Hex,
  type PublicClient,
} from 'viem'
import { chamberAbi } from '@/contracts/abis'

const STORAGE_PREFIX = 'chamber-proposal-calldata'

const SUBMIT_TX_EVENT = parseAbiItem(
  'event SubmitTransaction(uint256 indexed tokenId, uint256 indexed nonce, address indexed to, uint256 value, bytes data)',
)

function storageKey(chamberAddress: string, txId: number): string {
  return `${STORAGE_PREFIX}-${chamberAddress.toLowerCase()}-${txId}`
}

export function getStoredProposalCalldata(
  chamberAddress: string,
  txId: number,
): `0x${string}` | null {
  try {
    const raw = localStorage.getItem(storageKey(chamberAddress, txId))
    if (!raw) return null
    const normalized = raw.startsWith('0x') ? raw : `0x${raw}`
    return normalized as `0x${string}`
  } catch {
    return null
  }
}

export function setStoredProposalCalldata(
  chamberAddress: string,
  txId: number,
  calldata: `0x${string}`,
): void {
  localStorage.setItem(storageKey(chamberAddress, txId), calldata)
}

export function proposalCalldataMatchesHash(
  calldata: `0x${string}`,
  dataHash: `0x${string}`,
): boolean {
  return keccak256(calldata).toLowerCase() === dataHash.toLowerCase()
}

export type ProposalCalldataSource = 'local' | 'onchain' | 'event' | 'metadata'

export type ResolvedProposalCalldata = {
  calldata: `0x${string}`
  source: ProposalCalldataSource
}

/**
 * Fetch calldata for a proposal nonce from SubmitTransaction logs.
 */
export async function fetchProposalCalldataFromEvents(
  publicClient: {
    getLogs: (args: {
      address: `0x${string}`
      event: typeof SUBMIT_TX_EVENT
      args: { nonce: bigint }
      fromBlock: bigint
    }) => Promise<
      {
        args: {
          nonce?: bigint
          data?: Hex
        }
      }[]
    >
  },
  chamberAddress: `0x${string}`,
  txId: number,
  dataHash: `0x${string}`,
): Promise<ResolvedProposalCalldata | null> {
  const logs = await publicClient.getLogs({
    address: chamberAddress,
    event: SUBMIT_TX_EVENT,
    args: { nonce: BigInt(txId) },
    fromBlock: 0n,
  })

  for (const log of logs) {
    const data = log.args.data
    if (!data) continue
    const calldata = data as `0x${string}`
    if (proposalCalldataMatchesHash(calldata, dataHash)) {
      return { calldata, source: 'event' }
    }
  }

  return null
}

export function normalizeCalldataHex(raw: string): `0x${string}` | null {
  const trimmed = raw.trim()
  if (!trimmed || trimmed === '0x') return null
  return (trimmed.startsWith('0x') ? trimmed : `0x${trimmed}`) as `0x${string}`
}

function shortHexAddress(value: string): string {
  if (value.length < 12) return value
  return `${value.slice(0, 6)}…${value.slice(-4)}`
}

function formatUintAmount(value: bigint): string {
  const formatted = formatUnits(value, 18)
  const [whole, frac = ''] = formatted.split('.')
  if (whole !== '0') {
    const trimmedFrac = frac.replace(/0+$/, '')
    return trimmedFrac ? `${whole}.${trimmedFrac}` : whole
  }
  const leadingZeros = frac.match(/^0*/)?.[0].length ?? 0
  if (leadingZeros >= 6) return value.toString()
  return `0.${frac.replace(/0+$/, '')}`
}

function formatDecodedArg(value: unknown): string {
  if (typeof value === 'bigint') return formatUintAmount(value)
  if (typeof value === 'string' && /^0x[a-fA-F0-9]{40}$/.test(value)) return shortHexAddress(value)
  if (typeof value === 'string') return value.length > 22 ? `${value.slice(0, 10)}…` : value
  if (Array.isArray(value)) return `[${value.map(formatDecodedArg).join(', ')}]`
  return String(value)
}

function summarizeDecodedCall(name: string, args: readonly unknown[] | undefined): string {
  const a = args ?? []
  switch (name) {
    case 'transfer':
      return `Transfer ${formatDecodedArg(a[1])} to ${formatDecodedArg(a[0])}`
    case 'approve':
      return `Approve ${formatDecodedArg(a[0])} for ${formatDecodedArg(a[1])}`
    case 'transferFrom':
      return `Transfer ${formatDecodedArg(a[2])} from ${formatDecodedArg(a[0])} to ${formatDecodedArg(a[1])}`
    case 'mint':
      return a.length >= 2
        ? `Mint ${formatDecodedArg(a[1])} to ${formatDecodedArg(a[0])}`
        : `Mint ${formatDecodedArg(a[0])}`
    case 'burn':
      return `Burn ${formatDecodedArg(a[0])}`
    case 'pause':
      return 'Pause'
    case 'unpause':
      return 'Unpause'
    case 'upgradeImplementation':
      return `Upgrade implementation to ${formatDecodedArg(a[0])}`
    case 'deposit':
      return a.length >= 1 ? `Deposit ${formatDecodedArg(a[0])}` : 'Deposit'
    case 'withdraw':
      return a.length >= 1 ? `Withdraw ${formatDecodedArg(a[0])}` : 'Withdraw'
    case 'claim':
      return a.length >= 1 ? `Claim ${formatDecodedArg(a[0])}` : 'Claim'
    default:
      return a.length > 0 ? `${name}(${a.map(formatDecodedArg).join(', ')})` : `${name}()`
  }
}

export type DecodedProposalAction = {
  functionName: string
  summary: string
}

/**
 * Decode archived execution bytes into a director-facing action line.
 * Tries Chamber + ERC-20 ABIs; falls back to metadata functionName or the selector.
 */
export function decodeProposalAction(
  calldata: string | undefined,
  hints?: { functionName?: string },
): DecodedProposalAction | null {
  const hex = calldata ? normalizeCalldataHex(calldata) : null
  if (!hex) return null

  for (const abi of [chamberAbi, erc20Abi] as const) {
    try {
      const decoded = decodeFunctionData({ abi, data: hex })
      const args = (decoded.args as readonly unknown[] | undefined) ?? []
      return {
        functionName: decoded.functionName,
        summary: summarizeDecodedCall(decoded.functionName, args),
      }
    } catch {
      // Selector is not in this ABI.
    }
  }

  const selector = hex.slice(0, 10).toLowerCase()
  if (hints?.functionName) {
    return {
      functionName: hints.functionName,
      summary: `${hints.functionName} (${selector})`,
    }
  }
  return {
    functionName: selector,
    summary: `Contract call ${selector}`,
  }
}

export function resolveCalldataFromMetadataField(
  metadataCalldata: string | undefined,
  dataHash: `0x${string}`,
): ResolvedProposalCalldata | null {
  const calldata = metadataCalldata ? normalizeCalldataHex(metadataCalldata) : null
  if (!calldata || !proposalCalldataMatchesHash(calldata, dataHash)) return null
  return { calldata, source: 'metadata' }
}

export async function fetchProposalCalldataOnchain(
  publicClient: Pick<PublicClient, 'readContract'>,
  chamberAddress: `0x${string}`,
  txId: number,
  dataHash: `0x${string}`,
): Promise<ResolvedProposalCalldata | null> {
  try {
    const stored = await publicClient.readContract({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransactionCalldata',
      args: [BigInt(txId)],
    })
    const calldata = stored as `0x${string}`
    if (!calldata || calldata === '0x') return null
    if (!proposalCalldataMatchesHash(calldata, dataHash)) return null
    return { calldata, source: 'onchain' }
  } catch {
    return null
  }
}

/**
 * Resolve calldata: localStorage, on-chain self-call store (L-04), metadata, then logs.
 * Persists successful hits to localStorage.
 */
export async function resolveProposalCalldata(
  publicClient: Parameters<typeof fetchProposalCalldataFromEvents>[0] & Pick<PublicClient, 'readContract'>,
  chamberAddress: `0x${string}`,
  txId: number,
  dataHash: `0x${string}`,
  metadataCalldata?: string,
): Promise<ResolvedProposalCalldata | null> {
  const stored = getStoredProposalCalldata(chamberAddress, txId)
  if (stored && proposalCalldataMatchesHash(stored, dataHash)) {
    return { calldata: stored, source: 'local' }
  }

  const fromOnchain = await fetchProposalCalldataOnchain(publicClient, chamberAddress, txId, dataHash)
  if (fromOnchain) {
    setStoredProposalCalldata(chamberAddress, txId, fromOnchain.calldata)
    return fromOnchain
  }

  const fromMeta = resolveCalldataFromMetadataField(metadataCalldata, dataHash)
  if (fromMeta) {
    setStoredProposalCalldata(chamberAddress, txId, fromMeta.calldata)
    return fromMeta
  }

  const fromEvents = await fetchProposalCalldataFromEvents(
    publicClient,
    chamberAddress,
    txId,
    dataHash,
  )
  if (fromEvents) {
    setStoredProposalCalldata(chamberAddress, txId, fromEvents.calldata)
    return fromEvents
  }

  return null
}

export { SUBMIT_TX_EVENT }
