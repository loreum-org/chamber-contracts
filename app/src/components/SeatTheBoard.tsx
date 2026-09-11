import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useAccount, useChainId, useWriteContract } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { simulateContract } from 'wagmi/actions'
import { zeroAddress } from 'viem'
import { FiArrowRight, FiCheck, FiLoader, FiUsers } from 'react-icons/fi'
import toast from 'react-hot-toast'
import { useBoardMembers, useChamberBalance, useUserNFTs } from '@/hooks'
import { config, getContractAddresses, LOCAL_CHAIN_ID } from '@/lib/wagmi'
import { formatLocalTestMintToast, formatWalletSendError } from '@/lib/utils'
import { SEATING_DELAY_BLOCKS } from '@/lib/chamberGovernance'
import { erc721Abi } from '@/contracts'

type NextAction = 'mint' | 'receive' | 'deposit' | 'delegate'

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

export default function SeatTheBoard({
  chamberAddress,
  nftToken,
  assumeEmpty = false,
}: {
  chamberAddress: `0x${string}`
  nftToken?: `0x${string}`
  /** Deploy-success: treat as empty until `getTop` returns members. */
  assumeEmpty?: boolean
}) {
  const { address: userAddress } = useAccount()
  const chainId = useChainId()
  const { writeContractAsync } = useWriteContract()
  const [minting, setMinting] = useState(false)

  const { members, isPending, isFetched, refetch: refetchBoard } = useBoardMembers(chamberAddress, 1)
  const { tokenIds, balance: nftBalance, isLoading: nftsLoading, refetch: refetchNfts } = useUserNFTs(
    nftToken,
    userAddress,
    { chamberAddress },
  )
  const { balance: shareBalance, refetch: refetchShares } = useChamberBalance(chamberAddress, userAddress)

  const boardKnownEmpty = isFetched && !isPending && members.length === 0
  const boardHasDirectors = members.length > 0
  const showPanel = assumeEmpty ? !boardHasDirectors : boardKnownEmpty

  const holdsNft = tokenIds.length > 0 || (nftBalance !== undefined && nftBalance > 0n)
  const hasShares = shareBalance !== undefined && shareBalance > 0n
  const mintAvailable = canMintMembershipNft(nftToken, chainId)
  const firstTokenId = tokenIds[0]

  const nextAction: NextAction = !holdsNft
    ? mintAvailable
      ? 'mint'
      : 'receive'
    : !hasShares
      ? 'deposit'
      : 'delegate'

  const delegationHref = firstTokenId
    ? `/chamber/${chamberAddress}/delegation?tokenId=${firstTokenId.toString()}`
    : `/chamber/${chamberAddress}/delegation`
  const stakingHref = `/chamber/${chamberAddress}/staking`

  const handleMintFounderNft = async () => {
    if (!userAddress || !nftToken || nftToken === zeroAddress) return
    setMinting(true)
    try {
      const { request } = await simulateContract(config, {
        address: nftToken,
        abi: erc721Abi,
        functionName: 'mint',
        args: [userAddress],
        chainId,
        account: userAddress,
      })
      await writeContractAsync(request)
      toast.success('Founder membership token minted. Deposit shares, then delegate to seat the board.')
      void refetchNfts()
      void refetchBoard()
      void refetchShares()
    } catch (e: unknown) {
      toast.error(
        chainId === LOCAL_CHAIN_ID
          ? formatLocalTestMintToast(e)
          : formatWalletSendError(e, 'Mint failed'),
      )
    } finally {
      setMinting(false)
    }
  }

  if (!showPanel) return null

  const nextCopy: Record<NextAction, { detail: string; cta: string }> = {
    mint: {
      detail: 'Mint a founder membership token on this test collection, then deposit and delegate to it.',
      cta: 'Mint founder NFT',
    },
    receive: {
      detail:
        'Receive a membership token from this collection, or use a token ID you already hold. Deploy does not mint or seat anyone.',
      cta: 'Open chamber',
    },
    deposit: {
      detail: 'You hold a membership token. Deposit vault assets so you have shares to delegate.',
      cta: 'Deposit shares',
    },
    delegate: {
      detail: `Delegate shares to a token you hold. Director rights unlock after ${SEATING_DELAY_BLOCKS.toString()} block (SEATING_DELAY).`,
      cta: 'Delegate to seat',
    },
  }

  const copy = nextCopy[nextAction]
  const primaryHref =
    nextAction === 'deposit' ? stakingHref : nextAction === 'delegate' || nextAction === 'receive' ? delegationHref : undefined

  return (
    <div className="panel p-6 sm:p-8 space-y-5 border-accent-500/25 bg-accent-500/[0.04]">
      <div className="flex items-start gap-3">
        <div className="w-11 h-11 rounded-xl bg-accent-500/15 flex items-center justify-center shrink-0">
          <FiUsers className="w-5 h-5 text-accent-400" />
        </div>
        <div className="min-w-0">
          <h3 className="font-heading text-xl font-bold text-slate-100">Seat the board</h3>
          <p className="text-slate-400 text-sm mt-1 leading-relaxed">
            This chamber has no directors. Submit, confirm, and execute stay locked until a membership token
            receives delegation and seating matures.
          </p>
          <Link
            to="/docs/introduction/getting-started"
            className="text-accent-400 text-sm hover:underline mt-2 inline-block"
          >
            Getting started →
          </Link>
        </div>
      </div>

      <ol className="space-y-2 text-sm">
        <Step done={holdsNft} loading={!!userAddress && nftsLoading && !holdsNft} label="Hold a membership token" />
        <Step done={hasShares} label="Deposit shares" />
        <Step done={false} label={`Delegate, then wait ${SEATING_DELAY_BLOCKS.toString()} block`} />
      </ol>

      <p className="text-slate-400 text-sm leading-relaxed">{copy.detail}</p>

      <div className="flex flex-wrap gap-3">
        {nextAction === 'mint' ? (
          <button
            type="button"
            onClick={() => void handleMintFounderNft()}
            disabled={minting || !userAddress}
            className="btn btn-primary"
          >
            {minting ? <FiLoader className="w-4 h-4 animate-spin" /> : <FiUsers className="w-4 h-4" />}
            {minting ? 'Minting…' : 'Seat the board'}
          </button>
        ) : (
          <Link to={primaryHref ?? `/chamber/${chamberAddress}`} className="btn btn-primary">
            Seat the board
            <FiArrowRight className="w-4 h-4" />
          </Link>
        )}
        {nextAction === 'mint' && (
          <Link to={delegationHref} className="btn btn-secondary">
            I already hold a token
          </Link>
        )}
        {nextAction !== 'mint' && nextAction !== 'receive' && (
          <span className="self-center text-slate-500 text-xs">{copy.cta}</span>
        )}
      </div>
    </div>
  )
}

function Step({ done, loading, label }: { done: boolean; loading?: boolean; label: string }) {
  return (
    <li className="flex items-center gap-2 text-slate-300">
      {loading ? (
        <FiLoader className="w-3.5 h-3.5 text-slate-500 animate-spin shrink-0" />
      ) : done ? (
        <FiCheck className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
      ) : (
        <span className="w-3.5 h-3.5 rounded-full border border-slate-600 shrink-0" />
      )}
      <span className={done ? 'text-slate-400' : ''}>{label}</span>
    </li>
  )
}
