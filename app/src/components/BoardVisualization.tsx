import { useMemo, useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { FiUser, FiStar, FiAward, FiTrendingUp, FiRefreshCw, FiSearch } from 'react-icons/fi'
import { formatUnits, zeroAddress } from 'viem'
import type { BoardMember, Delegation } from '@/types'
import { useNftImageMap } from '@/hooks'
import { NftRetryableImage } from '@/components/NftRetryableImage'

interface BoardVisualizationProps {
  chamberAddress: `0x${string}`
  /** Membership NFT; used to load token URI → metadata image */
  nftToken?: `0x${string}`
  members: BoardMember[]
  seats: number
  totalDelegated: bigint
  /** While ERC721 owners are resolving */
  ownersLoading?: boolean
  delegations?: Delegation[]
  boardMembersFetched?: boolean
  boardMembersPending?: boolean
  onRefreshBoard?: () => void
}

function formatDirectorWallet(
  owner: `0x${string}` | undefined,
  loading: boolean
): string {
  if (loading) return 'Loading wallet…'
  if (!owner || owner === zeroAddress) return 'Director wallet unavailable'
  return `${owner.slice(0, 6)}…${owner.slice(-4)}`
}

function PodiumNftThumb({ url, skeleton }: { url?: string; skeleton: boolean }) {
  const [dead, setDead] = useState(false)
  useEffect(() => setDead(false), [url])
  const show = !!(url && !dead)
  if (show) {
    return (
      <NftRetryableImage
        src={url}
        alt=""
        className="w-full h-full object-cover"
        onLoadFailed={() => setDead(true)}
      />
    )
  }
  if (skeleton) {
    return <div className="w-full h-full animate-pulse bg-slate-600/60" aria-hidden />
  }
  return (
    <div className="w-full h-full flex items-center justify-center bg-accent-500/20">
      <FiUser className="w-4 h-4 text-accent-300" />
    </div>
  )
}

export default function BoardVisualization({
  chamberAddress,
  nftToken,
  members,
  seats,
  totalDelegated,
  ownersLoading = false,
  delegations = [],
  boardMembersFetched = false,
  boardMembersPending = false,
  onRefreshBoard,
}: BoardVisualizationProps) {
  const filledSeatCount = members.filter((_, i) => i < seats).length
  const userHasActiveDelegation = delegations.some((d) => d.amount > 0n)
  const boardDataMissing =
    userHasActiveDelegation &&
    members.length === 0 &&
    boardMembersFetched &&
    !boardMembersPending

  const memberTokenIds = useMemo(() => members.map((m) => m.tokenId), [members])
  const { data: memberImages, resolvingImages } = useNftImageMap(
    nftToken && nftToken !== zeroAddress ? nftToken : undefined,
    memberTokenIds,
    { chamberAddress }
  )

  const nftMetaLoading =
    !!nftToken && nftToken !== zeroAddress && resolvingImages

  const seatedMembers = useMemo(
    () => members.slice(0, Math.min(seats, members.length)),
    [members, seats]
  )

  const podiumAvatars = useMemo(() => {
    if (seatedMembers.length === 0) return []
    const n = Math.min(filledSeatCount, seatedMembers.length, 4)
    return seatedMembers.slice(0, n)
  }, [seatedMembers, filledSeatCount])

  return (
    <div className="space-y-6">
      {boardDataMissing && (
        <div className="panel p-4 flex flex-col sm:flex-row sm:items-center gap-3 justify-between border-accent-500/20 bg-accent-500/5">
          <p className="text-sm text-slate-300">
            Your delegation is onchain, but the ranked board hasn&apos;t loaded yet (or the indexer is behind).
            Refresh after the transaction confirms.
          </p>
          {onRefreshBoard && (
            <button
              type="button"
              onClick={() => onRefreshBoard()}
              className="btn btn-secondary inline-flex shrink-0 text-sm px-4 py-2"
            >
              <FiRefreshCw className="w-4 h-4" />
              Refresh board
            </button>
          )}
        </div>
      )}
      {/* Board Visualization */}
      <div className="relative panel p-8 overflow-hidden">
        {/* Background decoration */}
        <div className="absolute inset-0 bg-mesh-gradient pointer-events-none" />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-2xl">
          <div className="h-px bg-gradient-to-r from-transparent via-accent-500/50 to-transparent" />
        </div>
        
        {/* Header */}
        <div className="text-center mb-8">
          <h3 className="font-heading text-2xl font-bold text-slate-100 mb-2 tracking-tight">
            Board of Directors
          </h3>
          <p className="text-slate-400 text-sm">
            {seats} seats • {filledSeatCount} filled • Directors are the top {seats} members by delegated shares. Ranking changes the moment delegation changes.
          </p>
        </div>

        {/* Board Layout: semi-circle for ≤8 seats; single scrollable row for 9–20 */}
        {seats <= 8 ? (
          <div className="relative h-[320px] max-w-3xl mx-auto">
            {/* Center podium */}
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-24 h-16 bg-gradient-to-t from-accent-500/20 to-accent-500/5 rounded-t-full border-t border-l border-r border-accent-500/30">
              <div className="absolute -top-3 left-1/2 -translate-x-1/2 flex flex-row-reverse justify-center items-center">
                {podiumAvatars.length > 0 ? (
                  podiumAvatars.map((m, i) => {
                    const url = memberImages?.get(m.tokenId.toString())
                    const skeleton = nftMetaLoading && !url
                    return (
                      <div
                        key={m.tokenId.toString()}
                        className={`ring-2 ring-slate-900 rounded-full shrink-0 w-9 h-9 overflow-hidden bg-slate-800 ${
                          i > 0 ? 'mr-[-10px]' : ''
                        }`}
                        style={{ zIndex: podiumAvatars.length - i }}
                      >
                        <PodiumNftThumb url={url} skeleton={skeleton} />
                      </div>
                    )
                  })
                ) : (
                  <FiAward className="w-6 h-6 text-accent-400 shrink-0" />
                )}
              </div>
            </div>

            {Array.from({ length: seats }).map((_, index) => {
              const member = members[index]
              const isDirector = index < seats && !!member
              const angle = 180 - (180 / (seats + 1)) * (index + 1)
              const radius = 140
              const x = Math.cos((angle * Math.PI) / 180) * radius
              const y = Math.sin((angle * Math.PI) / 180) * radius * 0.7

              return (
                <motion.div
                  key={index}
                  initial={{ opacity: 0, scale: 0 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: index * 0.1, type: 'spring', bounce: 0.4 }}
                  className="absolute"
                  style={{
                    left: `calc(50% + ${x}px)`,
                    bottom: `${60 + y}px`,
                    transform: 'translate(-50%, 0)',
                  }}
                >
                  <SeatCard
                    chamberAddress={chamberAddress}
                    seatNumber={index + 1}
                    member={member}
                    nftImagePending={nftMetaLoading}
                    memberImageUrl={member ? memberImages?.get(member.tokenId.toString()) : undefined}
                    isDirector={isDirector}
                    totalDelegated={totalDelegated}
                    ownersLoading={ownersLoading}
                  />
                </motion.div>
              )
            })}

            {/* Decorative arcs */}
            <svg className="absolute inset-0 w-full h-full pointer-events-none" viewBox="0 0 600 320">
              <path d="M 50 280 Q 300 0 550 280" fill="none" stroke="url(#accentGradient)" strokeWidth="1" strokeDasharray="4 4" opacity="0.3" />
              <path d="M 100 280 Q 300 50 500 280" fill="none" stroke="url(#accentGradient)" strokeWidth="1" strokeDasharray="4 4" opacity="0.2" />
              <defs>
                <linearGradient id="accentGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="transparent" />
                  <stop offset="50%" stopColor="#3b82f6" />
                  <stop offset="100%" stopColor="transparent" />
                </linearGradient>
              </defs>
            </svg>
          </div>
        ) : (
          <div
            className="w-full overflow-x-auto overflow-y-visible py-4 scroll-smooth"
            style={{
              display: 'grid',
              gridTemplateColumns: `repeat(${Math.max(seats, 1)}, minmax(2.25rem, 1fr))`,
              columnGap: 'clamp(0.25rem, 1.2vw, 0.625rem)',
            }}
          >
            {Array.from({ length: seats }).map((_, index) => {
              const member = members[index]
              const isDirector = index < seats && !!member
              return (
                <motion.div
                  key={index}
                  className="min-w-0 flex justify-center"
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: index * 0.04, type: 'spring', bounce: 0.3 }}
                >
                  <SeatCard
                    chamberAddress={chamberAddress}
                    seatNumber={index + 1}
                    member={member}
                    nftImagePending={nftMetaLoading}
                    memberImageUrl={member ? memberImages?.get(member.tokenId.toString()) : undefined}
                    isDirector={isDirector}
                    totalDelegated={totalDelegated}
                    ownersLoading={ownersLoading}
                    fluidWidth
                  />
                </motion.div>
              )
            })}
          </div>
        )}
      </div>

      {/* Member List */}
      <div className="panel">
        <div className="p-4 border-b border-slate-700/30">
          <h4 className="font-heading font-semibold text-slate-100">Leaderboard</h4>
          <p className="text-slate-500 text-xs mt-1">All delegated members ranked by voting power</p>
        </div>
        <div className="divide-y divide-slate-700/30">
          {members.length > 0 ? (
            members.map((member, index) => (
              <MemberRow
                key={member.tokenId.toString()}
                chamberAddress={chamberAddress}
                member={member}
                nftImagePending={nftMetaLoading}
                memberImageUrl={memberImages?.get(member.tokenId.toString())}
                rank={index + 1}
                isDirector={index < seats}
                totalDelegated={totalDelegated}
                ownersLoading={ownersLoading}
              />
            ))
          ) : (
            <div className="p-8 text-center text-slate-500">
              No members have received delegations yet
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

interface SeatCardProps {
  chamberAddress: `0x${string}`
  seatNumber: number
  member?: BoardMember
  nftImagePending?: boolean
  memberImageUrl?: string
  isDirector: boolean
  totalDelegated: bigint
  ownersLoading: boolean
  /** One-row grid (9+ seats): card width tracks column; arc layout uses fixed width */
  fluidWidth?: boolean
}

function SeatCard({
  chamberAddress,
  seatNumber,
  member,
  nftImagePending = false,
  memberImageUrl,
  isDirector,
  totalDelegated,
  ownersLoading,
  fluidWidth = false,
}: SeatCardProps) {
  const [avatarDead, setAvatarDead] = useState(false)
  useEffect(() => setAvatarDead(false), [memberImageUrl])

  const showAvatarUrl = !!(memberImageUrl && !avatarDead)
  // Use bigint arithmetic (basis points) to avoid float precision loss on large balances
  const votingPower = member && totalDelegated > 0n
    ? Number((member.amount * 10000n) / totalDelegated) / 100
    : 0
  const walletLabel =
    member && isDirector ? formatDirectorWallet(member.owner, ownersLoading) : null

  const inner = (
    <motion.div
      whileHover={{ scale: 1.1, y: -5 }}
      className={`
        ${fluidWidth ? 'w-full max-w-[4rem] min-w-[2.5rem]' : 'w-16'}
        h-20 rounded-xl flex flex-col items-center justify-center transition-all
        ${isDirector 
          ? 'bg-gradient-to-b from-accent-500/15 to-accent-950/30 border border-accent-500/35 shadow-soft' 
          : 'bg-slate-800/80 border border-slate-700/50'
        }
        ${member ? 'cursor-pointer' : ''}
      `}
    >
      {member ? (
        <>
          <div
            className={`w-11 h-11 rounded-full overflow-hidden flex items-center justify-center mb-1 shrink-0 ring-2 ring-offset-2 ring-offset-slate-900/90
            ${isDirector ? 'ring-accent-500/50 bg-accent-500/20' : 'ring-slate-600/80 bg-slate-700'}`}
          >
            {showAvatarUrl ? (
              <NftRetryableImage
                src={memberImageUrl}
                alt=""
                className="w-full h-full object-cover"
                onLoadFailed={() => setAvatarDead(true)}
              />
            ) : nftImagePending ? (
              <div className="w-full h-full animate-pulse bg-slate-600/70" aria-hidden />
            ) : (
              <FiUser className={`w-5 h-5 ${isDirector ? 'text-accent-400' : 'text-slate-500'}`} />
            )}
          </div>
          <span className="text-xs font-mono text-slate-300">#{member.tokenId.toString()}</span>
          {walletLabel && (
            <span className="text-[9px] text-slate-500 font-mono truncate max-w-[4.5rem] text-center leading-tight">
              {walletLabel}
            </span>
          )}
          <span className="text-[10px] text-slate-500">{votingPower.toFixed(1)}%</span>
        </>
      ) : (
        <>
          <div className="w-8 h-8 rounded-lg bg-slate-800/50 border border-dashed border-slate-600/50 flex items-center justify-center mb-1">
            <span className="text-slate-600 text-xs">{seatNumber}</span>
          </div>
          <span className="text-[10px] text-slate-600">Empty</span>
        </>
      )}
    </motion.div>
  )

  if (member) {
    return (
      <Link to={`/chamber/${chamberAddress}/director/${member.tokenId.toString()}`} title={`View director #${member.tokenId} profile`}>
        {inner}
      </Link>
    )
  }
  return inner
}

interface MemberRowProps {
  chamberAddress: `0x${string}`
  member: BoardMember
  nftImagePending?: boolean
  memberImageUrl?: string
  rank: number
  isDirector: boolean
  totalDelegated: bigint
  ownersLoading: boolean
}

function MemberRow({
  chamberAddress,
  member,
  nftImagePending = false,
  memberImageUrl,
  rank,
  isDirector,
  totalDelegated,
  ownersLoading,
}: MemberRowProps) {
  const [avatarDead, setAvatarDead] = useState(false)
  useEffect(() => setAvatarDead(false), [memberImageUrl])

  const hasAvatar = !!(memberImageUrl && !avatarDead)

  // Use bigint arithmetic (basis points) to avoid float precision loss on large balances
  const votingPower = totalDelegated > 0n
    ? Number((member.amount * 10000n) / totalDelegated) / 100
    : 0
  const barPct = Math.min(100, Math.max(0, votingPower))
  const directorLine = formatDirectorWallet(member.owner, ownersLoading)

  return (
    <div className={`p-4 flex items-center gap-4 ${isDirector ? 'bg-accent-500/5' : ''}`}>
      {/* Rank + NFT thumbnail */}
      <div className="relative w-11 h-11 shrink-0">
        <div
          className={`
          w-full h-full rounded-full overflow-hidden flex items-center justify-center ring-2 ring-offset-2 ring-offset-slate-900
          ${hasAvatar
            ? rank === 1
              ? 'ring-accent-500/55'
              : 'ring-slate-600'
            : rank === 1
              ? 'bg-gradient-to-br from-accent-600 to-accent-800 shadow-sm ring-accent-500/40'
              : rank === 2
                ? 'bg-slate-300 ring-slate-400/50'
                : rank === 3
                  ? 'bg-amber-600 ring-amber-400/40'
                  : 'bg-slate-800 ring-slate-700'}
        `}
        >
          {hasAvatar ? (
            <NftRetryableImage
              src={memberImageUrl}
              alt=""
              className="w-full h-full object-cover"
              onLoadFailed={() => setAvatarDead(true)}
            />
          ) : nftImagePending ? (
            <div className="w-full h-full animate-pulse bg-slate-600/70" aria-hidden />
          ) : (
            <span
              className={`text-xs font-bold ${
                rank === 2 ? 'text-slate-900' : rank >= 4 ? 'text-slate-300' : 'text-white'
              }`}
            >
              {rank}
            </span>
          )}
        </div>
        {hasAvatar ? (
          <span
            className={`
            absolute -bottom-0.5 -right-0.5 min-w-[1.125rem] h-[1.125rem] px-0.5 rounded-full flex items-center justify-center text-[9px] font-bold border border-slate-900 shadow-sm
            ${rank === 1 ? 'bg-accent-600 text-white' : 'bg-slate-800 text-slate-100'}
          `}
          >
            {rank}
          </span>
        ) : null}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-mono text-slate-100">Member #{member.tokenId.toString()}</span>
          {isDirector && (
            <span className="badge badge-primary text-[10px]">
              <FiStar className="w-3 h-3 mr-1" />
              Director
            </span>
          )}
        </div>
        <div className="text-slate-500 text-xs mt-0.5">
          Director wallet: <span className="font-mono text-slate-400">{directorLine}</span>
        </div>
      </div>

      {/* Voting Power */}
      <div className="text-right">
        <div className="font-mono text-slate-100">
          {parseFloat(formatUnits(member.amount, 18)).toFixed(2)}
        </div>
        <div className="text-slate-500 text-xs flex items-center gap-1 justify-end">
          <FiTrendingUp className="w-3 h-3" />
          {votingPower.toFixed(1)}% power
        </div>
      </div>

      {/* Progress bar */}
      <div className="w-24 h-2 bg-slate-800 rounded-full overflow-hidden">
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${barPct}%` }}
          transition={{ duration: 0.5, ease: 'easeOut' }}
          className={`h-full rounded-full ${
            isDirector 
              ? 'bg-gradient-to-r from-accent-500 to-accent-600' 
              : 'bg-slate-600'
          }`}
        />
      </div>

      {/* Audit link */}
      <Link
        to={`/chamber/${chamberAddress}/director/${member.tokenId.toString()}`}
        className="p-1.5 rounded-lg text-slate-600 hover:text-accent-400 hover:bg-accent-500/10 transition-all"
        title="View director profile"
      >
        <FiSearch className="w-3.5 h-3.5" />
      </Link>
    </div>
  )
}
