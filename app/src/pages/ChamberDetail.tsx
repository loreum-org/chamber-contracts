import { useEffect, useMemo } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useAccount, useBalance, useReadContract, useReadContracts, useChainId } from 'wagmi'
import { formatUnits, isAddress, zeroAddress } from 'viem'
import { erc20Abi } from '@/contracts'
import { chamberAbi } from '@/contracts/abis'
import {
  FiArrowLeft,
  FiCopy,
  FiExternalLink,
  FiLayers,
  FiUsers,
  FiShield,
  FiActivity,
  FiClock,
  FiSend,
  FiPlus,
  FiCheck,
  FiStar,
  FiAlertTriangle,
  FiLoader,
  FiUpload,
} from 'react-icons/fi'
import toast from 'react-hot-toast'
import {
  useChamberInfo,
  useChamberBalance,
  useBoardMembers,
  useMembershipTokenOwners,
  useDelegations,
  useSeatUpdate,
  useChamberEventRefresh,
  useChambersByAsset,
  useParentChamber,
  useChildChambers,
  useIsChamber,
  useNftImageMap,
  useChamberRegistryImplementationSync,
  useDirectorActionGate,
} from '@/hooks'
import BoardVisualization from '@/components/BoardVisualization'
import { DirectorCallerStatus } from '@/components/DirectorCallerStatus'
import TreasuryOverview from '@/components/TreasuryOverview'
import DelegationManager from '@/components/DelegationManager'
import SeatTheBoard, { SeatTheBoardLink } from '@/components/SeatTheBoard'
import ChamberAssetsAlchemy from '@/components/ChamberAssetsAlchemy'
import { NftRetryableImage } from '@/components/NftRetryableImage'
import { addRecentChamber } from '@/lib/recentChambers'
import { getBlockExplorerAddressUrl, shortenAddress } from '@/lib/utils'
import type { SeatUpdate } from '@/types'

type Tab = 'overview' | 'board' | 'staking' | 'delegation'

const validTabs: Tab[] = ['overview', 'board', 'staking', 'delegation']

export default function ChamberDetail() {
  const { address } = useParams<{ address: string; tab?: string }>()
  const validAddress = address && isAddress(address)
  const chamberAddr = validAddress ? (address as `0x${string}`) : undefined
  const isChamber = useIsChamber(chamberAddr)

  if (!validAddress) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
        <FiAlertTriangle className="w-12 h-12 text-red-400" />
        <h2 className="font-heading text-xl font-bold text-slate-100">Invalid Address</h2>
        <p className="text-slate-400">The address in this URL is not a valid Ethereum address.</p>
        <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
      </div>
    )
  }

  if (isChamber === undefined) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
        <FiLoader className="w-10 h-10 text-accent-400 animate-spin" />
        <p className="text-slate-400 text-sm">Verifying chamber…</p>
      </div>
    )
  }

  if (isChamber === false) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
        <FiAlertTriangle className="w-12 h-12 text-red-400" />
        <h2 className="font-heading text-xl font-bold text-slate-100">Not a Chamber</h2>
        <p className="text-slate-400">This address does not look like a Chamber contract.</p>
        <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
      </div>
    )
  }

  return <ChamberDetailContent chamberAddress={chamberAddr!} />
}

function ChamberDetailContent({ chamberAddress }: { chamberAddress: `0x${string}` }) {
  const { tab } = useParams<{ address: string; tab?: string }>()
  const navigate = useNavigate()
  const { address: userAddress } = useAccount()
  const chainId = useChainId()

  useEffect(() => {
    addRecentChamber(chainId, chamberAddress)
  }, [chainId, chamberAddress])

  const activeTab: Tab = tab && validTabs.includes(tab as Tab) ? (tab as Tab) : 'overview'
  
  const setActiveTab = (newTab: Tab) => {
    if (newTab === 'overview') {
      navigate(`/chamber/${chamberAddress}`)
    } else {
      navigate(`/chamber/${chamberAddress}/${newTab}`)
    }
  }

  const chamberInfo = useChamberInfo(chamberAddress)
  const implSync = useChamberRegistryImplementationSync(chamberAddress)
  const { balance: userBalance } = useChamberBalance(chamberAddress, userAddress)
  const {
    members: boardMembersRaw,
    refetch: refetchBoard,
    isPending: boardMembersPending,
    isFetched: boardMembersFetched,
  } = useBoardMembers(chamberAddress, 20)
  const membershipTokenIds = useMemo(
    () => boardMembersRaw.map((m) => m.tokenId),
    [boardMembersRaw]
  )
  const {
    owners: membershipOwners,
    refetch: refetchMembershipOwners,
    isPending: membershipOwnersPending,
  } = useMembershipTokenOwners(chamberInfo.nftToken, membershipTokenIds)
  const members = useMemo(
    () =>
      boardMembersRaw.map((m, i) => ({
        ...m,
        owner: membershipOwners[i],
      })),
    [boardMembersRaw, membershipOwners]
  )
  const { delegations } = useDelegations(chamberAddress, userAddress)
  const directorGate = useDirectorActionGate(
    chamberAddress,
    userAddress,
    chamberInfo.directors,
    members,
  )
  const transactionIds = useMemo(
    () => Array.from({ length: chamberInfo.transactionCount || 0 }, (_, i) => i),
    [chamberInfo.transactionCount]
  )

  const { data: headerTransactionsData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransaction',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getTransaction'; args: [bigint] }[],
    query: { enabled: transactionIds.length > 0 },
  })

  const { data: headerCancelledData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getCancelled',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getCancelled'; args: [bigint] }[],
    query: { enabled: transactionIds.length > 0 },
  })

  const queuedTransactionCount = useMemo(() => {
    if (!headerTransactionsData) return 0
    return headerTransactionsData.reduce((count, result, index) => {
      if (result.status !== 'success' || !result.result) return count
      const [executed] = result.result as [boolean, number, `0x${string}`, bigint, `0x${string}`]
      const cancelledResult = headerCancelledData?.[index]
      const cancelled = cancelledResult?.status === 'success' && cancelledResult.result === true
      return !executed && !cancelled ? count + 1 : count
    }, 0)
  }, [headerTransactionsData, headerCancelledData])

  const refreshBoardViews = () => {
    void refetchBoard()
    void refetchMembershipOwners()
  }
  
  // Get asset token symbol
  const { data: assetSymbol } = useReadContract({
    address: chamberInfo.assetToken,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: !!chamberInfo.assetToken },
  })
  
  // Watch for contract events and auto-refresh data when transactions are mined
  useChamberEventRefresh(chamberAddress)
  
  // ETH balance of chamber
  const { data: ethBalance } = useBalance({
    address: chamberAddress,
  })

  const copyAddress = () => {
    navigator.clipboard.writeText(chamberAddress)
    toast.success('Address copied!')
  }

  const shortAddress = chamberAddress
    ? `${chamberAddress.slice(0, 10)}...${chamberAddress.slice(-8)}`
    : ''

  // Calculate total delegated
  const totalDelegated = members.reduce((sum, m) => sum + m.amount, 0n)

  const tabs = [
    { id: 'overview', label: 'Overview', icon: FiActivity },
    { id: 'board', label: 'Board', icon: FiUsers },
    { id: 'staking', label: 'Staking', icon: FiLayers },
    { id: 'delegation', label: 'Delegation', icon: FiSend },
  ] as const

  const boardEmpty = boardMembersFetched && !boardMembersPending && members.length === 0

  const chamberImplVersion =
    chamberInfo.version ?? implSync.chamberVersionLabel ?? undefined

  const chamberVersionTag =
    chamberImplVersion == null || chamberImplVersion === ''
      ? '…'
      : chamberImplVersion.startsWith('v')
        ? chamberImplVersion
        : `v${chamberImplVersion}`

  const upgradeProposalHref = `/chamber/${chamberAddress}/transactions?proposal=upgrade`

  const copyUpgradeProposalLink = () => {
    const url = new URL(upgradeProposalHref, window.location.origin).href
    void navigator.clipboard.writeText(url).then(
      () => toast.success('Upgrade proposal link copied'),
      () => toast.error('Could not copy link'),
    )
  }

  const registryImplementation = implSync.registryImplementation
  const showImplMismatch =
    implSync.implMismatch && !implSync.isLoading && !!registryImplementation

  return (
    <div className="space-y-6">
      {chamberInfo.paused && (
        <motion.div
          initial={{ opacity: 0, y: -6 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-xl border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-100"
          role="status"
        >
          <div className="flex items-start gap-3">
            <FiAlertTriangle className="w-5 h-5 shrink-0 text-red-400 mt-0.5" aria-hidden />
            <div>
              <p className="font-medium text-red-100">Chamber paused</p>
              <p className="text-red-100/80 leading-relaxed">
                Deposits, withdrawals, and wallet execute are halted. Directors can still submit and confirm an unpause proposal.
              </p>
              <Link
                to="/docs/protocol/governance"
                className="text-accent-400 hover:text-accent-300 font-medium mt-1.5 inline-block"
              >
                How governance works →
              </Link>
            </div>
          </div>
        </motion.div>
      )}
      {showImplMismatch && registryImplementation && (
        <motion.div
          initial={{ opacity: 0, y: -6 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-xl border border-amber-400/35 bg-amber-500/[0.08] px-4 py-3 text-sm text-amber-50/95"
          role="status"
        >
          <div className="flex items-start gap-3">
            <FiAlertTriangle className="w-5 h-5 shrink-0 text-amber-400 mt-0.5" aria-hidden />
            <div className="space-y-1.5">
              <p className="font-medium text-amber-100">New Chamber implementation available on the Registry</p>
              <p className="text-amber-100/85 leading-relaxed">
                The Registry’s default implementation is{' '}
                <span className="font-mono tabular-nums">
                  v{implSync.registryImplementationVersionLabel ?? '—'}
                </span>{' '}
                ({shortenAddress(registryImplementation, 6)}
                ). This chamber proxy still uses{' '}
                <span className="font-mono tabular-nums">
                  {chamberVersionTag === '…' ? '—' : chamberVersionTag}
                </span>
                . Directors can
                upgrade this proxy via the Chamber’s upgrade flow so it aligns with the Registry.
              </p>
              <p className="mt-1.5">
                <Link
                  to="/docs/protocol/architecture"
                  className="inline-flex items-center gap-1 text-accent-400 hover:text-accent-300 font-medium"
                >
                  How Chamber upgrades work →
                </Link>
              </p>
              {implSync.registryAddress && chainId !== 31337 && (
                <a
                  href={getBlockExplorerAddressUrl(implSync.registryAddress, chainId)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-accent-400 hover:text-accent-300 font-medium"
                >
                  View Registry <FiExternalLink className="w-3.5 h-3.5" aria-hidden />
                </a>
              )}
              {directorGate.canAct ? (
                <div className="flex flex-wrap gap-2 mt-4">
                  <Link to={upgradeProposalHref} className="btn btn-primary inline-flex gap-2 shrink-0">
                    <FiUpload className="w-4 h-4" aria-hidden />
                    Propose upgrade
                  </Link>
                </div>
              ) : directorGate.seatingPending ? (
                <p className="mt-4 text-amber-100/90 leading-relaxed">
                  You hold a live board seat, but director actions unlock at block{' '}
                  {directorGate.seatedAt?.toString() ?? '…'}.
                </p>
              ) : (
                <div className="mt-4 space-y-2">
                  <p className="text-amber-100/85 leading-relaxed">
                    Ask a director to open this link (with{' '}
                    <span className="font-mono">?proposal=upgrade</span>
                    ), review the prefilled multisig proposal, then submit.
                  </p>
                  <button
                    type="button"
                    onClick={copyUpgradeProposalLink}
                    className="btn btn-secondary inline-flex gap-2 shrink-0"
                    title="Copy upgrade proposal link"
                  >
                    <FiCopy className="w-4 h-4" aria-hidden />
                    Ask a director
                  </button>
                </div>
              )}
            </div>
          </div>
        </motion.div>
      )}

      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="panel p-6"
      >
        <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
          <div className="flex items-start gap-4">
            <Link
              to="/"
              className="p-2.5 rounded-xl bg-slate-800/80 text-slate-400 hover:text-accent-400 hover:bg-slate-800 transition-all"
            >
              <FiArrowLeft className="w-5 h-5" />
            </Link>
            
            <div>
              <div className="flex items-center gap-3 mb-1">
                <h1 className="font-heading text-2xl font-bold text-slate-100 tracking-tight">
                  {chamberInfo.name || 'Loading...'}
                </h1>
                <span className="badge badge-primary">{chamberInfo.symbol}</span>
                <span
                  title="Solidity VERSION constant from the Chamber implementation"
                  className="badge bg-slate-800 text-slate-400 border-slate-700 whitespace-nowrap font-mono tabular-nums"
                >
                  {chamberVersionTag}
                </span>
              </div>
              
              <div className="flex items-center gap-2 text-slate-500">
                <span className="font-mono text-sm">{shortAddress}</span>
                <button onClick={copyAddress} className="hover:text-accent-400 transition-colors">
                  <FiCopy className="w-4 h-4" />
                </button>
                <a
                  href={chainId !== 31337 ? getBlockExplorerAddressUrl(chamberAddress, chainId) : '#'}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-accent-400 transition-colors"
                >
                  <FiExternalLink className="w-4 h-4" />
                </a>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <Link
              to={`/chamber/${chamberAddress}/transactions`}
              className="btn btn-secondary relative"
            >
              <FiShield className="w-4 h-4" />
              Transactions
              {queuedTransactionCount > 0 && (
                <span className="absolute -right-2 -top-2 min-w-5 h-5 px-1 rounded-full bg-accent-500 text-white text-[11px] font-bold leading-5 text-center shadow-lg shadow-accent-500/20">
                  {queuedTransactionCount > 99 ? '99+' : queuedTransactionCount}
                </span>
              )}
            </Link>
          </div>
        </div>

        <DirectorCallerStatus
          role={directorGate.role}
          tokenId={directorGate.tokenId}
          nftOwner={directorGate.nftOwner}
        />

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-6 border-t border-slate-700/30">
          <div className="stat-card">
            <div className="flex items-center gap-2 text-slate-500 text-xs mb-1.5">
              <FiLayers className="w-3.5 h-3.5" />
              Total Assets
            </div>
            <div className="font-heading text-xl font-bold gradient-text">
              {chamberInfo.totalAssets !== undefined
                ? parseFloat(formatUnits(chamberInfo.totalAssets, 18)).toLocaleString(undefined, {
                    maximumFractionDigits: 2,
                  })
                : '...'}{' '}
              {assetSymbol && <span className="text-lg text-slate-400">{assetSymbol as string}</span>}
            </div>
          </div>
          
          <div className="stat-card">
            <div className="flex items-center gap-2 text-slate-500 text-xs mb-1.5">
              <FiUsers className="w-3.5 h-3.5" />
              Board Seats
            </div>
            <div className="font-heading text-xl font-bold text-slate-100">
              {chamberInfo.seats ?? '…'}
            </div>
          </div>
          
          <div className="stat-card">
            <div className="flex items-center gap-2 text-slate-500 text-xs mb-1.5">
              <FiCheck className="w-3.5 h-3.5" />
              Quorum
            </div>
            <div className="font-heading text-xl font-bold text-slate-100">
              {chamberInfo.quorum} signatures
            </div>
          </div>
          
          <div className="stat-card">
            <div className="flex items-center gap-2 text-slate-500 text-xs mb-1.5">
              <FiActivity className="w-3.5 h-3.5" />
              ETH Balance
            </div>
            <div className="font-heading text-xl font-bold text-slate-100">
              {ethBalance 
                ? parseFloat(formatUnits(ethBalance.value, 18)).toFixed(4)
                : '0'
              } ETH
            </div>
          </div>
        </div>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-slate-900/80 rounded-xl border border-slate-700/50 overflow-x-auto">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const isActive = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`
                relative flex items-center gap-2 px-4 py-2.5 rounded-lg transition-all flex-1 justify-center text-sm font-medium
                ${isActive ? 'text-accent-400' : 'text-slate-400 hover:text-slate-200'}
              `}
            >
              <Icon className="w-4 h-4" />
              <span className="hidden sm:inline">{tab.label}</span>
              {isActive && (
                <motion.div
                  layoutId="tab-indicator"
                  className="absolute inset-0 bg-accent-500/10 border border-accent-500/30 rounded-lg"
                  transition={{ type: 'spring', bounce: 0.2, duration: 0.6 }}
                />
              )}
            </button>
          )
        })}
      </div>

      {/* Tab Content */}
      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        {activeTab === 'overview' && (
          <OverviewTab
            chamberAddress={chamberAddress}
            chamberInfo={chamberInfo}
            members={members}
            totalDelegated={totalDelegated}
            userBalance={userBalance}
            boardEmpty={boardEmpty}
            setActiveTab={setActiveTab}
          />
        )}
        
        {activeTab === 'board' && (
          <BoardVisualization
            chamberAddress={chamberAddress}
            nftToken={
              chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress
                ? (chamberInfo.nftToken as `0x${string}`)
                : undefined
            }
            members={members}
            seats={chamberInfo.seats || 5}
            totalDelegated={totalDelegated}
            ownersLoading={membershipTokenIds.length > 0 && membershipOwnersPending}
            delegations={delegations}
            boardMembersFetched={boardMembersFetched}
            boardMembersPending={boardMembersPending}
            onRefreshBoard={refreshBoardViews}
          />
        )}
        
        {activeTab === 'staking' && (
          <TreasuryOverview
            chamberAddress={chamberAddress}
            chamberInfo={chamberInfo}
            userBalance={userBalance}
            totalDelegated={totalDelegated}
          />
        )}
        
        {activeTab === 'delegation' && (
          <DelegationManager
            chamberAddress={chamberAddress}
            userBalance={userBalance}
            delegations={delegations}
            members={members}
            vaultSymbol={chamberInfo.symbol}
            nftToken={
              chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress
                ? (chamberInfo.nftToken as `0x${string}`)
                : undefined
            }
            seats={chamberInfo.seats}
          />
        )}
        

      </motion.div>
    </div>
  )
}

// ─── Nakamoto Coefficient Panel ───────────────────────────────────────────────

/** Organization stacks under Current Directors on the left when the list is this short or shorter. */
const ORG_PANEL_BELOW_DIRECTORS_MAX = 6

function OrganizationOverviewCard({
  chamberAddress,
  nftToken,
  isLoadingParent,
  parentChamber,
  isLoadingChildren,
  childChambers,
  otherRelated,
}: {
  chamberAddress: `0x${string}`
  nftToken: ReturnType<typeof useChamberInfo>['nftToken']
  isLoadingParent: boolean
  parentChamber: `0x${string}` | undefined
  isLoadingChildren: boolean
  childChambers: `0x${string}`[] | undefined
  otherRelated: `0x${string}`[]
}) {
  return (
    <div className="panel min-w-0">
      <div className="p-4 border-b border-slate-700/30 flex items-center justify-between gap-4">
        <div>
          <h3 className="font-heading font-semibold text-slate-100">Organization (Sub Chambers)</h3>
          <p className="text-slate-500 text-xs mt-0.5">
            Hierarchy and related chambers in this organization
          </p>
        </div>
        {nftToken && (
          <Link
            to={`/deploy?erc20=${chamberAddress}&erc721=${nftToken}`}
            className="btn btn-secondary shrink-0"
          >
            <FiPlus className="w-4 h-4" />
            Sub Chamber
          </Link>
        )}
      </div>
      <div className="p-4 space-y-6">
        <div>
          <h4 className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-3 flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-slate-500" />
            Parent Chamber
          </h4>
          {isLoadingParent ? (
            <div className="h-16 bg-slate-800/50 rounded-xl animate-pulse max-w-sm" />
          ) : parentChamber && parentChamber !== '0x0000000000000000000000000000000000000000' ? (
            <Link
              to={`/chamber/${parentChamber}`}
              className="flex items-center gap-3 p-3.5 rounded-xl bg-slate-800/40 border border-slate-700/50 hover:border-slate-500/60 hover:bg-slate-800/60 transition-all group max-w-sm"
            >
              <div className="w-9 h-9 rounded-lg bg-slate-800/80 flex items-center justify-center border border-slate-600/40 group-hover:border-slate-500/50 transition-colors">
                <FiArrowLeft className="w-4 h-4 text-slate-400 rotate-90" />
              </div>
              <div>
                <div className="text-sm font-medium text-slate-200 group-hover:text-slate-100 transition-colors">
                  {parentChamber.slice(0, 10)}...{parentChamber.slice(-8)}
                </div>
                <div className="text-[11px] text-slate-500">Parent Chamber</div>
              </div>
            </Link>
          ) : (
            <div className="text-slate-500 text-xs italic pl-3.5 border-l border-slate-700/50 py-1">
              This is a main chamber
            </div>
          )}
        </div>

        <div>
          <h4 className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-3 flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-accent-500" />
            Sub Chambers
          </h4>
          {isLoadingChildren ? (
            <div className="flex gap-4 overflow-x-auto pb-2">
              {[1, 2].map((i) => (
                <div key={i} className="min-w-[240px] h-16 bg-slate-800/50 rounded-xl animate-pulse" />
              ))}
            </div>
          ) : childChambers && childChambers.length > 0 ? (
            <div className="flex gap-4 overflow-x-auto pb-2">
              {childChambers.map((addr) => (
                <Link
                  key={addr}
                  to={`/chamber/${addr}`}
                  className="min-w-[240px] p-3.5 rounded-xl bg-slate-800/40 border border-slate-700/50 hover:border-accent-500/50 hover:bg-slate-800/60 transition-all group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-accent-500/10 flex items-center justify-center group-hover:bg-accent-500/20 transition-colors">
                      <FiArrowLeft className="w-4 h-4 text-accent-400 -rotate-90" />
                    </div>
                    <div>
                      <div className="text-sm font-medium text-slate-200 group-hover:text-accent-400 transition-colors">
                        {addr.slice(0, 8)}...{addr.slice(-6)}
                      </div>
                      <div className="text-[11px] text-slate-500">Sub-Chamber</div>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="text-slate-500 text-xs italic pl-3.5 border-l border-slate-700/50 py-1">
              No sub-chambers deployed yet
            </div>
          )}
        </div>

        {otherRelated.length > 0 && (
          <div>
            <h4 className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-3 flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-slate-500" />
              Sibling Chambers
            </h4>
            <div className="flex gap-4 overflow-x-auto pb-2">
              {otherRelated.map((addr) => (
                <Link
                  key={addr}
                  to={`/chamber/${addr}`}
                  className="min-w-[240px] p-3.5 rounded-xl bg-slate-800/40 border border-slate-700/50 hover:border-slate-500/50 hover:bg-slate-800/60 transition-all group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-slate-700/50 flex items-center justify-center group-hover:bg-slate-600 transition-colors">
                      <FiLayers className="w-4 h-4 text-slate-400" />
                    </div>
                    <div>
                      <div className="text-sm font-medium text-slate-200 group-hover:text-slate-100 transition-colors">
                        {addr.slice(0, 8)}…{addr.slice(-6)}
                      </div>
                      <div className="text-[11px] text-slate-500">Sibling Chamber</div>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// Overview Tab Component
interface OverviewTabProps {
  chamberAddress: `0x${string}`
  chamberInfo: ReturnType<typeof useChamberInfo>
  members: ReturnType<typeof useBoardMembers>['members']
  totalDelegated: bigint
  userBalance: bigint | undefined
  boardEmpty: boolean
  setActiveTab: (tab: Tab) => void
}

function OverviewTab({ chamberAddress, chamberInfo, members, totalDelegated, userBalance, boardEmpty, setActiveTab }: OverviewTabProps) {
  const chainId = useChainId()
  const { chambers: relatedChambers } = useChambersByAsset(chamberInfo.assetToken as `0x${string}`)
  const { parentChamber, isLoading: isLoadingParent } = useParentChamber(chamberAddress)
  const { childChambers, isLoading: isLoadingChildren } = useChildChambers(chamberAddress)
  
  // Filter out current chamber from related chambers
  const filteredRelated = relatedChambers?.filter(addr => addr.toLowerCase() !== chamberAddress.toLowerCase()) || []

  // Filter out parent and children from related to show them separately
  const otherRelated = filteredRelated.filter(addr => 
    addr.toLowerCase() !== parentChamber?.toLowerCase() && 
    !childChambers?.some(c => c.toLowerCase() === addr.toLowerCase())
  )

  const directorSlice = useMemo(
    () => members.slice(0, chamberInfo.seats || 5),
    [members, chamberInfo.seats]
  )
  const directorTokenIds = useMemo(() => directorSlice.map((m) => m.tokenId), [directorSlice])
  const nftForImages =
    chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress
      ? (chamberInfo.nftToken as `0x${string}`)
      : undefined
  const { data: directorImages, resolvingImages: directorImagesResolving } = useNftImageMap(
    nftForImages,
    directorTokenIds,
    {
      chamberAddress,
    }
  )

  const orgBelowDirectors = directorSlice.length <= ORG_PANEL_BELOW_DIRECTORS_MAX
  const organizationCard = (
    <OrganizationOverviewCard
      chamberAddress={chamberAddress}
      nftToken={chamberInfo.nftToken}
      isLoadingParent={isLoadingParent}
      parentChamber={parentChamber}
      isLoadingChildren={isLoadingChildren}
      childChambers={childChambers}
      otherRelated={otherRelated}
    />
  )

  return (
    <div className="space-y-6">
      {boardEmpty ? (
        <SeatTheBoard
          chamberAddress={chamberAddress}
          nftToken={
            chamberInfo.nftToken && chamberInfo.nftToken !== zeroAddress
              ? (chamberInfo.nftToken as `0x${string}`)
              : undefined
          }
        />
      ) : (
        <TransactionActivityPanel
          chamberAddress={chamberAddress}
          currentSeats={chamberInfo.seats ?? 0}
          transactionCount={chamberInfo.transactionCount || 0}
          quorum={chamberInfo.quorum || 1}
        />
      )}

      <ChamberAssetsAlchemy
        chamberAddress={chamberAddress}
        chainId={chainId}
        chamberInfo={{
          assetToken: chamberInfo.assetToken,
          nftToken: chamberInfo.nftToken,
        }}
      />

      <div className="grid lg:grid-cols-2 gap-6 items-start">
        <div className="flex flex-col gap-6 min-w-0">
        {/* Directors — left column; Organization joins here when the list is short */}
        <div className="panel min-w-0">
        <div className="p-4 border-b border-slate-700/30 flex items-center justify-between">
          <div>
            <h3 className="font-heading font-semibold text-slate-100">Current Directors</h3>
            <p className="text-slate-500 text-xs mt-0.5">
              Top {chamberInfo.seats} members by delegated weight
            </p>
          </div>
          <span className="badge badge-primary">
            {members.filter((_, i) => i < (chamberInfo.seats || 0)).length} active
          </span>
        </div>
        <div className="divide-y divide-slate-700/30">
          {directorSlice.length > 0 ? (
            directorSlice.map((m, index) => (
              <Link
                key={m.tokenId.toString()}
                to={`/chamber/${chamberAddress}/director/${m.tokenId.toString()}`}
                className="p-4 flex items-center gap-3 hover:bg-slate-800/40 transition-colors group"
              >
                <div
                  className={`
                  relative w-8 h-8 rounded-lg overflow-hidden shrink-0 flex items-center justify-center
                  ${index === 0 ? 'ring-2 ring-accent-500/50' : ''}
                `}
                >
                  {directorImagesResolving && !directorImages?.get(m.tokenId.toString()) ? (
                    <div className="w-full h-full animate-pulse bg-slate-700/70" aria-hidden />
                  ) : directorImages?.get(m.tokenId.toString()) ? (
                    <NftRetryableImage
                      src={directorImages.get(m.tokenId.toString())}
                      alt=""
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div
                      className={`
                      w-full h-full flex items-center justify-center text-sm font-bold
                      ${index === 0
                        ? 'bg-gradient-to-br from-accent-600 to-accent-800 text-white shadow-sm'
                        : 'bg-slate-800 text-slate-400'}
                    `}
                    >
                      {index + 1}
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-slate-400 text-xs">Member #{m.tokenId.toString()}</span>
                    {index === 0 && <FiStar className="w-3 h-3 text-accent-400" />}
                  </div>
                  <span className="font-mono text-slate-100 text-sm">
                    {m.owner && m.owner !== '0x0000000000000000000000000000000000000000'
                      ? `${m.owner.slice(0, 8)}…${m.owner.slice(-6)}`
                      : 'Unknown owner'}
                  </span>
                </div>
                <span className="text-slate-500 text-xs font-mono shrink-0">
                  {parseFloat(formatUnits(m.amount, 18)).toFixed(2)} {chamberInfo.symbol}
                </span>
                <FiArrowLeft className="w-3.5 h-3.5 text-slate-600 group-hover:text-accent-400 rotate-180 transition-colors shrink-0" />
              </Link>
            ))
          ) : (
            <div className="p-8 text-center space-y-3">
              <p className="text-slate-300 text-sm font-medium">No directors seated</p>
              <p className="text-slate-500 text-xs max-w-sm mx-auto leading-relaxed">
                Hold a membership NFT, deposit shares, and delegate to that token. Director actions unlock after one block.
              </p>
              <Link
                to="/docs/introduction/getting-started"
                className="text-accent-400 text-xs hover:underline inline-block"
              >
                Getting started →
              </Link>
              <SeatTheBoardLink
                chamberAddress={chamberAddress}
                nftToken={chamberInfo.nftToken}
                className="btn btn-primary inline-flex"
              >
                Seat the board
              </SeatTheBoardLink>
            </div>
          )}
        </div>
      </div>
          {orgBelowDirectors && organizationCard}
        </div>

        {/* Right column: Quick Actions; Organization here when directors list is long; then Contract */}
        <div className="flex flex-col gap-6 min-w-0">
          <div className="panel">
            <div className="p-4 border-b border-slate-700/30">
              <h3 className="font-heading font-semibold text-slate-100">Quick Actions</h3>
              <p className="text-slate-500 text-xs mt-0.5">Common operations</p>
            </div>
            <div className="p-4 space-y-3">
              {boardEmpty ? (
                <>
                  <SeatTheBoardLink
                    chamberAddress={chamberAddress}
                    nftToken={chamberInfo.nftToken}
                    className="btn btn-primary w-full justify-start"
                  >
                    <FiSend className="w-4 h-4" />
                    Seat the board
                    <FiArrowLeft className="w-4 h-4 rotate-180 ml-auto" />
                  </SeatTheBoardLink>
                  <button
                    type="button"
                    onClick={() => setActiveTab('staking')}
                    className="btn btn-secondary w-full justify-start"
                  >
                    <FiPlus className="w-4 h-4" />
                    Deposit Assets
                    <FiArrowLeft className="w-4 h-4 rotate-180 ml-auto" />
                  </button>
                </>
              ) : (
                <>
                  <Link
                    to={`/chamber/${chamberAddress}/transactions`}
                    className="btn btn-secondary w-full justify-start"
                  >
                    <FiShield className="w-4 h-4" />
                    View Transaction Queue
                    <FiArrowLeft className="w-4 h-4 rotate-180 ml-auto" />
                  </Link>

                  <button
                    type="button"
                    onClick={() => setActiveTab('staking')}
                    className="btn btn-secondary w-full justify-start"
                  >
                    <FiPlus className="w-4 h-4" />
                    Deposit Assets
                    <FiArrowLeft className="w-4 h-4 rotate-180 ml-auto" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setActiveTab('delegation')}
                    className="btn btn-secondary w-full justify-start"
                  >
                    <FiSend className="w-4 h-4" />
                    Delegate Votes
                    <FiArrowLeft className="w-4 h-4 rotate-180 ml-auto" />
                  </button>
                </>
              )}
            </div>

            {userBalance !== undefined && (
              <div className="p-4 border-t border-slate-700/30 bg-accent-950/20">
                <div className="text-slate-400 text-xs mb-1">Your Balance</div>
                <div className="font-heading text-xl font-bold gradient-text">
                  {parseFloat(formatUnits(userBalance, 18)).toLocaleString(undefined, {
                    maximumFractionDigits: 4,
                  })}{' '}
                  shares
                </div>
              </div>
            )}
          </div>

          {!orgBelowDirectors && organizationCard}

          {/* Contract Info */}
          <div className="panel min-w-0">
            <div className="p-4 border-b border-slate-700/30">
              <h3 className="font-heading font-semibold text-slate-100">Contract Details</h3>
            </div>
            <div className="p-4 grid md:grid-cols-2 gap-4">
              <AddressRow label="Chamber Address" address={chamberAddress} chainId={chainId} />
              <AddressRow label="Asset Token (ERC20)" address={chamberInfo.assetToken} chainId={chainId} />
              <AddressRow label="Member Contract (ERC721)" address={chamberInfo.nftToken} chainId={chainId} />
              <div className="stat-card">
                <div className="text-slate-500 text-xs mb-1.5">Total Supply (Shares)</div>
                <div className="font-mono text-slate-100 text-sm">
                  {chamberInfo.totalSupply !== undefined
                    ? parseFloat(formatUnits(chamberInfo.totalSupply, 18)).toLocaleString()
                    : '...'}{' '}
                  {chamberInfo.symbol && <span className="text-slate-400">{chamberInfo.symbol}</span>}
                </div>
              </div>
              <div className="stat-card">
                <div className="text-slate-500 text-xs mb-1.5">Total Delegated (Voting Power)</div>
                <div className="font-mono text-slate-100 text-sm">
                  {parseFloat(formatUnits(totalDelegated, 18)).toLocaleString()}{' '}
                  {chamberInfo.symbol && <span className="text-slate-400">{chamberInfo.symbol}</span>}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

const SEAT_TIMELOCK_SEC = 7n * 24n * 60n * 60n

function boardProposalStatus(seatUpdate: SeatUpdate): 'Pending' | 'Ready' {
  const nowSec = BigInt(Math.floor(Date.now() / 1000))
  const timelockEnd = seatUpdate.timestamp + SEAT_TIMELOCK_SEC
  const timelockExpired = nowSec >= timelockEnd
  const supporterCount = seatUpdate.supporters.length
  const requiredQuorum = Number(seatUpdate.requiredQuorum)
  const quorumReached = supporterCount >= requiredQuorum
  return quorumReached && timelockExpired ? 'Ready' : 'Pending'
}

function TransactionActivityPanel({
  chamberAddress,
  currentSeats,
  transactionCount,
  quorum,
}: {
  chamberAddress: `0x${string}`
  currentSeats: number
  transactionCount: number
  quorum: number
}) {
  const latestIds = useMemo(
    () =>
      Array.from({ length: Math.min(transactionCount, 6) }, (_, i) => transactionCount - 1 - i),
    [transactionCount]
  )

  const { seatUpdate } = useSeatUpdate(chamberAddress)

  const { data: txData, isLoading: isLoadingTransactions } = useReadContracts({
    contracts: latestIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransaction',
      args: [BigInt(id)],
    })) as readonly {
      address: `0x${string}`
      abi: typeof chamberAbi
      functionName: 'getTransaction'
      args: [bigint]
    }[],
    query: { enabled: latestIds.length > 0 },
  })

  const transactions = latestIds
    .map((id, index) => {
      const result = txData?.[index]
      if (!result || result.status !== 'success') return null
      const [executed, confirmations, target, value] = result.result as [boolean, number, `0x${string}`, bigint, `0x${string}`]
      return {
        id,
        executed,
        confirmations,
        target,
        value,
        status: executed ? 'Executed' : confirmations >= quorum ? 'Ready' : 'Pending',
      }
    })
    .filter((tx): tx is NonNullable<typeof tx> => tx !== null)

  const activeBoardProposal =
    seatUpdate && seatUpdate.timestamp > 0n ? seatUpdate : undefined

  const isLoadingSeat = seatUpdate === undefined
  const listLoading =
    (latestIds.length > 0 && isLoadingTransactions) ||
    (!activeBoardProposal && transactions.length === 0 && isLoadingSeat)

  return (
    <div className="panel xl:sticky xl:top-6 xl:self-start">
      <div className="p-4 border-b border-slate-700/30 flex items-center justify-between gap-4">
        <div>
          <h3 className="font-heading font-semibold text-slate-100">Transaction Activity</h3>
          <p className="text-slate-500 text-xs mt-0.5">Wallet proposals and active board-seat changes</p>
        </div>
        <Link
          to={`/chamber/${chamberAddress}/transactions`}
          className="text-xs text-accent-400 hover:text-accent-300 transition-colors"
        >
          View all
        </Link>
      </div>

      <div className="p-4">
        {listLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-16 rounded-xl bg-slate-800/50 animate-pulse" />
            ))}
          </div>
        ) : activeBoardProposal || transactions.length > 0 ? (
          <div className="space-y-3">
            {activeBoardProposal && (
              <Link
                to={`/chamber/${chamberAddress}/transactions`}
                className="block rounded-xl border border-violet-500/30 bg-violet-500/5 p-3 hover:border-violet-400/40 hover:bg-violet-500/10 transition-all"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-slate-200 text-sm font-medium">Board seat change</span>
                      <span
                        className={`badge text-[10px] ${
                          boardProposalStatus(activeBoardProposal) === 'Ready'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                        }`}
                      >
                        {boardProposalStatus(activeBoardProposal)}
                      </span>
                    </div>
                    <div className="font-mono text-slate-500 text-xs mt-1">
                      {currentSeats} → {Number(activeBoardProposal.proposedSeats)} seats ·{' '}
                      {activeBoardProposal.supporters.length} /{' '}
                      {Number(activeBoardProposal.requiredQuorum)} support
                    </div>
                  </div>
                  <div className="p-2 rounded-lg bg-violet-500/10 text-violet-400">
                    <FiUsers className="w-4 h-4" />
                  </div>
                </div>
                <div className="mt-3 text-[11px] text-slate-500">
                  Open Proposals for support / execute · cleared from chain once executed.
                </div>
              </Link>
            )}
            {transactions.map((tx) => (
              <Link
                key={tx.id}
                to={`/chamber/${chamberAddress}/transactions`}
                className="block rounded-xl border border-slate-700/50 bg-slate-800/30 p-3 hover:border-slate-600 hover:bg-slate-800/50 transition-all"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-slate-200 text-sm">Proposal #{tx.id}</span>
                      <span className={`badge text-[10px] ${
                        tx.executed
                          ? 'badge-success'
                          : tx.status === 'Ready'
                          ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                          : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                      }`}>
                        {tx.status}
                      </span>
                    </div>
                    <div className="font-mono text-slate-500 text-xs mt-1">
                      {tx.target.slice(0, 8)}…{tx.target.slice(-6)}
                    </div>
                  </div>
                  <div className={`p-2 rounded-lg ${
                    tx.executed ? 'bg-emerald-500/10 text-emerald-400' : 'bg-slate-700/50 text-slate-400'
                  }`}>
                    {tx.executed ? <FiCheck className="w-4 h-4" /> : <FiClock className="w-4 h-4" />}
                  </div>
                </div>
                <div className="mt-3 flex items-center justify-between text-xs text-slate-500">
                  <span>{tx.confirmations} / {quorum} confirmations</span>
                  <span>{parseFloat(formatUnits(tx.value, 18)).toFixed(4)} ETH</span>
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <div className="rounded-xl border border-dashed border-slate-700/60 p-8 text-center">
            <FiActivity className="w-8 h-8 text-slate-600 mx-auto mb-3" />
            <div className="text-slate-300 text-sm font-medium">No recent activity</div>
            <p className="text-slate-500 text-xs mt-1">
              Wallet proposals and any active board-seat change appear here.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}

function AddressRow({ label, address, chainId }: { label: string; address: string | undefined; chainId: number }) {
  if (!address) return null
  const explorerUrl = getBlockExplorerAddressUrl(address, chainId)
  const short = `${address.slice(0, 8)}…${address.slice(-6)}`
  return (
    <div className="stat-card">
      <div className="text-slate-500 text-xs mb-1.5">{label}</div>
      <div className="flex items-center gap-2">
        <span className="font-mono text-slate-100 text-sm">{short}</span>
        <button
          onClick={() => { navigator.clipboard.writeText(address); toast.success('Copied!') }}
          className="p-1 rounded text-slate-600 hover:text-slate-300 transition-colors"
          title="Copy address"
        >
          <FiCopy className="w-3.5 h-3.5" />
        </button>
        {explorerUrl && (
          <a
            href={explorerUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="p-1 rounded text-slate-600 hover:text-accent-400 transition-colors"
            title="View on explorer"
          >
            <FiExternalLink className="w-3.5 h-3.5" />
          </a>
        )}
      </div>
    </div>
  )
}
