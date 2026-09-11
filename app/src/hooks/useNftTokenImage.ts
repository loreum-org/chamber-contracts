import { useMemo, useEffect } from 'react'
import { useReadContract, useReadContracts } from 'wagmi'
import { zeroAddress } from 'viem'
import { useQuery } from '@tanstack/react-query'
import { erc721Abi } from '@/contracts/abis'
import { fetchErc721MetadataWithRetry, resolveErc721ImageFromMetadata } from '@/lib/ipfs'

/** Keep fresh: partial maps were cached 1h and never refetched; chamber events must invalidate. */
const NFT_IMAGE_STALE_MS = 0

/** Always refetch when a consumer mounts (e.g. Delegation tab) — wagmi default staleTime can leave empty reads cached. */
const NFT_TOKENURI_QUERY = {
  staleTime: 0,
  refetchOnMount: true,
  retry: 2,
} as const

export type UseNftImageOpts = {
  enabled?: boolean
  /**
   * Include in the React Query key so `invalidateQueries` for this chamber refetches images
   * after delegations/board updates (keys without this never matched chamber invalidation).
   */
  chamberAddress?: `0x${string}`
}

/**
 * Resolved HTTPS image URL for an ERC721 token via tokenURI → JSON metadata `image`.
 */
export function useNftTokenImage(
  nftAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
  opts?: Pick<UseNftImageOpts, 'chamberAddress'>
) {
  const enabledAddr = !!nftAddress && nftAddress !== zeroAddress
  const scope = (opts?.chamberAddress ?? '').toLowerCase()

  const {
    data: tokenURI,
    isPending: tokenUriPending,
    isFetching: tokenUriFetching,
  } = useReadContract({
    address: enabledAddr ? nftAddress : undefined,
    abi: erc721Abi,
    functionName: 'tokenURI',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: enabledAddr && tokenId !== undefined && tokenId > 0n,
      ...NFT_TOKENURI_QUERY,
    },
  })

  const uri = typeof tokenURI === 'string' ? tokenURI : undefined
  const uriKey = uri ?? ''

  const imageQuery = useQuery({
    queryKey: ['nft-token-image', nftAddress?.toLowerCase() ?? '', scope, tokenId?.toString() ?? '', uriKey],
    enabled: !!enabledAddr && tokenId !== undefined && tokenId > 0n && !!uriKey.length,
    staleTime: NFT_IMAGE_STALE_MS,
    refetchOnMount: 'always',
    retry: 2,
    retryDelay: (a) => Math.min(1500 * 2 ** a, 12_000),
    queryFn: async ({ queryKey }): Promise<string | undefined> => {
      const raw = queryKey[4] as string
      if (typeof raw !== 'string' || !raw.length) return undefined
      const pack = await fetchErc721MetadataWithRetry(raw)
      const url = resolveErc721ImageFromMetadata(pack?.meta, pack?.documentUrl)
      const t = typeof url === 'string' ? url.trim() : ''
      return t.length > 0 ? t : undefined
    },
  })

  const resolvingImages =
    !!enabledAddr && tokenId !== undefined && tokenId > 0n
      ? tokenUriPending ||
        tokenUriFetching ||
        imageQuery.isPending ||
        imageQuery.isFetching ||
        imageQuery.isLoading
      : false

  return { ...imageQuery, resolvingImages }
}

/**
 * Batch-resolve images for many token IDs (multicall tokenURI + one metadata fetch per token).
 */
export function useNftImageMap(
  nftAddress: `0x${string}` | undefined,
  tokenIds: bigint[],
  opts?: UseNftImageOpts
) {
  const enabledAddr = !!nftAddress && nftAddress !== zeroAddress
  const scope = (opts?.chamberAddress ?? '').toLowerCase()
  // Value-based key: parents often pass new `tokenIds` arrays each render; stable `ids` keeps multicall config stable.
  const idsKey = [...new Set(tokenIds.map((id) => id.toString()))].join(',')
  const ids = useMemo(
    () => (idsKey ? idsKey.split(',').filter(Boolean).map(BigInt) : []),
    [idsKey]
  )

  const contracts = useMemo(
    (): {
      address: `0x${string}`
      abi: typeof erc721Abi
      functionName: 'tokenURI'
      args: readonly [bigint]
    }[] =>
      !nftAddress || !enabledAddr || ids.length === 0
        ? []
        : ids.map((id) => ({
            address: nftAddress,
            abi: erc721Abi,
            functionName: 'tokenURI' as const,
            args: [id],
          })),
    [nftAddress, ids, enabledAddr]
  )

  const { data: uriResults, isPending: uriReadsPending, isFetching: uriReadsFetching } =
    useReadContracts({
      contracts,
      query: {
        enabled: (opts?.enabled ?? true) && !!enabledAddr && contracts.length > 0,
        ...NFT_TOKENURI_QUERY,
      },
    })

  /** [tokenId, tokenURI] pairs — avoids `queryFn` closing over stale `uriResults` (fixes IPFS map after client nav). */
  const uriPairs = useMemo((): [string, string][] => {
    if (!uriResults || ids.length === 0) return []
    return ids.flatMap((id, i) => {
      const r = uriResults[i]
      if (r?.status !== 'success' || typeof r.result !== 'string' || !r.result) return []
      return [[id.toString(), r.result] as [string, string]]
    })
  }, [uriResults, ids])

  /** Token ids that have a successful tokenURI read — image map should eventually cover all of these. */
  const tokenIdsWithSuccessfulUri = useMemo(() => uriPairs.map(([id]) => id), [uriPairs])

  const imageQuery = useQuery({
    queryKey: ['nft-image-map', nftAddress?.toLowerCase() ?? '', scope, uriPairs],
    enabled: (opts?.enabled ?? true) && !!enabledAddr && uriPairs.length > 0,
    staleTime: NFT_IMAGE_STALE_MS,
    refetchOnMount: 'always',
    retry: 2,
    retryDelay: (a) => Math.min(1500 * 2 ** a, 12_000),
    queryFn: async ({ queryKey }): Promise<Map<string, string>> => {
      const pairs = queryKey[3] as [string, string][]
      const out = new Map<string, string>()
      await Promise.all(
        pairs.map(async ([id, rawUri]) => {
          const pack = await fetchErc721MetadataWithRetry(rawUri)
          const img = resolveErc721ImageFromMetadata(pack?.meta, pack?.documentUrl)
          const t = typeof img === 'string' ? img.trim() : ''
          if (t.length > 0) out.set(id, t)
        })
      )
      return out
    },
  })

  const mapIncomplete =
    imageQuery.isSuccess &&
    !!imageQuery.data &&
    tokenIdsWithSuccessfulUri.length > 0 &&
    tokenIdsWithSuccessfulUri.some((id) => !imageQuery.data!.has(id))

  const refetchImages = imageQuery.refetch
  useEffect(() => {
    if (!mapIncomplete) return
    const t = window.setInterval(() => {
      void refetchImages()
    }, 28_000)
    return () => window.clearInterval(t)
  }, [mapIncomplete, refetchImages])

  const resolvingImages =
    !!enabledAddr &&
    ids.length > 0 &&
    (uriReadsPending ||
      uriReadsFetching ||
      imageQuery.isPending ||
      imageQuery.isFetching ||
      imageQuery.isLoading)

  return { ...imageQuery, resolvingImages }
}
