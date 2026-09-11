import { useCallback, useEffect, useState } from 'react'
import { useAccount, useChainId, usePublicClient } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { multicall } from 'viem/actions'
import { chamberAbi, factoryAbi, registryAbi } from '@/contracts/abis'
import {
  discoverChambers,
  EMPTY_DISCOVERY_HEALTH,
  shouldShowDiscoveryGap,
  type ChamberDiscoveryHealth,
} from '@/lib/chamberDiscovery'
import { getIndexerUrl, indexerAppliesToChain } from '@/lib/indexer'
import { addRecentChamber, getRecentChambers } from '@/lib/recentChambers'
import { isNonZeroAddress } from '@/lib/wagmi'
import { useFactoryAddress, useRegistryAddress } from './useRegistry'

export function useRecentChambers() {
  const chainId = useChainId()
  const [recents, setRecents] = useState<`0x${string}`[]>(() => getRecentChambers(chainId))

  useEffect(() => {
    setRecents(getRecentChambers(chainId))
  }, [chainId])

  const remember = useCallback(
    (address: string) => {
      setRecents(addRecentChamber(chainId, address))
    },
    [chainId],
  )

  return { recents, remember }
}

export type MyChamberEntry = {
  address: `0x${string}`
  isDirector: boolean
  balance: bigint
  isCreator: boolean
}

/**
 * Chambers the connected user participates in: Ponder indexer (optional) +
 * Factory/Registry `ChamberCreated` logs plus local recents, kept when the user
 * is creator, a director, or holds shares.
 */
export function useMyChambers() {
  const { address: userAddress } = useAccount()
  const chainId = useChainId()
  const publicClient = usePublicClient()
  const factoryAddress = useFactoryAddress()
  const registryAddress = useRegistryAddress()
  const { recents, remember } = useRecentChambers()

  const factoryOk = isNonZeroAddress(factoryAddress)
  const registryOk = isNonZeroAddress(registryAddress)
  const indexerUrl = indexerAppliesToChain(chainId) ? getIndexerUrl() ?? '' : ''

  const query = useQuery({
    queryKey: [
      'my-chambers',
      chainId,
      userAddress,
      factoryOk ? factoryAddress : '0x0',
      registryOk ? registryAddress : '0x0',
      indexerUrl,
      recents.join(),
    ],
    enabled:
      !!publicClient &&
      !!userAddress &&
      (factoryOk || registryOk || recents.length > 0 || !!indexerUrl),
    staleTime: 15_000,
    queryFn: async (): Promise<{ chambers: MyChamberEntry[]; health: ChamberDiscoveryHealth }> => {
      if (!publicClient || !userAddress) {
        return { chambers: [], health: EMPTY_DISCOVERY_HEALTH }
      }

      const { addresses: discovered, creators, health } = await discoverChambers({
        client: publicClient,
        chainId,
        userAddress,
        factoryAddress: factoryOk ? factoryAddress : undefined,
        registryAddress: registryOk ? registryAddress : undefined,
      })

      const candidates: `0x${string}`[] = []
      const seen = new Set<string>()
      for (const addr of [...discovered, ...recents]) {
        const key = addr.toLowerCase()
        if (seen.has(key)) continue
        seen.add(key)
        candidates.push(addr)
      }

      if (candidates.length === 0) return { chambers: [], health }

      const user = userAddress.toLowerCase()
      const [dirs, bals] = await Promise.all([
        multicall(publicClient, {
          contracts: candidates.map((address) => ({
            address,
            abi: chamberAbi,
            functionName: 'getDirectors' as const,
          })),
          allowFailure: true,
        }),
        multicall(publicClient, {
          contracts: candidates.map((address) => ({
            address,
            abi: chamberAbi,
            functionName: 'balanceOf' as const,
            args: [userAddress] as const,
          })),
          allowFailure: true,
        }),
      ])

      const mine: MyChamberEntry[] = []
      for (let i = 0; i < candidates.length; i++) {
        const address = candidates[i]!
        const dirResult = dirs[i]
        const balResult = bals[i]
        const directors =
          dirResult?.status === 'success' ? (dirResult.result as `0x${string}`[]) : undefined
        const balance = balResult?.status === 'success' ? (balResult.result as bigint) : 0n
        const isDirector = !!directors?.some((d) => d.toLowerCase() === user)
        const hasBalance = balance > 0n
        const isCreator = creators.get(address) === user
        const isRecent = recents.some((r) => r === address)
        if (isCreator || isDirector || hasBalance || isRecent) {
          mine.push({ address, isDirector, balance, isCreator })
        }
      }
      return { chambers: mine, health }
    },
  })

  return {
    chambers: query.data?.chambers ?? [],
    isLoading: query.isLoading,
    error: query.error,
    discoveryIncomplete: shouldShowDiscoveryGap({
      connected: !!userAddress,
      loading: query.isLoading,
      queryFailed: query.isError,
      health: query.data?.health,
    }),
    refetch: query.refetch,
    recents,
    remember,
    factoryAddress,
    registryAddress,
  }
}

export function useCreateChamberTarget() {
  const factoryAddress = useFactoryAddress()
  const registryAddress = useRegistryAddress()
  if (isNonZeroAddress(factoryAddress)) {
    return { address: factoryAddress, abi: factoryAbi, source: 'factory' as const }
  }
  if (isNonZeroAddress(registryAddress)) {
    return { address: registryAddress, abi: registryAbi, source: 'registry' as const }
  }
  return { address: undefined, abi: factoryAbi, source: 'none' as const }
}
