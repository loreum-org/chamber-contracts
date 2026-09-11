/**
 * Live Sepolia check: a Registry chamber older than 48h is found via
 * production-style RPC getLogs (and a range-limited pagination path),
 * without localStorage. Factory-unset still works. Open-by-address is unchanged.
 *
 * Run: npx tsx --tsconfig tsconfig.json scripts/verify-sepolia-discovery.ts
 */
import assert from 'node:assert/strict'
import { createPublicClient, http, type PublicClient } from 'viem'
import { sepolia } from 'viem/chains'
import { addRecentChamber, getRecentChambers } from '../src/lib/recentChambers.ts'
import { discoverChambers, getEventLogsPaged, registryCreatedEvent } from '../src/lib/chamberDiscovery.ts'

const REGISTRY = '0xB028110234375A368Aa0b5fFB138ae1dDfb0b4cc' as const
const FACTORY = '0x43aA92c8A26392f21F63cdA88B6BaB5031C40550' as const
const KNOWN_OLD = '0x0ad3205ecfa76cdb52be5ebe099b990c35489888'
const KNOWN_OLD_BLOCK = 7453727n
const RPC = 'https://sepolia.gateway.tenderly.co'

const inner = createPublicClient({ chain: sepolia, transport: http(RPC) })

function rangeLimitedClient(maxSpan: bigint): PublicClient {
  return {
    ...inner,
    getBlockNumber: () => inner.getBlockNumber(),
    getTransaction: (args: Parameters<PublicClient['getTransaction']>[0]) => inner.getTransaction(args),
    getLogs: async (args: Parameters<PublicClient['getLogs']>[0]) => {
      const from = args.fromBlock
      const to = args.toBlock
      if (typeof from === 'bigint' && typeof to === 'bigint' && to - from + 1n > maxSpan) {
        throw new Error(`block range too large (${(to - from + 1n).toString()} > ${maxSpan})`)
      }
      return inner.getLogs(args)
    },
  } as PublicClient
}

const latest = await inner.getBlockNumber()
const ageBlocks = latest - KNOWN_OLD_BLOCK
assert.ok(ageBlocks > 14_400n, `known chamber is only ${ageBlocks} blocks old (~48h)`)

const windowFrom = KNOWN_OLD_BLOCK - 500n
const windowTo = KNOWN_OLD_BLOCK + 1_500n
const limited = rangeLimitedClient(800n)
const paged = await getEventLogsPaged(limited, {
  address: REGISTRY,
  event: registryCreatedEvent,
  fromBlock: windowFrom,
  toBlock: windowTo,
})
const found = paged.map((log) => log.args.chamber?.toLowerCase())
assert.ok(found.includes(KNOWN_OLD), `paged getLogs missed ${KNOWN_OLD}: ${found.join(',')}`)

const registryOnly = await discoverChambers({
  client: inner as PublicClient,
  chainId: 11155111,
  userAddress: '0x0000000000000000000000000000000000000001',
  registryAddress: REGISTRY,
})
assert.ok(
  registryOnly.addresses.includes(KNOWN_OLD),
  'Factory-unset / Registry-only still lists Registry-created chambers',
)
assert.equal(registryOnly.health.rpcErrored, false, 'live getLogs should not mark rpcErrored')

const factorySet = await discoverChambers({
  client: inner as PublicClient,
  chainId: 11155111,
  userAddress: '0x0000000000000000000000000000000000000001',
  factoryAddress: FACTORY,
  registryAddress: REGISTRY,
})
assert.ok(factorySet.addresses.includes(KNOWN_OLD), 'Factory set still includes leftover Registry chambers')

const openAddr = '0x1234567890123456789012345678901234567890' as const
const prev = globalThis.window
;(globalThis as { window?: { localStorage: Storage } }).window = {
  localStorage: (() => {
    const store = new Map<string, string>()
    return {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
      clear: () => void store.clear(),
      key: (i: number) => [...store.keys()][i] ?? null,
      get length() {
        return store.size
      },
    } as Storage
  })(),
}
addRecentChamber(11155111, openAddr)
assert.deepEqual(getRecentChambers(11155111), [openAddr])
if (prev === undefined) delete (globalThis as { window?: unknown }).window
else (globalThis as { window?: unknown }).window = prev

console.log('verify-sepolia-discovery: ok', {
  latest: latest.toString(),
  ageBlocks: ageBlocks.toString(),
  registryChambers: registryOnly.addresses,
  creators: [...registryOnly.creators.entries()],
})
