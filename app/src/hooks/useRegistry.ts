import { useQuery } from '@tanstack/react-query'
import {
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
  useChainId,
  usePublicClient,
} from 'wagmi'
import { zeroAddress, type Hex, type PublicClient } from 'viem'
import { registryAbi, chamberAbi, factoryAbi } from '@/contracts/abis'
import { REGISTRY_PAGE_SIZE } from '@/lib/chamberGovernance'
import {
  getContractAddresses,
  hasValidAddresses,
  isNonZeroAddress,
} from '@/lib/wagmi'
import {
  ERC1967_IMPLEMENTATION_SLOT,
  addressFromEip1967ImplementationSlot,
  chamberVersionBytes32ToLabel,
} from '@/lib/utils'

export function useRegistryAddress() {
  const chainId = useChainId()
  return getContractAddresses(chainId)?.registry ?? '0x0000000000000000000000000000000000000000' as `0x${string}`
}

export function useFactoryAddress() {
  const chainId = useChainId()
  return getContractAddresses(chainId)?.factory ?? '0x0000000000000000000000000000000000000000' as `0x${string}`
}

export function useHasValidConfig() {
  const chainId = useChainId()
  return {
    isValid: hasValidAddresses(chainId),
    chainId,
  }
}

function isValidAddress(addr: string | undefined): addr is `0x${string}` {
  return !!addr && addr !== zeroAddress && addr.startsWith('0x') && addr.length === 42
}

async function pageRegistryAddresses(
  client: PublicClient,
  registryAddress: `0x${string}`,
  pageFn: 'getChambers' | 'getAssets',
  countFn: 'getChamberCount' | 'getAssetCount',
): Promise<`0x${string}`[]> {
  const count = (await client.readContract({
    address: registryAddress,
    abi: registryAbi,
    functionName: countFn,
  })) as bigint

  const out: `0x${string}`[] = []
  for (let skip = 0n; skip < count; skip += REGISTRY_PAGE_SIZE) {
    const page = (await client.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: pageFn,
      args: [REGISTRY_PAGE_SIZE, skip],
    })) as `0x${string}`[]
    out.push(...page)
    if (page.length === 0) break
  }
  return out.filter(isValidAddress)
}

async function pageKeyedRegistryAddresses(
  client: PublicClient,
  registryAddress: `0x${string}`,
  pageFn: 'getChambersByAsset' | 'getChildChambers',
  countFn: 'getChambersByAssetCount' | 'getChildChamberCount',
  key: `0x${string}`,
  fallbackFn: 'getChambersByAsset' | 'getChildChambers',
): Promise<`0x${string}`[]> {
  try {
    const count = (await client.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: countFn,
      args: [key],
    })) as bigint

    const out: `0x${string}`[] = []
    for (let skip = 0n; skip < count; skip += REGISTRY_PAGE_SIZE) {
      const page = (await client.readContract({
        address: registryAddress,
        abi: registryAbi,
        functionName: pageFn,
        args: [key, REGISTRY_PAGE_SIZE, skip],
      })) as `0x${string}`[]
      out.push(...page)
      if (page.length === 0) break
    }
    return out.filter(isValidAddress)
  } catch {
    const page = (await client.readContract({
      address: registryAddress,
      abi: registryAbi,
      functionName: fallbackFn,
      args: [key],
    })) as `0x${string}`[]
    return page.filter(isValidAddress)
  }
}

export function useAllChambers() {
  const registryAddress = useRegistryAddress()
  const publicClient = usePublicClient()
  const isValidRegistry = isValidAddress(registryAddress)

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['registry-chambers-paged', registryAddress],
    enabled: isValidRegistry && !!publicClient,
    staleTime: 15_000,
    queryFn: async () => {
      if (!publicClient || !isValidRegistry) return []
      return pageRegistryAddresses(publicClient, registryAddress, 'getChambers', 'getChamberCount')
    },
  })

  return {
    chambers: data,
    isLoading,
    error,
    refetch,
    registryAddress,
  }
}

export function useChamberCount() {
  const registryAddress = useRegistryAddress()
  const isValidRegistry = registryAddress && 
    registryAddress !== '0x0000000000000000000000000000000000000000' &&
    registryAddress.startsWith('0x') &&
    registryAddress.length === 42
  
  const { data, refetch, isLoading, error } = useReadContract({
    address: isValidRegistry ? registryAddress : undefined,
    abi: registryAbi,
    functionName: 'getChamberCount',
    query: { 
      enabled: !!isValidRegistry,
      retry: 2,
      retryDelay: 1000,
    },
  })

  return { 
    count: data ? Number(data) : 0,
    refetch,
    isLoading,
    error,
    registryAddress,
  }
}

/**
 * Probe the address (`VERSION` / `nft` / `getSeats`) instead of requiring Registry.isChamber.
 * Registry.isChamber remains a soft hint for chambers that are still in the deprecated index.
 */
export function useIsChamber(
  address: `0x${string}` | undefined,
  opts?: { enabled?: boolean },
) {
  const registryAddress = useRegistryAddress()
  const registryOk = isNonZeroAddress(registryAddress)
  const enabled = (opts?.enabled ?? true) && !!address

  const {
    data: probe,
    isFetched: probeFetched,
    isFetching: probeFetching,
  } = useReadContracts({
    contracts: address
      ? [
          { address, abi: chamberAbi, functionName: 'VERSION' as const },
          { address, abi: chamberAbi, functionName: 'nft' as const },
          { address, abi: chamberAbi, functionName: 'getSeats' as const },
        ]
      : [],
    query: { enabled, retry: 1 },
  })

  const { data: registryHint, isFetched: hintFetched } = useReadContract({
    address: registryOk ? registryAddress : undefined,
    abi: registryAbi,
    functionName: 'isChamber',
    args: address ? [address] : undefined,
    query: { enabled: enabled && registryOk },
  })

  if (!address || !enabled) return undefined

  const looksLikeChamber = !!probe?.some((r) => r.status === 'success' && r.result !== undefined)
  if (looksLikeChamber) return true
  if (registryHint === true) return true
  if (probeFetched && (!registryOk || hintFetched)) return false
  if (probeFetching) return undefined
  return undefined
}

export function useChambersByAsset(asset: `0x${string}` | undefined) {
  const registryAddress = useRegistryAddress()
  const publicClient = usePublicClient()
  const isValidRegistry = isValidAddress(registryAddress)

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['registry-chambers-by-asset-paged', registryAddress, asset],
    enabled: !!asset && isValidRegistry && !!publicClient,
    staleTime: 15_000,
    queryFn: async () => {
      if (!publicClient || !isValidRegistry || !asset) return []
      return pageKeyedRegistryAddresses(
        publicClient,
        registryAddress,
        'getChambersByAsset',
        'getChambersByAssetCount',
        asset,
        'getChambersByAsset',
      )
    },
  })

  return {
    chambers: data,
    isLoading,
    error,
    refetch,
  }
}

export function useAssets() {
  const registryAddress = useRegistryAddress()
  const publicClient = usePublicClient()
  const isValidRegistry = isValidAddress(registryAddress)

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['registry-assets-paged', registryAddress],
    enabled: isValidRegistry && !!publicClient,
    staleTime: 15_000,
    queryFn: async () => {
      if (!publicClient || !isValidRegistry) return []
      try {
        return await pageRegistryAddresses(publicClient, registryAddress, 'getAssets', 'getAssetCount')
      } catch {
        const page = (await publicClient.readContract({
          address: registryAddress,
          abi: registryAbi,
          functionName: 'getAssets',
          args: [],
        })) as `0x${string}`[]
        return page.filter(isValidAddress)
      }
    },
  })

  return {
    assets: data,
    isLoading,
    error,
    refetch,
  }
}

/**
 * Groups the given chambers by their membership NFT (ERC721).
 * Pass the user's chambers — do not crawl the world index.
 */
export function useOrganizationsByNFT(chambers?: readonly `0x${string}`[]) {
  const validChambers = (chambers ?? []).filter(
    (addr): addr is `0x${string}` =>
      !!addr &&
      addr !== '0x0000000000000000000000000000000000000000' &&
      addr.startsWith('0x') &&
      addr.length === 42
  )

  const { data: nftResults, isLoading: nftsLoading } = useReadContracts({
    contracts: validChambers.map((addr) => ({
      address: addr,
      abi: chamberAbi,
      functionName: 'nft',
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'nft' }[],
    query: {
      enabled: validChambers.length > 0,
    },
  })

  const organizations = (() => {
    if (!nftResults || nftResults.length !== validChambers.length) return []
    const byNft = new Map<string, `0x${string}`[]>()
    for (let i = 0; i < validChambers.length; i++) {
      const r = nftResults[i]
      const chamber = validChambers[i]
      if (r?.status === 'success' && r.result && chamber) {
        const nft = (r.result as string).toLowerCase() as `0x${string}`
        if (!byNft.has(nft)) byNft.set(nft, [])
        byNft.get(nft)!.push(chamber)
      }
    }
    return Array.from(byNft.entries()).map(([nft, chams]) => ({
      nft: nft as `0x${string}`,
      chambers: chams,
    }))
  })()

  return {
    organizations,
    isLoading: nftsLoading && validChambers.length > 0,
  }
}

export function useParentChamber(chamber: `0x${string}` | undefined) {
  const registryAddress = useRegistryAddress()
  
  const { data, isLoading, error, refetch } = useReadContract({
    address: registryAddress,
    abi: registryAbi,
    functionName: 'getParentChamber',
    args: chamber ? [chamber] : undefined,
    query: { enabled: !!chamber && registryAddress !== '0x0000000000000000000000000000000000000000' },
  })

  return {
    parentChamber: data as `0x${string}` | undefined,
    isLoading,
    error,
    refetch,
  }
}

export function useChildChambers(chamber: `0x${string}` | undefined) {
  const registryAddress = useRegistryAddress()
  const publicClient = usePublicClient()
  const isValidRegistry = isValidAddress(registryAddress)

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['registry-child-chambers-paged', registryAddress, chamber],
    enabled: !!chamber && isValidRegistry && !!publicClient,
    staleTime: 15_000,
    queryFn: async () => {
      if (!publicClient || !isValidRegistry || !chamber) return []
      return pageKeyedRegistryAddresses(
        publicClient,
        registryAddress,
        'getChildChambers',
        'getChildChamberCount',
        chamber,
        'getChildChambers',
      )
    },
  })

  return {
    childChambers: data,
    isLoading,
    error,
    refetch,
  }
}

export function useCreateChamber() {
  const factoryAddress = useFactoryAddress()
  const registryAddress = useRegistryAddress()
  const createAddress = isNonZeroAddress(factoryAddress) ? factoryAddress : registryAddress
  const createAbi = isNonZeroAddress(factoryAddress) ? factoryAbi : registryAbi
  const { writeContract, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess, data: receipt } = useWaitForTransactionReceipt({ hash })

  const createChamber = async (
    erc20Token: `0x${string}`,
    erc721Token: `0x${string}`,
    seats: number,
    name: string,
    symbol: string
  ) => {
    writeContract({
      address: createAddress,
      abi: createAbi,
      functionName: 'createChamber',
      args: [erc20Token, erc721Token, BigInt(seats), name, symbol],
    })
  }

  return {
    createChamber,
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    receipt,
  }
}

/**
 * Compare this chamber proxy’s EIP-1967 implementation with the Registry’s
 * default implementation used for new deployments. When the Registry bumps
 * its implementation pointer, existing proxies may lag until upgraded.
 */
export function useChamberRegistryImplementationSync(chamberAddress: `0x${string}` | undefined) {
  const factoryAddress = useFactoryAddress()
  const registryAddress = useRegistryAddress()
  const chainId = useChainId()
  const publicClient = usePublicClient()
  const factoryOk = isNonZeroAddress(factoryAddress)
  const registryOk = isNonZeroAddress(registryAddress)

  const { data: factoryImplementation, isLoading: factoryImplLoading } = useReadContract({
    address: factoryOk ? factoryAddress : undefined,
    abi: factoryAbi,
    functionName: 'implementation',
    query: { enabled: factoryOk && !!chamberAddress },
  })

  const { data: registryImplementation, isLoading: registryImplLoading } = useReadContract({
    address: registryOk && !factoryOk ? registryAddress : undefined,
    abi: registryAbi,
    functionName: 'implementation',
    query: { enabled: registryOk && !factoryOk && !!chamberAddress },
  })

  const preferredImpl = factoryOk ? factoryImplementation : registryImplementation
  const regImpl =
    preferredImpl && preferredImpl !== zeroAddress
      ? (preferredImpl as `0x${string}`)
      : undefined

  const { data: proxyImplementationAddress, isLoading: slotLoading } = useQuery({
    queryKey: ['chamberProxyImplementation', chamberAddress, chainId],
    queryFn: async () => {
      if (!publicClient || !chamberAddress) return undefined
      const raw = await publicClient.getStorageAt({
        address: chamberAddress,
        slot: ERC1967_IMPLEMENTATION_SLOT,
      })
      return addressFromEip1967ImplementationSlot(raw as Hex | undefined)
    },
    enabled: !!chamberAddress && !!publicClient,
  })

  const { data: chamberVerRaw, isLoading: chamberVerLoading } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'VERSION',
    query: { enabled: !!chamberAddress },
  })

  const { data: registryVerRaw, isLoading: registryVerLoading } = useReadContract({
    address: regImpl,
    abi: chamberAbi,
    functionName: 'VERSION',
    query: { enabled: !!regImpl },
  })

  const chamberVersionLabel = chamberVersionBytes32ToLabel(chamberVerRaw as Hex | undefined)
  const registryImplementationVersionLabel = chamberVersionBytes32ToLabel(registryVerRaw as Hex | undefined)

  const implMismatch =
    !!proxyImplementationAddress &&
    !!regImpl &&
    proxyImplementationAddress.toLowerCase() !== regImpl.toLowerCase()

  return {
    proxyImplementationAddress,
    registryImplementation: regImpl,
    chamberVersionLabel,
    registryImplementationVersionLabel,
    implMismatch,
    registryAddress: factoryOk ? factoryAddress : registryOk ? registryAddress : undefined,
    isLoading:
      factoryImplLoading || registryImplLoading || slotLoading || chamberVerLoading || registryVerLoading,
  }
}
