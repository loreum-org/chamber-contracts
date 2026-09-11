import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt, useSimulateContract, useAccount, useBlockNumber, usePublicClient, useChainId } from 'wagmi'
import { isAddress, zeroAddress } from 'viem'
import { chamberAbi, erc20Abi, erc721Abi } from '@/contracts/abis'
import { chamberVersionBytes32ToLabel } from '@/lib/utils'
import { isSeatingMature } from '@/lib/chamberGovernance'
import { getAlchemyApiKeyFromEnv } from '@/lib/alchemy'
import { listOwnedErc721TokenIds } from '@/lib/ownedErc721'
import { isOnchainContractBytecode } from '@/lib/address'
import type { Transaction, BoardMember, SeatUpdate } from '@/types'

/** Public RPC / long block times: retry eth_call simulation and refresh state after txs. */
const SLOW_CHAIN_SIMULATE_QUERY = {
  staleTime: 0 as const,
  retry: 5,
  retryDelay: (attemptIndex: number) => Math.min(3000 * 2 ** attemptIndex, 45_000),
}

export type SimulateQueryOpts = { queryEnabled?: boolean }

// ERC20 Allowance hook
export function useTokenAllowance(
  tokenAddress: `0x${string}` | undefined,
  ownerAddress: `0x${string}` | undefined,
  spenderAddress: `0x${string}` | undefined,
  opts?: { refetchInterval?: number | false }
) {
  const { data: allowance, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: ownerAddress && spenderAddress ? [ownerAddress, spenderAddress] : undefined,
    query: {
      enabled: !!tokenAddress && !!ownerAddress && !!spenderAddress,
      refetchInterval: opts?.refetchInterval,
      staleTime: 0,
      retry: 4,
      retryDelay: (attemptIndex: number) => Math.min(2000 * 2 ** attemptIndex, 30_000),
    },
  })

  return { allowance: allowance as bigint | undefined, refetch }
}

// ERC20 Approve hook
export function useTokenApprove(tokenAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const approve = async (spender: `0x${string}`, amount: bigint) => {
    if (!tokenAddress) return
    return writeContractAsync({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'approve',
      args: [spender, amount],
    })
  }

  return { approve, isPending, isConfirming, isSuccess, error, hash }
}

// Permit2 Approve hook
export function usePermit2Approve() {
  const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3'
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const approvePermit2 = async (token: `0x${string}`, spender: `0x${string}`, amount: bigint, expiration: number) => {
    return writeContractAsync({
      address: PERMIT2_ADDRESS,
      abi: [
        {
          type: 'function',
          name: 'approve',
          inputs: [
            { name: 'token', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint160' },
            { name: 'expiration', type: 'uint48' },
          ],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ] as const,
      functionName: 'approve',
      args: [token, spender, amount, expiration],
    })
  }

  return { approvePermit2, isPending, isConfirming, isSuccess, error, hash }
}

// ERC20 Balance hook
export function useTokenBalance(tokenAddress: `0x${string}` | undefined, account: `0x${string}` | undefined) {
  const { data: balance, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    query: { enabled: !!tokenAddress && !!account },
  })

  return { balance: balance as bigint | undefined, refetch }
}

export function useChamberInfo(chamberAddress: `0x${string}` | undefined) {
  // Validate address before making queries
  const isValidAddress = chamberAddress &&
    chamberAddress !== '0x0000000000000000000000000000000000000000' &&
    isAddress(chamberAddress)

  const { data: name } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'name',
    query: { 
      enabled: !!isValidAddress,
      retry: 1, // Reduce retries to avoid stack overflow
      retryDelay: 1000,
    },
  })

  const { data: symbol } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'symbol',
    query: { 
      enabled: !!isValidAddress,
      retry: 1, // Reduce retries to avoid stack overflow
      retryDelay: 1000,
    },
  })

  const { data: totalAssets } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'totalAssets',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: totalSupply } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'totalSupply',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: seats } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'getSeats',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: quorum } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'getQuorum',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: directors } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'getDirectors',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: transactionCount, refetch: refetchTransactionCount } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'getTransactionCount',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: assetToken } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'asset',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: nftToken } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'nft',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: versionBytes32 } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'VERSION',
    query: { 
      enabled: !!isValidAddress,
      retry: 1,
      retryDelay: 1000,
    },
  })

  const { data: paused } = useReadContract({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    functionName: 'paused',
    query: {
      enabled: !!isValidAddress,
      retry: false,
    },
  })

  return {
    name: name as string | undefined,
    symbol: symbol as string | undefined,
    totalAssets: totalAssets as bigint | undefined,
    totalSupply: totalSupply as bigint | undefined,
    seats: seats ? Number(seats) : undefined,
    quorum: quorum ? Number(quorum) : undefined,
    directors: directors as `0x${string}`[] | undefined,
    transactionCount: transactionCount ? Number(transactionCount) : undefined,
    refetchTransactionCount,
    assetToken: assetToken as `0x${string}` | undefined,
    nftToken: nftToken as `0x${string}` | undefined,
    version: chamberVersionBytes32ToLabel(versionBytes32 as `0x${string}` | undefined),
    paused: paused === true,
  }
}

export function useChamberBalance(chamberAddress: `0x${string}` | undefined, account: `0x${string}` | undefined) {
  const { data: balance, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    query: {
      enabled: !!chamberAddress && !!account,
      retry: false,
    },
  })

  return { balance: balance as bigint | undefined, refetch }
}

export function useBoardMembers(chamberAddress: `0x${string}` | undefined, count: number = 20) {
  const { data, refetch, isPending, isFetched } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getTop',
    args: [BigInt(count)],
    query: { enabled: !!chamberAddress },
  })

  const members: BoardMember[] = []
  if (data) {
    const [tokenIds, amounts] = data as [bigint[], bigint[]]
    for (let i = 0; i < tokenIds.length; i++) {
      members.push({
        tokenId: tokenIds[i],
        amount: amounts[i],
        next: 0n,
        prev: 0n,
        rank: i + 1,
      })
    }
  }

  return { members, refetch, isPending, isFetched }
}

/**
 * Resolves ERC721 ownerOf for each membership token ID (director wallets on the board).
 */
export function useMembershipTokenOwners(
  nftAddress: `0x${string}` | undefined,
  tokenIds: bigint[]
) {
  const enabled =
    !!nftAddress &&
    nftAddress !== '0x0000000000000000000000000000000000000000' &&
    tokenIds.length > 0

  const contracts = tokenIds.map((tokenId) => ({
    address: nftAddress!,
    abi: erc721Abi,
    functionName: 'ownerOf' as const,
    args: [tokenId] as const,
  }))

  const { data, refetch, isPending, isFetched } = useReadContracts({
    contracts,
    query: { enabled },
  })

  const owners = useMemo((): (`0x${string}` | undefined)[] => {
    if (!enabled || !data || data.length !== tokenIds.length) {
      return tokenIds.map(() => undefined)
    }
    return data.map((r) => {
      if (r.status === 'success' && r.result !== undefined && r.result !== null) {
        return r.result as `0x${string}`
      }
      return undefined
    })
  }, [enabled, data, tokenIds])

  return { owners, refetch, isPending, isFetched }
}

export function useTransaction(chamberAddress: `0x${string}` | undefined, transactionId: number) {
  const { data, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getTransaction',
    args: [BigInt(transactionId)],
    query: { enabled: !!chamberAddress && transactionId >= 0 },
  })

  let transaction: Transaction | undefined
  if (data) {
    const [executed, confirmations, target, value, dataHash] = data as [
      boolean,
      number,
      `0x${string}`,
      bigint,
      `0x${string}`,
    ]
    transaction = {
      id: transactionId,
      executed,
      confirmations,
      target,
      value,
      dataHash,
    }
  }

  return { transaction, refetch }
}

export function useSeatUpdate(chamberAddress: `0x${string}` | undefined) {
  const { data, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getSeatUpdate',
    query: { enabled: !!chamberAddress },
  })

  let seatUpdate: SeatUpdate | undefined
  if (data) {
    const [proposedSeats, timestamp, requiredQuorum, supporters] = data as [bigint, bigint, bigint, bigint[]]
    seatUpdate = {
      proposedSeats,
      timestamp,
      requiredQuorum,
      supporters,
    }
  }

  return { seatUpdate, refetch }
}

/**
 * Token IDs of membership NFTs held by `ownerAddress`.
 * Enumerable is the fast path; non-enumerable 721s (Sepolia EXPLORERS) use
 * `ownerOf` / Alchemy / Transfer logs — see `listOwnedErc721TokenIds`.
 */
export function useUserNFTs(
  nftAddress: `0x${string}` | undefined,
  ownerAddress: `0x${string}` | undefined,
  opts?: { chamberAddress?: `0x${string}` }
) {
  const publicClient = usePublicClient()
  const chainId = useChainId()
  const alchemyApiKey = getAlchemyApiKeyFromEnv()
  const chamberScope = (opts?.chamberAddress ?? '').toLowerCase()

  const { data: balance, isPending: balancePending, refetch: refetchBalance } = useReadContract({
    address: nftAddress,
    abi: erc721Abi,
    functionName: 'balanceOf',
    args: ownerAddress ? [ownerAddress] : undefined,
    query: {
      enabled: !!nftAddress && !!ownerAddress,
      staleTime: 0,
      refetchOnMount: true,
    },
  })

  const balanceKnown = balance !== undefined
  const hasNfts = !!balance && balance > 0n

  const listQuery = useQuery({
    queryKey: [
      'user-nfts',
      nftAddress?.toLowerCase() ?? '',
      ownerAddress?.toLowerCase() ?? '',
      chamberScope,
      balance?.toString() ?? '',
      chainId,
    ],
    enabled: !!publicClient && !!nftAddress && !!ownerAddress && hasNfts,
    staleTime: 15_000,
    refetchOnMount: 'always',
    retry: 2,
    retryDelay: (attemptIndex) => Math.min(1500 * 2 ** attemptIndex, 12_000),
    queryFn: () =>
      listOwnedErc721TokenIds({
        client: publicClient!,
        nft: nftAddress!,
        owner: ownerAddress!,
        expectedBalance: balance,
        chainId,
        alchemyApiKey,
      }),
  })

  const tokenIds = useMemo(() => {
    if (!hasNfts) return [] as bigint[]
    return listQuery.data ?? []
  }, [hasNfts, listQuery.data])

  const isLoading =
    (!!nftAddress && !!ownerAddress && (balancePending || !balanceKnown)) ||
    (hasNfts && (listQuery.isPending || listQuery.isFetching) && tokenIds.length === 0)

  return {
    tokenIds,
    balance: balance ?? 0n,
    isLoading,
    refetch: async () => {
      await refetchBalance()
      return listQuery.refetch()
    },
  }
}

export function useDelegations(chamberAddress: `0x${string}` | undefined, account: `0x${string}` | undefined) {
  const { data, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getDelegations',
    args: account ? [account] : undefined,
    query: { enabled: !!chamberAddress && !!account },
  })

  const delegations: { tokenId: bigint; amount: bigint }[] = []
  if (data) {
    const [tokenIds, amounts] = data as [bigint[], bigint[]]
    for (let i = 0; i < tokenIds.length; i++) {
      delegations.push({
        tokenId: tokenIds[i],
        amount: amounts[i],
      })
    }
  }

  return { delegations, refetch }
}

// Write hooks
export function useSubmitTransaction(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const submit = async (
    tokenId: bigint,
    target: `0x${string}`,
    value: bigint,
    data: `0x${string}`,
    metadataURI?: string
  ) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: metadataURI ? 'submitTransactionWithMetadata' : 'submitTransaction',
      args: metadataURI ? [tokenId, target, value, data, metadataURI] : [tokenId, target, value, data],
    })
  }

  return { submit, isPending, isConfirming, isSuccess, error, hash }
}

export function useSubmitBatchTransactions(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const submitBatch = async (tokenId: bigint, targets: `0x${string}`[], values: bigint[], data: `0x${string}`[]) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'submitBatchTransactions',
      args: [tokenId, targets, values, data],
    })
  }

  return { submitBatch, isPending, isConfirming, isSuccess, error, hash }
}

export function useConfirmTransaction(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const confirm = async (tokenId: bigint, transactionId: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'confirmTransaction',
      args: [tokenId, transactionId],
    })
  }

  return { confirm, isPending, isConfirming, isSuccess, error, hash }
}

export function useExecuteTransaction(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const execute = async (tokenId: bigint, transactionId: bigint, calldata: `0x${string}` = '0x') => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'executeTransaction',
      args: [tokenId, transactionId, calldata],
    })
  }

  return { execute, isPending, isConfirming, isSuccess, error, hash }
}

export function useRevokeConfirmation(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const revoke = async (tokenId: bigint, transactionId: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'revokeConfirmation',
      args: [tokenId, transactionId],
    })
  }

  return { revoke, isPending, isConfirming, isSuccess, error, hash }
}

export function useCancelTransaction(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const cancel = async (tokenId: bigint, transactionId: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'cancelTransaction',
      args: [tokenId, transactionId],
    })
  }

  return { cancel, isPending, isConfirming, isSuccess, error, hash }
}

export function useTransactionConfirmation(
  chamberAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
  transactionId: number | undefined
) {
  const { data: isConfirmed } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getConfirmation',
    args: tokenId !== undefined && transactionId !== undefined ? [tokenId, BigInt(transactionId)] : undefined,
    query: {
      enabled: !!chamberAddress && tokenId !== undefined && transactionId !== undefined,
    },
  })

  return { isConfirmed: isConfirmed as boolean | undefined }
}

export function useTransactionCancelConfirmation(
  chamberAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
  transactionId: number | undefined
) {
  const { data: hasVotedToCancel } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getCancelConfirmation',
    args: tokenId !== undefined && transactionId !== undefined ? [tokenId, BigInt(transactionId)] : undefined,
    query: {
      enabled: !!chamberAddress && tokenId !== undefined && transactionId !== undefined,
    },
  })

  return { hasVotedToCancel: hasVotedToCancel as boolean | undefined }
}

/**
 * Hook for delegating shares to an NFT token ID.
 * Uses simulation to validate the transaction before sending.
 */
export function useDelegate(chamberAddress: `0x${string}` | undefined) {
  const { address: userAddress } = useAccount()
  const { writeContractAsync, data: hash, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const delegate = async (tokenId: bigint, amount: bigint) => {
    if (!chamberAddress || !userAddress) {
      throw new Error('Chamber address or user address not available')
    }
    
    // The writeContractAsync will automatically simulate before sending
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'delegate',
      args: [tokenId, amount],
    })
  }

  return { delegate, isPending, isConfirming, isSuccess, error: writeError, hash }
}

/**
 * Hook for simulating a delegate call to check if it will succeed.
 * Use this to show validation errors before the user clicks submit.
 */
export function useSimulateDelegate(
  chamberAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
  amount: bigint | undefined,
  opts?: SimulateQueryOpts
) {
  const { address: userAddress } = useAccount()
  const queryEnabled = opts?.queryEnabled !== false

  const { data, error, isLoading, refetch } = useSimulateContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'delegate',
    args: tokenId !== undefined && amount !== undefined ? [tokenId, amount] : undefined,
    query: {
      enabled:
        queryEnabled &&
        !!chamberAddress &&
        !!userAddress &&
        tokenId !== undefined &&
        amount !== undefined &&
        amount > 0n,
      ...SLOW_CHAIN_SIMULATE_QUERY,
    },
  })

  return {
    isValid: !!data && !error,
    error,
    isLoading,
    refetch,
  }
}

/**
 * Hook for undelegating shares from an NFT token ID.
 * Uses simulation to validate the transaction before sending.
 */
export function useUndelegate(chamberAddress: `0x${string}` | undefined) {
  const { address: userAddress } = useAccount()
  const { writeContractAsync, data: hash, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const undelegate = async (tokenId: bigint, amount: bigint) => {
    if (!chamberAddress || !userAddress) {
      throw new Error('Chamber address or user address not available')
    }
    
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'undelegate',
      args: [tokenId, amount],
    })
  }

  return { undelegate, isPending, isConfirming, isSuccess, error: writeError, hash }
}

/**
 * Hook for simulating an undelegate call to check if it will succeed.
 */
export function useSimulateUndelegate(
  chamberAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
  amount: bigint | undefined,
  opts?: SimulateQueryOpts
) {
  const { address: userAddress } = useAccount()
  const queryEnabled = opts?.queryEnabled !== false

  const { data, error, isLoading, refetch } = useSimulateContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'undelegate',
    args: tokenId !== undefined && amount !== undefined ? [tokenId, amount] : undefined,
    query: {
      enabled:
        queryEnabled &&
        !!chamberAddress &&
        !!userAddress &&
        tokenId !== undefined &&
        amount !== undefined &&
        amount > 0n,
      ...SLOW_CHAIN_SIMULATE_QUERY,
    },
  })

  return {
    isValid: !!data && !error,
    error,
    isLoading,
    refetch,
  }
}

/**
 * Hook for depositing assets into the chamber.
 * Uses simulation to validate the transaction before sending.
 */
export function useDeposit(chamberAddress: `0x${string}` | undefined) {
  const { address: userAddress } = useAccount()
  const { writeContractAsync, data: hash, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const deposit = async (assets: bigint, receiver: `0x${string}`) => {
    if (!chamberAddress || !userAddress) {
      throw new Error('Chamber address or user address not available')
    }
    
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'deposit',
      args: [assets, receiver],
    })
  }

  return { deposit, isPending, isConfirming, isSuccess, error: writeError, hash }
}

/**
 * Hook for simulating a deposit call to check if it will succeed.
 */
export function useSimulateDeposit(
  chamberAddress: `0x${string}` | undefined,
  assets: bigint | undefined,
  receiver: `0x${string}` | undefined,
  opts?: SimulateQueryOpts
) {
  const { address: userAddress } = useAccount()
  const queryEnabled = opts?.queryEnabled !== false

  const { data, error, isLoading, refetch } = useSimulateContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'deposit',
    args: assets !== undefined && receiver ? [assets, receiver] : undefined,
    query: {
      enabled:
        queryEnabled &&
        !!chamberAddress &&
        !!userAddress &&
        assets !== undefined &&
        assets > 0n &&
        !!receiver,
      ...SLOW_CHAIN_SIMULATE_QUERY,
    },
  })

  return {
    isValid: !!data && !error,
    error,
    isLoading,
    refetch,
  }
}

/**
 * Hook for withdrawing assets from the chamber.
 * Uses simulation to validate the transaction before sending.
 */
export function useWithdraw(chamberAddress: `0x${string}` | undefined) {
  const { address: userAddress } = useAccount()
  const { writeContractAsync, data: hash, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const withdraw = async (assets: bigint, receiver: `0x${string}`, owner: `0x${string}`) => {
    if (!chamberAddress || !userAddress) {
      throw new Error('Chamber address or user address not available')
    }
    
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'withdraw',
      args: [assets, receiver, owner],
    })
  }

  return { withdraw, isPending, isConfirming, isSuccess, error: writeError, hash }
}

/**
 * Hook for simulating a withdraw call to check if it will succeed.
 */
export function useSimulateWithdraw(
  chamberAddress: `0x${string}` | undefined,
  assets: bigint | undefined,
  receiver: `0x${string}` | undefined,
  owner: `0x${string}` | undefined,
  opts?: SimulateQueryOpts
) {
  const { address: userAddress } = useAccount()
  const queryEnabled = opts?.queryEnabled !== false

  const { data, error, isLoading, refetch } = useSimulateContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'withdraw',
    args: assets !== undefined && receiver && owner ? [assets, receiver, owner] : undefined,
    query: {
      enabled:
        queryEnabled &&
        !!chamberAddress &&
        !!userAddress &&
        assets !== undefined &&
        assets > 0n &&
        !!receiver &&
        !!owner,
      ...SLOW_CHAIN_SIMULATE_QUERY,
    },
  })

  return {
    isValid: !!data && !error,
    error,
    isLoading,
    refetch,
  }
}

export function useUpdateSeats(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const updateSeats = async (tokenId: bigint, numOfSeats: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'updateSeats',
      args: [tokenId, numOfSeats],
    })
  }

  return { updateSeats, isPending, isConfirming, isSuccess, error, hash }
}

export function useExecuteSeatsUpdate(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const executeSeatsUpdate = async (tokenId: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'executeSeatsUpdate',
      args: [tokenId],
    })
  }

  return { executeSeatsUpdate, isPending, isConfirming, isSuccess, error, hash }
}

export function useCancelSeatUpdate(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const cancelSeatUpdate = async (tokenId: bigint) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'cancelSeatUpdate',
      args: [tokenId],
    })
  }

  return { cancelSeatUpdate, isPending, isConfirming, isSuccess, error, hash }
}

/**
 * Live session key for `tokenId`, or zero if unset / stale / EOA-owned.
 */
export function useDirectorOperator(
  chamberAddress: `0x${string}` | undefined,
  tokenId: bigint | undefined,
) {
  const { data, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getDirectorOperator',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: !!chamberAddress && tokenId !== undefined,
      staleTime: 0,
      retry: false,
    },
  })

  const operator = data as `0x${string}` | undefined
  const isSet = !!operator && operator !== zeroAddress

  return { operator, isSet, refetch }
}

/**
 * `address.code.length > 0` for the connected (or given) account.
 * Protocol rejects `setDirectorOperator` for EOA-owned NFTs.
 */
export function useIsContractAccount(account: `0x${string}` | undefined) {
  const publicClient = usePublicClient()
  const chainId = useChainId()

  const { data: bytecode, isFetched, isFetching } = useQuery({
    queryKey: ['account-bytecode', chainId, account?.toLowerCase() ?? ''],
    enabled: !!publicClient && !!account,
    staleTime: 15_000,
    queryFn: async () => {
      const code = await publicClient!.getBytecode({ address: account! })
      return (code ?? '0x') as `0x${string}`
    },
  })

  return {
    isContract: isOnchainContractBytecode(bytecode),
    bytecode,
    isFetched,
    isFetching,
  }
}

/**
 * Register or clear the session key for a contract-owned membership NFT.
 * Pass `address(0)` to clear. Never consults ERC-1271.
 */
export function useSetDirectorOperator(chamberAddress: `0x${string}` | undefined) {
  const { writeContractAsync, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const setDirectorOperator = async (tokenId: bigint, operator: `0x${string}`) => {
    if (!chamberAddress) return
    return writeContractAsync({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'setDirectorOperator',
      args: [tokenId, operator],
    })
  }

  const clearDirectorOperator = async (tokenId: bigint) => {
    return setDirectorOperator(tokenId, zeroAddress)
  }

  return { setDirectorOperator, clearDirectorOperator, isPending, isConfirming, isSuccess, error, hash }
}

export function useSeatedAt(chamberAddress: `0x${string}` | undefined, tokenId: bigint | undefined) {
  const { data, refetch } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getSeatedAt',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: {
      enabled: !!chamberAddress && tokenId !== undefined,
      retry: false,
    },
  })

  return { seatedAt: data as bigint | undefined, refetch }
}

export type DirectorCallerRole = 'owner' | 'operator'

/**
 * Combined director action gate (H-02): connected address is the NFT owner
 * of a current top-seat tokenId, or the Chamber-registered session key for
 * that token, AND seating is mature (`block.number >= seatedAt`).
 * If `getSeatedAt` is not deployed yet, treat the seat as mature.
 */
export function useDirectorActionGate(
  chamberAddress: `0x${string}` | undefined,
  userAddress: `0x${string}` | undefined,
  directors: `0x${string}`[] | undefined,
  members: { tokenId: bigint }[],
) {
  const ownerIndex =
    userAddress && directors
      ? directors.findIndex((d) => d.toLowerCase() === userAddress.toLowerCase())
      : -1
  const ownerTokenId =
    ownerIndex >= 0 && ownerIndex < members.length ? members[ownerIndex].tokenId : undefined
  const ownerAddress =
    ownerIndex >= 0 && directors ? directors[ownerIndex] : undefined

  const directorCount = directors?.length ?? 0
  const seatedMembers = useMemo(
    () => members.slice(0, directorCount),
    [members, directorCount],
  )
  const memberTokenKey = seatedMembers.map((m) => m.tokenId.toString()).join(',')
  const memberTokenIds = useMemo(
    () => (memberTokenKey ? memberTokenKey.split(',').map((id) => BigInt(id)) : []),
    [memberTokenKey],
  )

  const { data: operatorResults } = useReadContracts({
    contracts: memberTokenIds.map((tokenId) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getDirectorOperator' as const,
      args: [tokenId] as const,
    })),
    query: {
      enabled:
        !!chamberAddress &&
        !!userAddress &&
        memberTokenIds.length > 0,
      retry: false,
    },
  })

  let operatorTokenId: bigint | undefined
  let operatorOwner: `0x${string}` | undefined
  let sessionOperator: `0x${string}` | undefined
  if (userAddress && operatorResults && directors) {
    for (let i = 0; i < operatorResults.length; i++) {
      const result = operatorResults[i]
      if (result.status !== 'success' || typeof result.result !== 'string') continue
      const op = result.result as `0x${string}`
      if (!op || op === zeroAddress) continue

      if (ownerTokenId !== undefined && memberTokenIds[i] === ownerTokenId) {
        sessionOperator = op
      } else if (
        ownerTokenId === undefined &&
        op.toLowerCase() === userAddress.toLowerCase()
      ) {
        operatorTokenId = memberTokenIds[i]
        operatorOwner = directors[i]
      }
    }
  }

  const tokenId = ownerTokenId ?? operatorTokenId
  const role: DirectorCallerRole | null =
    ownerTokenId !== undefined ? 'owner' : operatorTokenId !== undefined ? 'operator' : null
  const nftOwner = ownerAddress ?? operatorOwner

  const { seatedAt } = useSeatedAt(chamberAddress, tokenId)
  const { data: blockNumber } = useBlockNumber({
    query: {
      enabled: !!chamberAddress && tokenId !== undefined,
      refetchInterval: 4_000,
    },
  })

  const getterMissing = tokenId !== undefined && seatedAt === undefined
  const seated = tokenId === undefined ? false : getterMissing ? true : isSeatingMature(seatedAt, blockNumber)
  const seatingPending = tokenId !== undefined && !getterMissing && !seated

  return {
    tokenId,
    seatedAt,
    blockNumber,
    canAct: tokenId !== undefined && seated,
    seatingPending,
    role,
    nftOwner,
    sessionOperator,
  }
}
