import { useAccount, useChainId } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { zeroAddress } from 'viem'
import { useBoardMembers, useChamberBalance, useDelegations, useUserNFTs } from './useChamber'
import { getContractAddresses, LOCAL_CHAIN_ID } from '@/lib/wagmi'

export type SeatTheBoardAction = 'mint' | 'receive' | 'deposit' | 'delegate'

function canMintMembershipNft(
  nftToken: `0x${string}` | undefined,
  chainId: number | undefined,
): boolean {
  if (!nftToken || nftToken === zeroAddress || typeof chainId !== 'number') return false
  const onLocal = chainId === LOCAL_CHAIN_ID
  const onSepolia = chainId === sepolia.id
  if (!onLocal && !onSepolia) return false
  const mockNft = getContractAddresses(chainId)?.mockERC721
  return !!mockNft && mockNft !== zeroAddress && mockNft.toLowerCase() === nftToken.toLowerCase()
}

export function seatTheBoardHref(
  chamberAddress: `0x${string}`,
  action: SeatTheBoardAction,
  tokenId?: bigint,
): string {
  if (action === 'deposit') return `/chamber/${chamberAddress}/staking`
  if (action === 'mint') return `/chamber/${chamberAddress}`
  const q = tokenId !== undefined ? `?tokenId=${tokenId.toString()}` : ''
  return `/chamber/${chamberAddress}/delegation${q}`
}

/** Next seating step: mint | receive | deposit | delegate. Shared by all seat-the-board CTAs. */
export function useSeatTheBoard(
  chamberAddress: `0x${string}`,
  nftToken?: `0x${string}`,
) {
  const { address: userAddress } = useAccount()
  const chainId = useChainId()
  const nft = nftToken && nftToken !== zeroAddress ? nftToken : undefined

  const { members, isPending, isFetched, refetch: refetchBoard } = useBoardMembers(chamberAddress, 1)
  const { tokenIds, balance: nftBalance, isLoading: nftsLoading, refetch: refetchNfts } = useUserNFTs(
    nft,
    userAddress,
    { chamberAddress },
  )
  const { balance: shareBalance, refetch: refetchShares } = useChamberBalance(chamberAddress, userAddress)
  const { delegations, refetch: refetchDelegations } = useDelegations(chamberAddress, userAddress)

  const boardKnownEmpty = isFetched && !isPending && members.length === 0
  const boardHasDirectors = members.length > 0
  const holdsNft = tokenIds.length > 0 || (nftBalance !== undefined && nftBalance > 0n)
  const hasShares = shareBalance !== undefined && shareBalance > 0n
  const hasDelegated = delegations.some((d) => d.amount > 0n)
  const mintAvailable = canMintMembershipNft(nft, chainId)
  const firstTokenId = tokenIds[0]

  const nextAction: SeatTheBoardAction = !holdsNft
    ? mintAvailable
      ? 'mint'
      : 'receive'
    : !hasShares
      ? 'deposit'
      : 'delegate'

  return {
    nextAction,
    href: seatTheBoardHref(chamberAddress, nextAction, firstTokenId),
    holdsNft,
    hasShares,
    hasDelegated,
    mintAvailable,
    firstTokenId,
    nftsLoading,
    userAddress,
    chainId,
    nft,
    boardKnownEmpty,
    boardHasDirectors,
    refetchNfts,
    refetchBoard,
    refetchShares,
    refetchDelegations,
  }
}
