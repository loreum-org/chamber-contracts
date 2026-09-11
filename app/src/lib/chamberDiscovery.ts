/**
 * Discover chambers the user created or might hold — no on-chain world directory.
 *
 * Order:
 * 1. Ponder GraphQL (`VITE_INDEXER_URL`) — loreum-org/chamber-indexer `chambers` /
 *    `chamberHolders` (creator OR share balance). Sepolia by default.
 * 2. Factory / Registry `ChamberCreated` via chunked `eth_getLogs` (not one
 *    getLogs-from-0). Factory remains the source of creation events; Registry
 *    logs are leftover legacy deploys only.
 *
 * Public Sepolia RPCs often reject or truncate a single from-0 `getLogs`.
 * Production RPC (Alchemy when `VITE_ALCHEMY_API_KEY` is set) can page history
 * older than 48h. A live Ponder host is optional.
 *
 * Failures are recorded on `health` (no raw GraphQL/RPC strings) so the
 * Dashboard can tell incomplete discovery from a truly empty wallet.
 */

import { parseAbiItem, type AbiEvent, type Address, type GetLogsReturnType, type PublicClient } from 'viem'
import { isNonZeroAddress } from '@/lib/address'
import {
  fetchIndexerMyChambers,
  getIndexerUrl,
  indexerAppliesToChain,
  type IndexerChamber,
} from '@/lib/indexer'

export const factoryCreatedEvent = parseAbiItem(
  'event ChamberCreated(address indexed chamber, address indexed asset, address indexed nft, uint256 seats, string name, string symbol, address creator)',
)

export const registryCreatedEvent = parseAbiItem(
  'event ChamberCreated(address indexed chamber, uint256 seats, string name, string symbol, address erc20Token, address erc721Token)',
)

/** chamber-indexer `REGISTRY_START_BLOCK` — Factory default matches when unset. */
export const SEPOLIA_DISCOVERY_START_BLOCK = 7453704n

/** Catch-up window after a successful indexer query (~2 days on 12s Sepolia). */
export const INDEXER_CATCHUP_BLOCKS = 16_384n

/** When no start block is configured, walk back far enough to survive >48h. */
export const UNBOUNDED_LOOKBACK_BLOCKS = 2_000_000n

const DEFAULT_LOG_CHUNK = 10_000n
const MIN_LOG_CHUNK = 200n
const LOG_CONCURRENCY = 4
const TX_CONCURRENCY = 4

export type ChamberDiscoveryHealth = {
  indexerConfigured: boolean
  indexerFailed: boolean
  /** Indexer answered; getLogs only covers the recent catch-up window. */
  catchupOnly: boolean
  /** A getLogs window was abandoned or Factory/Registry collection threw. */
  rpcErrored: boolean
}

export const EMPTY_DISCOVERY_HEALTH: ChamberDiscoveryHealth = {
  indexerConfigured: false,
  indexerFailed: false,
  catchupOnly: false,
  rpcErrored: false,
}

export function isChamberDiscoveryIncomplete(health: ChamberDiscoveryHealth): boolean {
  return health.indexerFailed || health.rpcErrored
}

/** Production banner: connected, settled, and discovery is degraded or the query died. */
export function shouldShowDiscoveryGap(options: {
  connected: boolean
  loading: boolean
  queryFailed: boolean
  health?: ChamberDiscoveryHealth
}): boolean {
  if (!options.connected || options.loading) return false
  if (options.queryFailed) return true
  return !!options.health && isChamberDiscoveryIncomplete(options.health)
}

export type DiscoveredChambers = {
  addresses: `0x${string}`[]
  creators: Map<string, `0x${string}`>
  health: ChamberDiscoveryHealth
}

export function parseStartBlock(raw: string | undefined): bigint | undefined {
  if (typeof raw !== 'string') return undefined
  const trimmed = raw.trim()
  if (trimmed === '') return undefined
  try {
    const value = BigInt(trimmed)
    return value >= 0n ? value : undefined
  } catch {
    return undefined
  }
}

export function discoveryStartBlock(chainId: number, kind: 'factory' | 'registry'): bigint {
  const env =
    kind === 'factory'
      ? {
          1: import.meta.env?.VITE_MAINNET_FACTORY_START_BLOCK,
          11155111: import.meta.env?.VITE_SEPOLIA_FACTORY_START_BLOCK,
          8453: import.meta.env?.VITE_BASE_FACTORY_START_BLOCK,
          42161: import.meta.env?.VITE_ARBITRUM_FACTORY_START_BLOCK,
        }[chainId]
      : {
          1: import.meta.env?.VITE_MAINNET_REGISTRY_START_BLOCK,
          11155111: import.meta.env?.VITE_SEPOLIA_REGISTRY_START_BLOCK,
          8453: import.meta.env?.VITE_BASE_REGISTRY_START_BLOCK,
          42161: import.meta.env?.VITE_ARBITRUM_REGISTRY_START_BLOCK,
        }[chainId]

  const parsed = parseStartBlock(env)
  if (parsed !== undefined) return parsed
  if (chainId === 11155111) return SEPOLIA_DISCOVERY_START_BLOCK
  return 0n
}

export function clampDiscoveryFromBlock(fromBlock: bigint, latest: bigint, catchupOnly: boolean): bigint {
  if (catchupOnly) {
    const catchup = latest > INDEXER_CATCHUP_BLOCKS ? latest - INDEXER_CATCHUP_BLOCKS : 0n
    return fromBlock > catchup ? fromBlock : catchup
  }
  if (fromBlock > 0n) return fromBlock
  if (latest > UNBOUNDED_LOOKBACK_BLOCKS) return latest - UNBOUNDED_LOOKBACK_BLOCKS
  return 0n
}

function pushChamber(
  addresses: `0x${string}`[],
  seen: Set<string>,
  creators: Map<string, `0x${string}`>,
  chamber: Address | undefined,
  creator?: Address,
) {
  if (!chamber || !isNonZeroAddress(chamber)) return
  const key = chamber.toLowerCase() as `0x${string}`
  if (!seen.has(key)) {
    seen.add(key)
    addresses.push(key)
  }
  if (creator && isNonZeroAddress(creator) && !creators.has(key)) {
    creators.set(key, creator.toLowerCase() as `0x${string}`)
  }
}

function mergeIndexerRows(
  addresses: `0x${string}`[],
  seen: Set<string>,
  creators: Map<string, `0x${string}`>,
  rows: IndexerChamber[],
) {
  for (const row of rows) {
    pushChamber(addresses, seen, creators, row.address, row.creator)
  }
}

async function mapPool<T, R>(items: T[], concurrency: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  if (items.length === 0) return []
  const out: R[] = new Array(items.length)
  let next = 0
  const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (next < items.length) {
      const i = next++
      out[i] = await fn(items[i]!)
    }
  })
  await Promise.all(workers)
  return out
}

type EventLogs<TEvent extends AbiEvent> = GetLogsReturnType<TEvent>

async function probeLogChunk<TEvent extends AbiEvent>(
  client: PublicClient,
  args: { address: `0x${string}`; event: TEvent },
  fromBlock: bigint,
  toBlock: bigint,
): Promise<bigint> {
  let chunk = DEFAULT_LOG_CHUNK
  while (chunk >= MIN_LOG_CHUNK) {
    const probeFrom = toBlock + 1n > chunk ? toBlock - chunk + 1n : fromBlock
    try {
      await client.getLogs({
        address: args.address,
        event: args.event,
        fromBlock: probeFrom,
        toBlock,
      })
      return chunk
    } catch {
      chunk = chunk / 2n
    }
  }
  return MIN_LOG_CHUNK
}

export type LogPageSink = { errored?: boolean }

export async function getEventLogsPaged<TEvent extends AbiEvent>(
  client: PublicClient,
  args: { address: `0x${string}`; event: TEvent; fromBlock: bigint; toBlock: bigint },
  sink?: LogPageSink,
): Promise<EventLogs<TEvent>> {
  try {
    return await client.getLogs({
      address: args.address,
      event: args.event,
      fromBlock: args.fromBlock,
      toBlock: args.toBlock,
    })
  } catch {
    const chunk = await probeLogChunk(client, args, args.fromBlock, args.toBlock)
    return collectLogs(client, args, args.fromBlock, args.toBlock, chunk, sink)
  }
}

async function collectLogs<TEvent extends AbiEvent>(
  client: PublicClient,
  args: { address: `0x${string}`; event: TEvent },
  fromBlock: bigint,
  toBlock: bigint,
  chunk: bigint,
  sink?: LogPageSink,
): Promise<EventLogs<TEvent>> {
  if (toBlock < fromBlock) return [] as EventLogs<TEvent>

  const span = toBlock - fromBlock + 1n
  if (span <= chunk) {
    try {
      return await client.getLogs({
        address: args.address,
        event: args.event,
        fromBlock,
        toBlock,
      })
    } catch {
      if (span <= MIN_LOG_CHUNK) {
        if (sink) sink.errored = true
        return [] as EventLogs<TEvent>
      }
      const mid = fromBlock + span / 2n - 1n
      const [left, right] = await Promise.all([
        collectLogs(client, args, fromBlock, mid, chunk, sink),
        collectLogs(client, args, mid + 1n, toBlock, chunk, sink),
      ])
      return [...left, ...right]
    }
  }

  const windows: Array<[bigint, bigint]> = []
  for (let start = fromBlock; start <= toBlock; start += chunk) {
    const end = start + chunk - 1n > toBlock ? toBlock : start + chunk - 1n
    windows.push([start, end])
  }

  const batches = await mapPool(windows, LOG_CONCURRENCY, ([start, end]) =>
    collectLogs(client, args, start, end, chunk, sink),
  )
  return batches.flat()
}

async function recoverRegistryCreators(
  client: PublicClient,
  logs: readonly { transactionHash?: `0x${string}` | null; args?: { chamber?: Address } }[],
  creators: Map<string, `0x${string}`>,
) {
  const needed: { hash: `0x${string}`; chamber: `0x${string}` }[] = []
  const seenTx = new Set<string>()
  for (const log of logs) {
    const chamber = log.args?.chamber
    const hash = log.transactionHash
    if (!chamber || !isNonZeroAddress(chamber) || !hash) continue
    const key = chamber.toLowerCase()
    if (creators.has(key) || seenTx.has(hash)) continue
    seenTx.add(hash)
    needed.push({ hash, chamber: key as `0x${string}` })
  }

  await mapPool(needed, TX_CONCURRENCY, async ({ hash, chamber }) => {
    try {
      const tx = await client.getTransaction({ hash })
      if (tx.from && isNonZeroAddress(tx.from) && !creators.has(chamber)) {
        creators.set(chamber, tx.from.toLowerCase() as `0x${string}`)
      }
    } catch {
      // creator badge is best-effort for leftover Registry events
    }
  })
}

export async function discoverChambers(options: {
  client: PublicClient
  chainId: number
  userAddress: Address
  factoryAddress?: `0x${string}`
  registryAddress?: `0x${string}`
  /** Test override. Unset uses `VITE_INDEXER_URL` when the chain matches. */
  indexerUrl?: string
}): Promise<DiscoveredChambers> {
  const { client, chainId, userAddress, factoryAddress, registryAddress } = options
  const addresses: `0x${string}`[] = []
  const seen = new Set<string>()
  const creators = new Map<string, `0x${string}`>()

  const factoryOk = isNonZeroAddress(factoryAddress)
  const registryOk = isNonZeroAddress(registryAddress)
  const indexerUrl =
    options.indexerUrl !== undefined
      ? options.indexerUrl.trim().replace(/\/+$/, '') || undefined
      : indexerAppliesToChain(chainId)
        ? getIndexerUrl()
        : undefined

  const health: ChamberDiscoveryHealth = {
    indexerConfigured: !!indexerUrl,
    indexerFailed: false,
    catchupOnly: false,
    rpcErrored: false,
  }

  let indexerOk = false
  if (indexerUrl) {
    try {
      const mine = await fetchIndexerMyChambers(indexerUrl, userAddress)
      mergeIndexerRows(addresses, seen, creators, mine.created)
      mergeIndexerRows(addresses, seen, creators, mine.held)
      indexerOk = true
      health.catchupOnly = true
    } catch {
      health.indexerFailed = true
    }
  }

  if (!factoryOk && !registryOk) {
    return { addresses, creators, health }
  }

  const latest = await client.getBlockNumber()

  const collectFactory = async () => {
    if (!factoryOk || !factoryAddress) return
    const sink: LogPageSink = {}
    try {
      const fromBlock = clampDiscoveryFromBlock(
        discoveryStartBlock(chainId, 'factory'),
        latest,
        indexerOk,
      )
      const logs = await getEventLogsPaged(
        client,
        {
          address: factoryAddress,
          event: factoryCreatedEvent,
          fromBlock,
          toBlock: latest,
        },
        sink,
      )
      for (const log of logs) {
        pushChamber(addresses, seen, creators, log.args.chamber, log.args.creator)
      }
    } catch {
      health.rpcErrored = true
    }
    if (sink.errored) health.rpcErrored = true
  }

  const collectRegistry = async () => {
    if (!registryOk || !registryAddress) return
    const sink: LogPageSink = {}
    try {
      const fromBlock = clampDiscoveryFromBlock(
        discoveryStartBlock(chainId, 'registry'),
        latest,
        indexerOk,
      )
      const logs = await getEventLogsPaged(
        client,
        {
          address: registryAddress,
          event: registryCreatedEvent,
          fromBlock,
          toBlock: latest,
        },
        sink,
      )
      for (const log of logs) {
        pushChamber(addresses, seen, creators, log.args.chamber)
      }
      if (!indexerOk) {
        await recoverRegistryCreators(client, logs, creators)
      }
    } catch {
      health.rpcErrored = true
    }
    if (sink.errored) health.rpcErrored = true
  }

  await Promise.all([collectFactory(), collectRegistry()])
  return { addresses, creators, health }
}
