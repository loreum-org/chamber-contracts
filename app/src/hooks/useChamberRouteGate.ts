import { useQuery } from '@tanstack/react-query'
import { getPublicClient } from 'wagmi/actions'
import { useChainId } from 'wagmi'
import type { PublicClient } from 'viem'
import { chamberAbi, registryAbi } from '@/contracts/abis'
import { classifyChamberRoute, type ChamberRouteDecision } from '@/lib/chamberRoute'
import {
  config,
  getConfiguredChainIds,
  getContractAddresses,
  hasValidAddresses,
  isNonZeroAddress,
} from '@/lib/wagmi'
import { useIsChamber } from './useRegistry'

async function probeLooksLikeChamber(
  client: PublicClient,
  address: `0x${string}`,
  chainId: number,
): Promise<boolean> {
  const results = await Promise.allSettled([
    client.readContract({ address, abi: chamberAbi, functionName: 'VERSION' }),
    client.readContract({ address, abi: chamberAbi, functionName: 'nft' }),
    client.readContract({ address, abi: chamberAbi, functionName: 'getSeats' }),
  ])
  if (results.some((r) => r.status === 'fulfilled' && r.value !== undefined)) return true

  const registry = getContractAddresses(chainId)?.registry
  if (!isNonZeroAddress(registry)) return false
  try {
    const hint = await client.readContract({
      address: registry,
      abi: registryAbi,
      functionName: 'isChamber',
      args: [address],
    })
    return hint === true
  } catch {
    return false
  }
}

function useChamberOnOtherConfiguredChain(
  address: `0x${string}` | undefined,
  enabled: boolean,
) {
  const chainId = useChainId()
  const otherIds = getConfiguredChainIds().filter((id) => id !== chainId)

  return useQuery({
    queryKey: ['chamber-on-other-configured-chain', address, chainId, otherIds],
    enabled: !!address && enabled && otherIds.length > 0,
    staleTime: 15_000,
    queryFn: async () => {
      if (!address) return null
      for (const id of otherIds) {
        const client = getPublicClient(config, { chainId: id })
        if (!client) continue
        try {
          if (await probeLooksLikeChamber(client, address, id)) return id
        } catch {
          // RPC down or chain unused in this environment — try the next configured chain.
        }
      }
      return null
    },
  })
}

export function useChamberRouteDecision(
  address: `0x${string}` | undefined,
): ChamberRouteDecision {
  const chainId = useChainId()
  const configValid = hasValidAddresses(chainId)
  const supportedChainIds = getConfiguredChainIds()
  const isChamber = useIsChamber(address, { enabled: configValid })
  const otherConfigured = supportedChainIds.filter((id) => id !== chainId)
  const shouldProbeOthers = configValid && isChamber === false && otherConfigured.length > 0
  const { data: foundOnOtherChainId, isFetched } = useChamberOnOtherConfiguredChain(
    address,
    shouldProbeOthers,
  )

  return classifyChamberRoute({
    hasAddress: !!address,
    currentChainId: chainId,
    configValid,
    supportedChainIds,
    isChamber: configValid ? isChamber : undefined,
    foundOnOtherChainId: shouldProbeOthers
      ? isFetched
        ? (foundOnOtherChainId ?? null)
        : undefined
      : null,
  })
}
