import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { useWriteContract } from 'wagmi'
import { simulateContract } from 'wagmi/actions'
import { zeroAddress } from 'viem'
import { FiArrowRight, FiCheck, FiLoader, FiUsers } from 'react-icons/fi'
import toast from 'react-hot-toast'
import { seatTheBoardHref, useSeatTheBoard, type SeatTheBoardAction } from '@/hooks'
import { config, LOCAL_CHAIN_ID } from '@/lib/wagmi'
import { formatLocalTestMintToast, formatWalletSendError } from '@/lib/utils'
import { SEATING_DELAY_BLOCKS } from '@/lib/chamberGovernance'
import { erc721Abi } from '@/contracts'

/** Routes a seat-the-board CTA to the derived next step (not a blind /delegation link). */
export function SeatTheBoardLink({
  chamberAddress,
  nftToken,
  className,
  children,
}: {
  chamberAddress: `0x${string}`
  nftToken?: `0x${string}`
  className?: string
  children: ReactNode
}) {
  const { href } = useSeatTheBoard(chamberAddress, nftToken)
  return (
    <Link to={href} className={className}>
      {children}
    </Link>
  )
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
  const { writeContractAsync } = useWriteContract()
  const [minting, setMinting] = useState(false)
  const {
    nextAction,
    href,
    holdsNft,
    hasShares,
    hasDelegated,
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
  } = useSeatTheBoard(chamberAddress, nftToken)

  const showPanel = assumeEmpty ? !boardHasDirectors : boardKnownEmpty

  const handleMintFounderNft = async () => {
    if (!userAddress || !nft || nft === zeroAddress) return
    setMinting(true)
    try {
      const { request } = await simulateContract(config, {
        address: nft,
        abi: erc721Abi,
        functionName: 'mint',
        args: [userAddress],
        chainId,
        account: userAddress,
      })
      await writeContractAsync(request)
      toast.success('Founder membership NFT minted. Deposit shares, then delegate to seat the board.')
      void refetchNfts()
      void refetchBoard()
      void refetchShares()
      void refetchDelegations()
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

  const nextCopy: Record<SeatTheBoardAction, { detail: string; cta: string }> = {
    mint: {
      detail: 'Mint a founder membership NFT on this test collection, then deposit and delegate to it.',
      cta: 'Mint founder NFT',
    },
    receive: {
      detail:
        'Receive a membership NFT from this collection, or use a token ID you already hold. Deploy does not mint or seat anyone.',
      cta: 'Open chamber',
    },
    deposit: {
      detail: 'You hold a membership NFT. Deposit vault assets so you have shares to delegate.',
      cta: 'Deposit shares',
    },
    delegate: {
      detail: `Delegate shares to a token you hold. Director rights unlock after ${SEATING_DELAY_BLOCKS.toString()} block (SEATING_DELAY).`,
      cta: 'Delegate to seat',
    },
  }

  const copy = nextCopy[nextAction]

  return (
    <div className="panel p-6 sm:p-8 space-y-5 border-accent-500/25 bg-accent-500/[0.04]">
      <div className="flex items-start gap-3">
        <div className="w-11 h-11 rounded-xl bg-accent-500/15 flex items-center justify-center shrink-0">
          <FiUsers className="w-5 h-5 text-accent-400" />
        </div>
        <div className="min-w-0">
          <h3 className="font-heading text-xl font-bold text-slate-100">Seat the board</h3>
          <p className="text-slate-400 text-sm mt-1 leading-relaxed">
            This chamber has no directors. Submit, confirm, and execute stay locked until a membership NFT
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
        <Step done={holdsNft} loading={!!userAddress && nftsLoading && !holdsNft} label="Hold a membership NFT" />
        <Step done={hasShares} label="Deposit shares" />
        <Step done={hasDelegated} label={`Delegate, then wait ${SEATING_DELAY_BLOCKS.toString()} block`} />
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
            {minting ? 'Minting…' : copy.cta}
          </button>
        ) : (
          <Link to={href} className="btn btn-primary">
            {copy.cta}
            <FiArrowRight className="w-4 h-4" />
          </Link>
        )}
        {nextAction === 'mint' && (
          <Link to={seatTheBoardHref(chamberAddress, 'receive')} className="btn btn-secondary">
            I already hold a token
          </Link>
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
