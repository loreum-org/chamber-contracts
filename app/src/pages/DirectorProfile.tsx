import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useAccount, useReadContract, useReadContracts, useChainId, usePublicClient } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { formatEther, formatUnits, isAddress, parseAbiItem, zeroAddress } from 'viem'
import {
  FiArrowLeft,
  FiShield,
  FiCheckCircle,
  FiPlay,
  FiSend,
  FiXCircle,
  FiRotateCcw,
  FiUsers,
  FiTrendingUp,
  FiDollarSign,
  FiActivity,
  FiExternalLink,
  FiAlertTriangle,
  FiAward,
  FiLayers,
} from 'react-icons/fi'
import { chamberAbi, erc721Abi } from '@/contracts/abis'
import { useChamberInfo, useBoardMembers, useNftTokenImage } from '@/hooks'
import { DirectorOperatorManager } from '@/components/DirectorOperatorManager'
import { getBlockExplorerAddressUrl } from '@/lib/utils'
import { NftRetryableImage } from '@/components/NftRetryableImage'

// Minimal generated-abi event fragments for log queries
const SUBMIT_TX_EVENT = parseAbiItem('event SubmitTransaction(uint256 indexed tokenId, uint256 indexed nonce, address indexed to, uint256 value, bytes data)')
const CONFIRM_TX_EVENT = parseAbiItem('event ConfirmTransaction(uint256 indexed tokenId, uint256 indexed nonce)')
const EXECUTE_TX_EVENT = parseAbiItem('event ExecuteTransaction(uint256 indexed tokenId, uint256 indexed nonce)')
const CANCEL_TX_EVENT = parseAbiItem('event CancelTransaction(uint256 indexed tokenId, uint256 indexed nonce)')
const REVOKE_CONFIRM_EVENT = parseAbiItem('event RevokeConfirmation(uint256 indexed tokenId, uint256 indexed nonce)')

// ─── Hooks ────────────────────────────────────────────────────────────────────

function useDirectorLogs(chamberAddress: `0x${string}`, tokenId: bigint) {
  const publicClient = usePublicClient()

  return useQuery({
    queryKey: ['director-logs', chamberAddress, tokenId.toString()],
    enabled: !!publicClient && !!chamberAddress && tokenId > 0n,
    staleTime: 30_000,
    queryFn: async () => {
      if (!publicClient) return null

      const [submitted, confirmed, executed, cancelled, revoked] = await Promise.all([
        publicClient.getLogs({ address: chamberAddress, event: SUBMIT_TX_EVENT, args: { tokenId }, fromBlock: 0n }),
        publicClient.getLogs({ address: chamberAddress, event: CONFIRM_TX_EVENT, args: { tokenId }, fromBlock: 0n }),
        publicClient.getLogs({ address: chamberAddress, event: EXECUTE_TX_EVENT, args: { tokenId }, fromBlock: 0n }),
        publicClient.getLogs({ address: chamberAddress, event: CANCEL_TX_EVENT, args: { tokenId }, fromBlock: 0n }),
        publicClient.getLogs({ address: chamberAddress, event: REVOKE_CONFIRM_EVENT, args: { tokenId }, fromBlock: 0n }),
      ])

      const totalValueSubmitted = submitted.reduce((acc, log) => acc + (log.args.value ?? 0n), 0n)
      const totalValueExecuted = executed.reduce((acc, log) => {
        const submitLog = submitted.find((s) => s.args.nonce === log.args.nonce)
        return acc + (submitLog?.args.value ?? 0n)
      }, 0n)

      return { submitted, confirmed, executed, cancelled, revoked, totalValueSubmitted, totalValueExecuted }
    },
  })
}

function useDelegationLogs(chamberAddress: `0x${string}`, tokenId: bigint) {
  const publicClient = usePublicClient()
  const DELEGATE_EVENT = parseAbiItem('event DelegationUpdated(address indexed holder, uint256 indexed tokenId, uint256 amount)')

  return useQuery({
    queryKey: ['delegation-logs', chamberAddress, tokenId.toString()],
    enabled: !!publicClient && !!chamberAddress && tokenId > 0n,
    staleTime: 30_000,
    queryFn: async () => {
      if (!publicClient) return []
      const logs = await publicClient.getLogs({ address: chamberAddress, event: DELEGATE_EVENT, args: { tokenId }, fromBlock: 0n })
      return logs
    },
  })
}

// ─── Stat card ────────────────────────────────────────────────────────────────

function StatCard({ icon: Icon, label, value, sub }: {
  icon: React.ElementType
  label: string
  value: string | number
  sub?: string
}) {
  return (
    <div className="stat-card">
      <div className="flex items-center gap-2 text-slate-500 text-xs mb-1.5">
        <Icon className="w-3.5 h-3.5" />
        {label}
      </div>
      <div className="font-heading text-xl font-bold text-slate-100">{value}</div>
      {sub && <div className="text-slate-500 text-xs mt-0.5">{sub}</div>}
    </div>
  )
}

// ─── Activity row ─────────────────────────────────────────────────────────────

function ActivityRow({ action, nonce, detail, href }: {
  action: 'submitted' | 'confirmed' | 'executed' | 'cancelled' | 'revoked'
  nonce: string
  detail?: string
  href?: string
}) {
  const config = {
    submitted: { icon: FiSend, label: 'Submitted', color: 'text-blue-400', bg: 'bg-blue-500/10' },
    confirmed: { icon: FiCheckCircle, label: 'Confirmed', color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    executed: { icon: FiPlay, label: 'Executed', color: 'text-accent-400', bg: 'bg-accent-500/10' },
    cancelled: { icon: FiXCircle, label: 'Cancelled', color: 'text-red-400', bg: 'bg-red-500/10' },
    revoked: { icon: FiRotateCcw, label: 'Revoked', color: 'text-amber-400', bg: 'bg-amber-500/10' },
  }
  const { icon: Icon, label, color, bg } = config[action]

  return (
    <div className="flex items-center gap-3 py-2.5 border-b border-slate-800/60 last:border-0">
      <div className={`w-7 h-7 rounded-lg ${bg} flex items-center justify-center shrink-0`}>
        <Icon className={`w-3.5 h-3.5 ${color}`} />
      </div>
      <div className="flex-1 min-w-0">
        <span className={`text-sm font-medium ${color}`}>{label}</span>
        {detail && <span className="text-slate-500 text-sm ml-2 truncate">{detail}</span>}
      </div>
      <div className="text-xs font-mono text-slate-500">#{nonce}</div>
      {href && (
        <a href={href} target="_blank" rel="noopener noreferrer" className="text-slate-600 hover:text-slate-300 transition-colors">
          <FiExternalLink className="w-3.5 h-3.5" />
        </a>
      )}
    </div>
  )
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function DirectorProfile() {
  const { address, tokenId: tokenIdParam } = useParams<{ address: string; tokenId: string }>()
  const { address: userAddress } = useAccount()
  const chainId = useChainId()

  const validAddress = address && isAddress(address)
  const chamberAddress = (validAddress ? address : zeroAddress) as `0x${string}`
  const tokenId = useMemo(() => {
    try { return tokenIdParam ? BigInt(tokenIdParam) : 0n } catch { return 0n }
  }, [tokenIdParam])

  // Chamber-level data
  const chamberInfo = useChamberInfo(chamberAddress)
  const { members } = useBoardMembers(chamberAddress, chamberInfo.seats || 20)

  // Board node for this tokenId
  const { data: memberNode } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getMember',
    args: [tokenId],
    query: { enabled: tokenId > 0n && !!validAddress },
  })

  // NFT owner
  const { data: nftOwner } = useReadContract({
    address: chamberInfo.nftToken as `0x${string}` | undefined,
    abi: erc721Abi,
    functionName: 'ownerOf',
    args: [tokenId],
    query: { enabled: tokenId > 0n && !!chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress },
  })

  const { data: avatarUrl, resolvingImages } = useNftTokenImage(
    chamberInfo.nftToken as `0x${string}` | undefined,
    tokenId > 0n ? tokenId : undefined,
    { chamberAddress }
  )

  const [avatarLoadFailed, setAvatarLoadFailed] = useState(false)
  useEffect(() => {
    setAvatarLoadFailed(false)
  }, [avatarUrl])

  /** While tokenURI or metadata resolves; hides brief empty-trophy flicker before first paint. */
  const avatarResolving = resolvingImages && !avatarUrl
  const showAvatarImg = !!(avatarUrl && !avatarLoadFailed)

  // Confirm status per existing transaction (up to transactionCount)
  const txCount = chamberInfo.transactionCount || 0
  const txIds = useMemo(() => Array.from({ length: Math.min(txCount, 100) }, (_, i) => i), [txCount])

  const { data: confirmations } = useReadContracts({
    contracts: txIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getConfirmation' as const,
      args: [tokenId, BigInt(id)],
    })),
    query: { enabled: tokenId > 0n && txIds.length > 0 && !!validAddress },
  })

  // Log-based activity (events filtered by tokenId)
  const { data: logs, isLoading: logsLoading } = useDirectorLogs(chamberAddress, tokenId)
  const { data: delegationLogs } = useDelegationLogs(chamberAddress, tokenId)

  // Compute derived stats
  const boardMember = useMemo(() => members.find((m) => m.tokenId === tokenId), [members, tokenId])
  const isDirector = useMemo(() => {
    const dirs = chamberInfo.directors || []
    return dirs.some((d) => d.toLowerCase() === (nftOwner as string || '').toLowerCase())
  }, [chamberInfo.directors, nftOwner])
  const rank = boardMember?.rank ?? null
  const delegatedAmount = (memberNode as readonly [bigint, bigint, bigint, bigint] | undefined)?.[1] ?? 0n
  const totalDelegated = members.reduce((acc, m) => acc + m.amount, 0n)
  const votingPower = totalDelegated > 0n ? Number((delegatedAmount * 10000n) / totalDelegated) / 100 : 0

  const confirmedByNode = useMemo(() => confirmations?.filter((c) => c.result === true).length ?? 0, [confirmations])

  // Unique delegators
  const uniqueDelegators = useMemo(() => {
    if (!delegationLogs) return 0
    const holders = new Set(delegationLogs.map((l) => l.args.holder))
    return holders.size
  }, [delegationLogs])

  // Activity timeline — merge all events, sorted by block number desc
  const activityFeed = useMemo(() => {
    if (!logs) return []
    type Entry = { action: 'submitted' | 'confirmed' | 'executed' | 'cancelled' | 'revoked'; nonce: bigint; blockNumber: bigint; detail?: string }
    const entries: Entry[] = [
      ...logs.submitted.map((l) => ({ action: 'submitted' as const, nonce: l.args.nonce!, blockNumber: l.blockNumber!, detail: l.args.to ? `→ ${l.args.to.slice(0, 10)}…` : undefined })),
      ...logs.confirmed.map((l) => ({ action: 'confirmed' as const, nonce: l.args.nonce!, blockNumber: l.blockNumber! })),
      ...logs.executed.map((l) => ({ action: 'executed' as const, nonce: l.args.nonce!, blockNumber: l.blockNumber! })),
      ...logs.cancelled.map((l) => ({ action: 'cancelled' as const, nonce: l.args.nonce!, blockNumber: l.blockNumber! })),
      ...logs.revoked.map((l) => ({ action: 'revoked' as const, nonce: l.args.nonce!, blockNumber: l.blockNumber! })),
    ]
    return entries.sort((a, b) => Number(b.blockNumber - a.blockNumber))
  }, [logs])

  // Guards
  if (!validAddress || tokenId === 0n) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
        <FiAlertTriangle className="w-12 h-12 text-red-400" />
        <h2 className="font-heading text-xl font-bold text-slate-100">Invalid URL</h2>
        <p className="text-slate-400">Chamber address or token ID is missing.</p>
        <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
      </div>
    )
  }

  const shortOwner = nftOwner ? `${(nftOwner as string).slice(0, 8)}…${(nftOwner as string).slice(-6)}` : '—'
  const explorerUrl = chainId !== 31337 ? getBlockExplorerAddressUrl(chamberAddress, chainId) : undefined
  const isYou = userAddress && nftOwner && (nftOwner as string).toLowerCase() === userAddress.toLowerCase()

  return (
    <div className="space-y-6 pb-12">
      {/* Back nav */}
      <div className="flex items-center gap-3">
        <Link
          to={`/chamber/${chamberAddress}/board`}
          className="p-2 rounded-xl bg-slate-800/80 text-slate-400 hover:text-accent-400 transition-all"
        >
          <FiArrowLeft className="w-4 h-4" />
        </Link>
        <span className="text-slate-500 text-sm">
          <Link to={`/chamber/${chamberAddress}`} className="hover:text-slate-300 transition-colors">{chamberInfo.name || 'Chamber'}</Link>
          <span className="mx-2">›</span>
          Director Audit
        </span>
      </div>

      {/* Header card */}
      <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="panel p-6 relative overflow-hidden">
        <div className="absolute inset-0 bg-mesh-gradient pointer-events-none opacity-70" />
        <div className="relative z-10 space-y-6">
          <div className="flex flex-col md:flex-row md:items-center gap-6">
            {/* Avatar / NFT image placeholder */}
            <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-accent-600/20 to-accent-900/40 border border-accent-500/30 flex items-center justify-center shrink-0 overflow-hidden relative">
              {showAvatarImg ? (
                <NftRetryableImage
                  src={avatarUrl}
                  alt={`Member #${tokenId}`}
                  className="w-full h-full object-cover"
                  onLoadFailed={() => setAvatarLoadFailed(true)}
                />
              ) : avatarResolving ? (
                <div className="w-full h-full bg-slate-800/80 animate-pulse" />
              ) : (
                <FiAward className="w-8 h-8 text-accent-400" />
              )}
            </div>

            <div className="flex-1 min-w-0">
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <h1 className="font-heading text-2xl font-bold text-slate-100">
                  {chamberInfo.name || 'Chamber'} · Member #{tokenIdParam}
                </h1>
                {isDirector && (
                  <span className="badge bg-accent-600/80 text-white border-accent-500/40 text-xs">
                    <FiShield className="w-3 h-3 mr-1" /> Active Director
                  </span>
                )}
                {isYou && (
                  <span className="badge bg-emerald-600/40 text-emerald-300 border-emerald-500/30 text-xs">You</span>
                )}
                {rank !== null && (
                  <span className="badge bg-slate-700 text-slate-300 border-slate-600 text-xs">
                    Rank #{rank}
                  </span>
                )}
              </div>

              <div className="flex flex-wrap gap-4 text-sm text-slate-400 mt-2">
                <span className="flex items-center gap-1.5">
                  <FiUsers className="w-3.5 h-3.5" />
                  Owner: <span className="font-mono text-slate-300">{shortOwner}</span>
                  {nftOwner && explorerUrl && (
                    <a href={`${explorerUrl.replace('/address/', '/address/')}${nftOwner}`} target="_blank" rel="noopener noreferrer" className="hover:text-slate-200">
                      <FiExternalLink className="w-3 h-3" />
                    </a>
                  )}
                </span>
                <span className="flex items-center gap-1.5">
                  <FiLayers className="w-3.5 h-3.5" />
                  Chamber: <Link to={`/chamber/${chamberAddress}`} className="font-mono text-slate-300 hover:text-accent-400 transition-colors">{chamberAddress.slice(0, 10)}…{chamberAddress.slice(-8)}</Link>
                </span>
              </div>
            </div>

            {/* Voting power ring */}
            <div className="flex flex-col items-center gap-1 shrink-0">
              <div className="relative w-20 h-20">
                <svg className="w-20 h-20 -rotate-90" viewBox="0 0 36 36">
                  <circle cx="18" cy="18" r="15.9" fill="none" stroke="rgb(30 41 59)" strokeWidth="2.5" />
                  <circle
                    cx="18" cy="18" r="15.9" fill="none"
                    stroke="rgb(99 102 241)"
                    strokeWidth="2.5"
                    strokeDasharray={`${Math.min(votingPower, 100)} ${100 - Math.min(votingPower, 100)}`}
                    strokeLinecap="round"
                  />
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-sm font-bold text-slate-100">{votingPower.toFixed(1)}%</span>
                </div>
              </div>
              <span className="text-xs text-slate-500">Voting power</span>
            </div>
          </div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 pt-6 border-t border-slate-700/30">
          <StatCard icon={FiSend} label="Submitted" value={logs?.submitted.length ?? '…'} />
          <StatCard icon={FiCheckCircle} label="Confirmed" value={logs ? (logs.confirmed.length + confirmedByNode) : '…'} />
          <StatCard icon={FiPlay} label="Executed" value={logs?.executed.length ?? '…'} />
          <StatCard icon={FiXCircle} label="Cancelled" value={logs?.cancelled.length ?? '…'} />
          <StatCard icon={FiTrendingUp} label="Delegated" value={`${parseFloat(formatUnits(delegatedAmount, 18)).toFixed(2)}`} sub={`${votingPower.toFixed(2)}% of board`} />
          <StatCard icon={FiUsers} label="Delegators" value={uniqueDelegators} sub="unique wallets" />
        </div>
        </div>
      </motion.div>

      <DirectorOperatorManager
        chamberAddress={chamberAddress}
        nftToken={
          chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress
            ? (chamberInfo.nftToken as `0x${string}`)
            : undefined
        }
        tokenId={tokenId}
      />

      {/* Two-column layout: Activity + Details */}
      <div className="grid md:grid-cols-3 gap-6">

        {/* Activity feed (2/3) */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="md:col-span-2 panel p-5 space-y-3"
        >
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-2">
              <FiActivity className="w-4 h-4 text-accent-400" />
              <h2 className="font-heading font-semibold text-slate-100">Governance Activity</h2>
            </div>
            <span className="text-xs text-slate-500">{activityFeed.length} actions</span>
          </div>

          {logsLoading ? (
            <div className="space-y-2">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="flex items-center gap-3 py-2.5 animate-pulse">
                  <div className="w-7 h-7 rounded-lg bg-slate-800" />
                  <div className="flex-1 h-4 bg-slate-800 rounded" />
                  <div className="w-12 h-4 bg-slate-800 rounded" />
                </div>
              ))}
            </div>
          ) : activityFeed.length === 0 ? (
            <div className="py-10 text-center text-slate-500 text-sm">No governance activity recorded for this member</div>
          ) : (
            <div className="max-h-[480px] overflow-y-auto scroll-container pr-1">
              {activityFeed.map((entry, i) => (
                <ActivityRow
                  key={`${entry.action}-${entry.nonce}-${i}`}
                  action={entry.action}
                  nonce={entry.nonce.toString()}
                  detail={entry.detail}
                />
              ))}
            </div>
          )}
        </motion.div>

        {/* Details sidebar (1/3) */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15 }}
          className="space-y-4"
        >
          {/* Board position */}
          <div className="panel p-4 space-y-3">
            <div className="flex items-center gap-2 mb-1">
              <FiShield className="w-4 h-4 text-accent-400" />
              <h3 className="font-semibold text-slate-100 text-sm">Board Position</h3>
            </div>
            <Row label="Rank" value={rank !== null ? `#${rank} of ${members.length}` : 'Not ranked'} />
            <Row label="Seats" value={`${chamberInfo.seats ?? '—'} total`} />
            <Row label="Status" value={isDirector ? 'Active Director' : rank !== null ? 'Queued (not seated)' : 'Not on board'} highlight={isDirector} />
            <Row label="Quorum required" value={chamberInfo.quorum ? `${chamberInfo.quorum} / ${chamberInfo.seats}` : '—'} />
          </div>

          {/* Delegation detail */}
          <div className="panel p-4 space-y-3">
            <div className="flex items-center gap-2 mb-1">
              <FiDollarSign className="w-4 h-4 text-purple-400" />
              <h3 className="font-semibold text-slate-100 text-sm">Delegation</h3>
            </div>
            <Row label="Current weight" value={`${parseFloat(formatUnits(delegatedAmount, 18)).toFixed(4)} ${chamberInfo.symbol || ''}`} />
            <Row label="Board total" value={`${parseFloat(formatUnits(totalDelegated, 18)).toFixed(4)} ${chamberInfo.symbol || ''}`} />
            <Row label="Share of board" value={`${votingPower.toFixed(2)}%`} />
            <Row label="Unique delegators" value={uniqueDelegators.toString()} />
            <Row label="Delegation events" value={delegationLogs?.length.toString() ?? '…'} />
          </div>

          {/* Financial */}
          <div className="panel p-4 space-y-3">
            <div className="flex items-center gap-2 mb-1">
              <FiDollarSign className="w-4 h-4 text-emerald-400" />
              <h3 className="font-semibold text-slate-100 text-sm">Financial Impact</h3>
            </div>
            <Row label="Value proposed" value={`${parseFloat(formatEther(logs?.totalValueSubmitted ?? 0n)).toFixed(4)} ETH`} />
            <Row label="Value executed" value={`${parseFloat(formatEther(logs?.totalValueExecuted ?? 0n)).toFixed(4)} ETH`} />
            <Row label="Chamber assets" value={`${parseFloat(formatUnits(chamberInfo.totalAssets ?? 0n, 18)).toFixed(4)} ${chamberInfo.symbol || ''}`} />
          </div>

          {/* Quick links */}
          <div className="panel p-4 space-y-2">
            <h3 className="font-semibold text-slate-100 text-sm mb-2">Quick Links</h3>
            <Link to={`/chamber/${chamberAddress}`} className="flex items-center gap-2 text-sm text-slate-400 hover:text-accent-400 transition-colors">
              <FiLayers className="w-3.5 h-3.5" /> View Chamber
            </Link>
            <Link to={`/chamber/${chamberAddress}/transactions`} className="flex items-center gap-2 text-sm text-slate-400 hover:text-accent-400 transition-colors">
              <FiActivity className="w-3.5 h-3.5" /> Transaction Queue
            </Link>
            {nftOwner && nftOwner !== zeroAddress && explorerUrl && (
              <a
                href={`${explorerUrl.replace('/address/', '/address/')}${nftOwner}`}
                target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2 text-sm text-slate-400 hover:text-accent-400 transition-colors"
              >
                <FiExternalLink className="w-3.5 h-3.5" /> View owner on explorer
              </a>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  )
}

function Row({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-slate-500">{label}</span>
      <span className={highlight ? 'text-emerald-400 font-medium' : 'text-slate-300 font-medium'}>{value}</span>
    </div>
  )
}
