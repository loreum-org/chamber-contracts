import { useState, useEffect, useMemo, useRef } from 'react'
import { useParams, Link, useSearchParams } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { useAccount, useReadContracts, useChainId, useReadContract } from 'wagmi'
import { formatEther, isAddress, encodeFunctionData, parseAbi, parseEther, parseUnits } from 'viem'
import {
  FiArrowLeft,
  FiPlus,
  FiCheck,
  FiPlay,
  FiLoader,
  FiExternalLink,
  FiClock,
  FiShield,
  FiAlertCircle,
  FiSend,
  FiCode,
  FiDollarSign,
  FiHash,
  FiUsers,
  FiX,
} from 'react-icons/fi'
import toast from 'react-hot-toast'
import {
  useChamberInfo,
  useBoardMembers,
  useSubmitTransaction,
  useConfirmTransaction,
  useExecuteTransaction,
  useRevokeConfirmation,
  useCancelTransaction,
  useTransactionConfirmation,
  useTransactionCancelConfirmation,
  useChamberEvents,
  useReceiptRefresh,
  useIsChamber,
  useSeatUpdate,
  useUpdateSeats,
  useExecuteSeatsUpdate,
  useCancelSeatUpdate,
  useDirectorActionGate,
  useUserNFTs,
  useChamberRegistryImplementationSync,
  useProposalCalldata,
  queueWriteErrorMessage,
  queueWritePendingLabel,
  queueWriteSuccessMessage,
  type QueueWriteKind,
} from '@/hooks'
import { chamberAbi, erc20Abi } from '@/contracts/abis'
import {
  formatWalletSendError,
  getBlockExplorerAddressUrl,
  getBlockExplorerTxUrl,
  hasProposalCalldata,
  shortenAddress,
} from '@/lib/utils'
import { DirectorCallerStatus } from '@/components/DirectorCallerStatus'
import {
  UPGRADE_SELECTOR,
  PAUSE_SELECTOR,
  UNPAUSE_SELECTOR,
  SEAT_UPDATE_TIMELOCK_SEC,
  SEAT_UPDATE_EXPIRY_SEC,
  isAllowedChamberSelfCall,
  isChamberSelfCall,
  isUnpauseCall,
  selectorOf,
  requiredExecuteConfirmations,
  computeQueueTxStatus,
} from '@/lib/chamberGovernance'
import type { TransactionQueueItem } from '@/types'
import {
  createProposalMetadataURI,
  getProposalMetadata,
  parseProposalMetadataURI,
  setProposalMetadata,
} from '@/lib/proposalMetadata'
import {
  proposalCalldataMatchesHash,
  setStoredProposalCalldata,
} from '@/lib/proposalCalldata'
import type { SeatUpdate } from '@/types'

type TabType = 'queue' | 'history' | 'new'

type RiskLevel = 'low' | 'medium' | 'high'

type QueueWriteFlight = {
  kind: QueueWriteKind
  hash?: `0x${string}`
}

type QueueWriteReporters = {
  onWriteStart: (kind: QueueWriteKind) => void
  onWriteSent: (hash: `0x${string}`, kind: QueueWriteKind) => void
  onWriteClear: () => void
}

const MAX_BOARD_SEATS = 20

function PendingTxBanner({
  kind,
  hash,
  chainId,
}: {
  kind: QueueWriteKind
  hash?: `0x${string}`
  chainId: number
}) {
  const phase = hash ? 'chain' : 'wallet'
  const explorerUrl = hash && chainId !== 31337 ? getBlockExplorerTxUrl(hash, chainId) : undefined

  return (
    <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 px-4 py-3 text-sm text-amber-200">
      <div className="flex items-start gap-2">
        <FiLoader className="w-4 h-4 mt-0.5 shrink-0 animate-spin text-amber-400" />
        <div className="min-w-0">
          <p>{queueWritePendingLabel(kind, phase)}</p>
          {explorerUrl && (
            <a
              href={explorerUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-accent-400 hover:underline inline-flex items-center gap-1 mt-1"
            >
              View on explorer
              <FiExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
        </div>
      </div>
    </div>
  )
}

function classifyTransactionRisk(chamberAddress: `0x${string}`, target: `0x${string}`, value: bigint, data: `0x${string}`) {
  const isSelfCall = isChamberSelfCall(chamberAddress, target)
  const selector = selectorOf(data)
  const isUpgrade = isSelfCall && selector === UPGRADE_SELECTOR
  const isPause = isSelfCall && selector === PAUSE_SELECTOR
  const isUnpause = isSelfCall && selector === UNPAUSE_SELECTOR
  const hasUnknownCallData = data !== '0x' && !isUpgrade && !isPause && !isUnpause
  const sendsEth = value > 0n

  if (isUpgrade) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: protocol upgrade',
      summary: 'Changes Chamber implementation. Confirm implementation address, audit status, and migration notes before approval.',
    }
  }

  if (isPause) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: pause vault',
      summary: 'Halts deposits, withdrawals, and wallet execute until the board unpauses.',
    }
  }

  if (isUnpause) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: unpause vault',
      summary: 'Restores deposits, withdrawals, and wallet execute after a pause.',
    }
  }

  if (isSelfCall) {
    return {
      level: 'high' as RiskLevel,
      label: 'Invalid: Chamber self-call',
      summary: 'Proposals reject Chamber self-calls except upgrades. Use Board changes for seat changes.',
    }
  }

  if (sendsEth && hasUnknownCallData) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: ETH + contract call',
      summary: 'Transfers ETH while executing calldata. Review the target contract and decoded selector carefully.',
    }
  }

  if (sendsEth || hasUnknownCallData) {
    return {
      level: 'medium' as RiskLevel,
      label: sendsEth ? 'Medium risk: treasury transfer' : 'Medium risk: contract call',
      summary: sendsEth
        ? 'Moves treasury ETH. Verify recipient, amount, and proposal rationale.'
        : 'Executes calldata on an external contract. Verify function selector and target contract.',
    }
  }

  return {
    level: 'low' as RiskLevel,
    label: 'Low risk: no calldata',
    summary: 'Plain transaction with no calldata. Still verify recipient and amount before approval.',
  }
}

/** Risk summary when `getTransaction` only returns `dataHash` (no preimage in RPC). */
function classifyTransactionRiskFromDataHash(
  chamberAddress: `0x${string}`,
  target: `0x${string}`,
  value: bigint,
  dataHash: `0x${string}`
) {
  const isSelfCall = target.toLowerCase() === chamberAddress.toLowerCase()
  const hasCalldata = hasProposalCalldata(dataHash)
  const sendsEth = value > 0n

  if (isSelfCall && !hasCalldata) {
    return {
      level: 'high' as RiskLevel,
      label: 'Invalid: Chamber self-call',
      summary:
        'Proposals reject Chamber self-calls except upgrades. Use Board changes for seat changes.',
    }
  }

  if (isSelfCall && hasCalldata) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: Chamber self-call',
      summary:
        'Calls this Chamber from Treasury proposals. Verify calldata matches the intended action (e.g. upgrade) before approving.',
    }
  }

  if (sendsEth && hasCalldata) {
    return {
      level: 'high' as RiskLevel,
      label: 'High risk: ETH + contract call',
      summary:
        'Sends ETH with contract calldata. Review target, amount, and the exact calldata used at execution.',
    }
  }

  if (sendsEth || hasCalldata) {
    return {
      level: 'medium' as RiskLevel,
      label: sendsEth ? 'Medium risk: treasury transfer' : 'Medium risk: contract call',
      summary: sendsEth
        ? 'Moves treasury ETH. Verify recipient and amount before approval.'
        : 'Executes calldata on an external contract. The proposer must share the exact hex for execution.',
    }
  }

  return {
    level: 'low' as RiskLevel,
    label: 'Low risk: no calldata',
    summary: 'Plain ETH transfer with no calldata. Still verify recipient and amount.',
  }
}

export default function TransactionQueue() {
  const { address } = useParams<{ address: string }>()
  const validAddress = address && isAddress(address)
  const chamberAddr = validAddress ? (address as `0x${string}`) : undefined
  const isChamber = useIsChamber(chamberAddr)

  if (!validAddress) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
        <FiAlertCircle className="w-12 h-12 text-red-400" />
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
        <FiAlertCircle className="w-12 h-12 text-red-400" />
        <h2 className="font-heading text-xl font-bold text-slate-100">Not a Chamber</h2>
        <p className="text-slate-400">This address does not look like a Chamber contract.</p>
        <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
      </div>
    )
  }

  return <TransactionQueueContent chamberAddress={chamberAddr!} />
}

function TransactionQueueContent({ chamberAddress }: { chamberAddress: `0x${string}` }) {
  const { address: userAddress } = useAccount()
  const chainId = useChainId()
  const [searchParams, setSearchParams] = useSearchParams()

  const [activeTab, setActiveTab] = useState<TabType>('queue')
  const [inFlight, setInFlight] = useState<QueueWriteFlight | null>(null)
  type QueueTx = TransactionQueueItem & {
    cancelled?: boolean
    cancelConfirmations?: number
    metadataURI?: string
    leftoverTokenId?: bigint
  }

  const [transactions, setTransactions] = useState<QueueTx[]>([])
  
  const chamberInfo = useChamberInfo(chamberAddress)
  const implSync = useChamberRegistryImplementationSync(chamberAddress)
  const { members, isFetched: boardFetched } = useBoardMembers(chamberAddress, chamberInfo.seats || 5)
  const boardEmpty = boardFetched && members.length === 0
  const { seatUpdate, refetch: refetchSeatUpdate } = useSeatUpdate(chamberAddress)
  const { tokenIds: ownedTokenIds } = useUserNFTs(chamberInfo.nftToken, userAddress, {
    chamberAddress,
  })
  const directorGate = useDirectorActionGate(
    chamberAddress,
    userAddress,
    chamberInfo.directors,
    members,
  )
  const canAct = directorGate.canAct
  const userTokenId = directorGate.tokenId

  const upgradeProposalIntent = searchParams.get('proposal') === 'upgrade'
  const registryUpgradeDraft =
    upgradeProposalIntent &&
    implSync.implMismatch &&
    implSync.registryImplementation
      ? ({
          newImplementation: implSync.registryImplementation,
          chamberVersionLabel: implSync.chamberVersionLabel,
          registryVersionLabel: implSync.registryImplementationVersionLabel,
        } as const)
      : undefined

  const upgradeProposalHandledRef = useRef(false)
  useEffect(() => {
    if (!upgradeProposalIntent) {
      upgradeProposalHandledRef.current = false
      return
    }
    if (implSync.isLoading || upgradeProposalHandledRef.current) return

    upgradeProposalHandledRef.current = true

    if (!registryUpgradeDraft?.newImplementation) {
      toast('This chamber already matches the Registry’s default implementation.', { duration: 4500 })
      setSearchParams(
        (prev) => {
          const next = new URLSearchParams(prev)
          next.delete('proposal')
          return next
        },
        { replace: true },
      )
      return
    }

    setActiveTab('new')
  }, [
    upgradeProposalIntent,
    implSync.isLoading,
    registryUpgradeDraft?.newImplementation,
    registryUpgradeDraft,
    setSearchParams,
  ])

  // Fetch all transactions
  const transactionCount = chamberInfo.transactionCount || 0
  const transactionIds = Array.from({ length: transactionCount }, (_, i) => i)
  
  const { data: transactionsData, refetch: refetchTransactions } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransaction',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getTransaction'; args: [bigint] }[],
    query: {
      enabled: transactionCount > 0,
    },
  })

  const { data: cancelledData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getCancelled',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getCancelled'; args: [bigint] }[],
    query: {
      enabled: transactionCount > 0,
    },
  })

  const { data: cancelConfirmationsData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getCancelConfirmations',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getCancelConfirmations'; args: [bigint] }[],
    query: {
      enabled: transactionCount > 0,
    },
  })

  const { data: metadataData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransactionMetadata',
      args: [BigInt(id)],
    })) as readonly { address: `0x${string}`; abi: typeof chamberAbi; functionName: 'getTransactionMetadata'; args: [bigint] }[],
    query: {
      enabled: transactionCount > 0,
    },
  })

  const directorTokenKey = members.map((m) => m.tokenId.toString()).join(',')
  const directorTokenIds = useMemo(
    () => (directorTokenKey ? directorTokenKey.split(',').map((id) => BigInt(id)) : []),
    [directorTokenKey],
  )
  const ownedTokenKey = ownedTokenIds.map((id) => id.toString()).join(',')
  const ownedTokenIdsStable = useMemo(
    () => (ownedTokenKey ? ownedTokenKey.split(',').map((id) => BigInt(id)) : []),
    [ownedTokenKey],
  )

  const { data: requiredQuorumData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransactionRequiredQuorum' as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: transactionCount > 0, retry: false },
  })

  const { data: expiredData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'isTransactionExpired' as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: transactionCount > 0, retry: false },
  })

  const { data: deadlineData } = useReadContracts({
    contracts: transactionIds.map((id) => ({
      address: chamberAddress,
      abi: chamberAbi,
      functionName: 'getTransactionDeadline' as const,
      args: [BigInt(id)] as const,
    })),
    query: { enabled: transactionCount > 0, retry: false },
  })

  const { data: liveConfirmData } = useReadContracts({
    contracts: transactionIds.flatMap((id) =>
      directorTokenIds.map((tokenId) => ({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'getConfirmation' as const,
        args: [tokenId, BigInt(id)] as const,
      })),
    ),
    query: { enabled: transactionCount > 0 && directorTokenIds.length > 0 },
  })

  const { data: leftoverConfirmData } = useReadContracts({
    contracts: transactionIds.flatMap((id) =>
      ownedTokenIdsStable.map((tokenId) => ({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'getConfirmation' as const,
        args: [tokenId, BigInt(id)] as const,
      })),
    ),
    query: { enabled: transactionCount > 0 && ownedTokenIdsStable.length > 0 },
  })

  // Event watches are a fast path only. Receipt + refetch below is the source of truth.
  useChamberEvents(chamberAddress, {
    onTransactionEvent: () => {
      refetchTransactions()
    },
    onBoardEvent: () => {
      refetchSeatUpdate()
    },
  })

  const startQueueWrite = (kind: QueueWriteKind) => {
    setInFlight({ kind })
  }
  const sentQueueWrite = (hash: `0x${string}`, kind: QueueWriteKind) => {
    setInFlight({ kind, hash })
  }
  const clearQueueWrite = () => {
    setInFlight(null)
  }
  const writeReporters: QueueWriteReporters = {
    onWriteStart: startQueueWrite,
    onWriteSent: sentQueueWrite,
    onWriteClear: clearQueueWrite,
  }

  useReceiptRefresh({
    chamberAddress,
    hash: inFlight?.hash,
    successMessage: inFlight ? queueWriteSuccessMessage(inFlight.kind) : 'Transaction confirmed',
    errorMessage: inFlight ? queueWriteErrorMessage(inFlight.kind) : 'Transaction failed',
    onSuccess: () => {
      const kind = inFlight?.kind
      setInFlight(null)
      if (kind === 'submit' || kind === 'upgrade' || kind === 'seat-propose') {
        setSearchParams(
          (prev) => {
            const next = new URLSearchParams(prev)
            next.delete('proposal')
            return next
          },
          { replace: true },
        )
        setActiveTab('queue')
      }
      void chamberInfo.refetchTransactionCount()
      void refetchTransactions()
      void refetchSeatUpdate()
    },
    onError: () => {
      setInFlight(null)
    },
  })

  useEffect(() => {
    if (transactionsData) {
      const cancelledList: boolean[] = []
      cancelledData?.forEach((r: { status: string; result?: unknown }, i: number) => {
        cancelledList[i] = r.status === 'success' && r.result === true
      })

      const cancelConfirmationsList: number[] = []
      cancelConfirmationsData?.forEach((r: { status: string; result?: unknown }, i: number) => {
        cancelConfirmationsList[i] = r.status === 'success' && typeof r.result === 'bigint' ? Number(r.result) : 0
      })

      const metadataList: string[] = []
      metadataData?.forEach((r: { status: string; result?: unknown }, i: number) => {
        metadataList[i] = r.status === 'success' && typeof r.result === 'string' ? r.result : ''
      })

      const liveQuorum = chamberInfo.quorum || 1
      const directorCount = directorTokenIds.length
      const ownedCount = ownedTokenIdsStable.length

      const txs: QueueTx[] = []
      transactionsData.forEach((result, index) => {
        if (result.status === 'success' && result.result) {
          const [executed, confirmations, target, value, dataHash] = result.result as [
            boolean,
            number,
            `0x${string}`,
            bigint,
            `0x${string}`,
          ]
          const cancelled = cancelledList[index] ?? false
          const snapshotResult = requiredQuorumData?.[index]
          const snapshot =
            snapshotResult?.status === 'success' && snapshotResult.result !== undefined
              ? Number(snapshotResult.result)
              : undefined
          const required = requiredExecuteConfirmations(snapshot, liveQuorum)

          let liveConfirmations = 0
          if (directorCount > 0 && liveConfirmData) {
            const offset = index * directorCount
            for (let i = 0; i < directorCount; i++) {
              const row = liveConfirmData[offset + i]
              if (row?.status === 'success' && row.result === true) liveConfirmations += 1
            }
          } else {
            liveConfirmations = confirmations
          }

          const expiredResult = expiredData?.[index]
          const expired =
            expiredResult?.status === 'success' ? expiredResult.result === true : false
          const deadlineResult = deadlineData?.[index]
          const deadline =
            deadlineResult?.status === 'success' && typeof deadlineResult.result === 'bigint'
              ? deadlineResult.result
              : undefined

          let leftoverTokenId: bigint | undefined
          if (ownedCount > 0 && leftoverConfirmData) {
            const offset = index * ownedCount
            for (let i = 0; i < ownedCount; i++) {
              const row = leftoverConfirmData[offset + i]
              if (row?.status === 'success' && row.result === true) {
                leftoverTokenId = ownedTokenIdsStable[i]
                break
              }
            }
          }

          const status = computeQueueTxStatus({
            executed,
            cancelled,
            expired,
            liveConfirmations,
            requiredConfirmations: required,
          })
          txs.push({
            id: index,
            executed,
            confirmations,
            liveConfirmations,
            requiredConfirmations: required,
            target,
            value,
            dataHash,
            deadline,
            expired,
            status,
            cancelled,
            cancelConfirmations: cancelConfirmationsList[index] ?? 0,
            metadataURI: metadataList[index] || undefined,
            leftoverTokenId,
          })
        }
      })
      setTransactions(txs)
    }
  }, [
    transactionsData,
    cancelledData,
    cancelConfirmationsData,
    metadataData,
    requiredQuorumData,
    expiredData,
    deadlineData,
    liveConfirmData,
    leftoverConfirmData,
    chamberInfo.quorum,
    directorTokenIds,
    ownedTokenIdsStable,
  ])

  const pendingTransactions = transactions.filter(tx => tx.status === 'pending')
  const readyTransactions = transactions.filter(tx => tx.status === 'ready')
  const expiredTransactions = transactions.filter(tx => tx.status === 'expired')
  const cancelledTransactions = transactions.filter(tx => tx.cancelled)
  const executedTransactions = transactions.filter(tx => tx.executed)
  const hasSeatProposal = !!seatUpdate && seatUpdate.timestamp > 0n
  const seatProposalReady = hasSeatProposal && seatUpdate
    ? seatUpdate.supporters.length >= Number(seatUpdate.requiredQuorum) &&
      BigInt(Math.floor(Date.now() / 1000)) >= seatUpdate.timestamp + SEAT_UPDATE_TIMELOCK_SEC
    : false
  const boardProposalCount = hasSeatProposal ? 1 : 0
  const queueCount = pendingTransactions.length + readyTransactions.length + expiredTransactions.length + boardProposalCount

  const actionTokenId = canAct ? userTokenId : undefined

  return (
    <div className="space-y-6">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="panel p-6"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link
              to={`/chamber/${chamberAddress}`}
              className="p-2.5 rounded-xl bg-slate-800/80 text-slate-400 hover:text-accent-400 hover:bg-slate-800 transition-all"
            >
              <FiArrowLeft className="w-5 h-5" />
            </Link>
            <div>
              <h1 className="font-heading text-2xl font-bold text-slate-100 tracking-tight">
                Proposals
              </h1>
              <p className="text-slate-500 text-sm">
                {chamberInfo.name} • {chamberInfo.quorum} of {chamberInfo.seats} directors must confirm
              </p>
            </div>
          </div>

          {canAct ? (
            <button
              onClick={() => setActiveTab('new')}
              className="btn btn-primary"
            >
              <FiPlus className="w-4 h-4" />
              New Proposal
            </button>
          ) : (
            <div className="text-slate-500 text-sm italic hidden md:block">
              {directorGate.seatingPending ? 'Director seating is not mature yet' : 'Director access required'}
            </div>
          )}
        </div>

        {chamberInfo.paused && (
          <div className="mt-4 rounded-xl border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-200">
            This chamber is paused. Deposits, withdrawals, and execute are halted. Directors can still submit and confirm an unpause proposal.
          </div>
        )}
        <DirectorCallerStatus
          role={directorGate.role}
          tokenId={directorGate.tokenId}
          nftOwner={directorGate.nftOwner}
        />
        {directorGate.seatingPending && (
          <div className="mt-4 rounded-xl border border-amber-500/30 bg-amber-500/5 px-4 py-3 text-sm text-amber-200">
            You hold a live board seat, but director actions unlock at block {directorGate.seatedAt?.toString() ?? '…'}.
          </div>
        )}
        {inFlight && (
          <div className="mt-4">
            <PendingTxBanner kind={inFlight.kind} hash={inFlight.hash} chainId={chainId} />
          </div>
        )}
        {boardEmpty && (
          <div className="mt-4 rounded-xl border border-accent-500/30 bg-accent-500/5 px-4 py-3 text-sm text-slate-200">
            <p className="font-medium">No directors seated</p>
            <p className="text-slate-400 mt-1">
              Submit, confirm, and execute stay locked until you seat the board. Hold a membership token and delegate shares to it.
            </p>
            <Link
              to={`/chamber/${chamberAddress}/delegation`}
              className="text-accent-400 text-sm hover:underline mt-2 inline-block"
            >
              Seat the board →
            </Link>
          </div>
        )}

        {/* Stats */}
        <div className="grid grid-cols-6 gap-4 mt-6 pt-6 border-t border-slate-700/30">
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold text-amber-400">
              {pendingTransactions.length + (hasSeatProposal && !seatProposalReady ? 1 : 0)}
            </div>
            <div className="text-slate-500 text-xs mt-1">Pending</div>
          </div>
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold text-emerald-400">
              {readyTransactions.length + (seatProposalReady ? 1 : 0)}
            </div>
            <div className="text-slate-500 text-xs mt-1">Ready</div>
          </div>
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold text-red-400/80">
              {expiredTransactions.length}
            </div>
            <div className="text-slate-500 text-xs mt-1">Expired</div>
          </div>
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold text-slate-500">
              {cancelledTransactions.length}
            </div>
            <div className="text-slate-500 text-xs mt-1">Cancelled</div>
          </div>
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold text-slate-300">
              {executedTransactions.length}
            </div>
            <div className="text-slate-500 text-xs mt-1">Executed</div>
          </div>
          <div className="stat-card text-center">
            <div className="font-heading text-xl font-bold gradient-text">
              {transactions.length + boardProposalCount}
            </div>
            <div className="text-slate-500 text-xs mt-1">Total</div>
          </div>
        </div>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-slate-900/80 rounded-xl border border-slate-700/50">
        {[
          { id: 'queue', label: 'Proposals', count: queueCount },
          { id: 'history', label: 'History', count: executedTransactions.length },
          { id: 'new', label: 'New Proposal', count: 0 },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as TabType)}
            className={`
              relative flex items-center gap-2 px-4 py-2.5 rounded-lg transition-all flex-1 justify-center text-sm font-medium
              ${activeTab === tab.id ? 'text-accent-400' : 'text-slate-400 hover:text-slate-200'}
            `}
          >
            <span>{tab.label}</span>
            {tab.count > 0 && (
              <span className={`
                px-1.5 py-0.5 rounded-lg text-xs
                ${activeTab === tab.id ? 'bg-accent-500/20 text-accent-400' : 'bg-slate-800 text-slate-500'}
              `}>
                {tab.count}
              </span>
            )}
            {activeTab === tab.id && (
              <motion.div
                layoutId="tab-indicator-tx"
                className="absolute inset-0 bg-accent-500/10 border border-accent-500/30 rounded-lg"
                transition={{ type: 'spring', bounce: 0.2, duration: 0.6 }}
              />
            )}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <AnimatePresence mode="wait">
        {activeTab === 'queue' && (
          <motion.div
            key="queue"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="space-y-4"
          >
            {hasSeatProposal && seatUpdate && (
              <div className="space-y-3">
                <h3 className={`font-heading font-semibold flex items-center gap-2 ${
                  seatProposalReady ? 'text-emerald-400' : 'text-amber-400'
                }`}>
                  {seatProposalReady ? <FiPlay className="w-4 h-4" /> : <FiClock className="w-4 h-4" />}
                  Board changes
                </h3>
                <BoardProposalCard
                  chamberAddress={chamberAddress}
                  userTokenId={actionTokenId}
                  currentSeats={chamberInfo.seats ?? 5}
                  seatUpdate={seatUpdate}
                  {...writeReporters}
                />
              </div>
            )}

            {/* Ready to Execute */}
            {readyTransactions.length > 0 && (
              <div className="space-y-3">
                <h3 className="font-heading font-semibold text-emerald-400 flex items-center gap-2">
                  <FiPlay className="w-4 h-4" />
                  Ready to Execute
                </h3>
                {readyTransactions.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    transaction={tx}
                    chamberAddress={chamberAddress}
                    quorum={tx.requiredConfirmations}
                    userTokenId={actionTokenId}
                    leftoverTokenId={tx.leftoverTokenId}
                    paused={chamberInfo.paused}
                    chainId={chainId}
                    {...writeReporters}
                  />
                ))}
              </div>
            )}

            {/* Pending */}
            {pendingTransactions.length > 0 && (
              <div className="space-y-3">
                <h3 className="font-heading font-semibold text-amber-400 flex items-center gap-2">
                  <FiClock className="w-4 h-4" />
                  Pending Confirmations
                </h3>
                {pendingTransactions.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    transaction={tx}
                    chamberAddress={chamberAddress}
                    quorum={tx.requiredConfirmations}
                    userTokenId={actionTokenId}
                    leftoverTokenId={tx.leftoverTokenId}
                    paused={chamberInfo.paused}
                    chainId={chainId}
                    {...writeReporters}
                  />
                ))}

            {expiredTransactions.length > 0 && (
              <div className="space-y-3">
                <h3 className="font-heading font-semibold text-red-400/80 flex items-center gap-2">
                  <FiClock className="w-4 h-4" />
                  Expired
                </h3>
                {expiredTransactions.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    transaction={tx}
                    chamberAddress={chamberAddress}
                    quorum={tx.requiredConfirmations}
                    userTokenId={actionTokenId}
                    leftoverTokenId={tx.leftoverTokenId}
                    paused={chamberInfo.paused}
                    chainId={chainId}
                    {...writeReporters}
                  />
                ))}
              </div>
            )}
              </div>
            )}

            {/* Cancelled */}
            {cancelledTransactions.length > 0 && (
              <div className="space-y-3">
                <h3 className="font-heading font-semibold text-slate-500 flex items-center gap-2">
                  <FiX className="w-4 h-4" />
                  Cancelled
                </h3>
                {cancelledTransactions.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    transaction={tx}
                    chamberAddress={chamberAddress}
                    quorum={tx.requiredConfirmations}
                    userTokenId={actionTokenId}
                    leftoverTokenId={tx.leftoverTokenId}
                    paused={chamberInfo.paused}
                    chainId={chainId}
                    {...writeReporters}
                  />
                ))}
              </div>
            )}

            {pendingTransactions.length === 0 && readyTransactions.length === 0 && expiredTransactions.length === 0 && cancelledTransactions.length === 0 && !hasSeatProposal && (
              <div className="panel p-12 text-center">
                <FiShield className="w-12 h-12 text-slate-600 mx-auto mb-4" />
                {boardEmpty ? (
                  <>
                    <h3 className="font-heading text-xl font-semibold text-slate-300 mb-2">
                      Seat the board first
                    </h3>
                    <p className="text-slate-500 mb-6 max-w-sm mx-auto">
                      There are no directors, so Proposals cannot submit, confirm, or execute. Hold a membership token and delegate shares to it.
                    </p>
                    <Link
                      to={`/chamber/${chamberAddress}/delegation`}
                      className="btn btn-primary inline-flex"
                    >
                      Seat the board
                    </Link>
                  </>
                ) : (
                  <>
                    <h3 className="font-heading text-xl font-semibold text-slate-300 mb-2">
                      No Pending Proposals
                    </h3>
                    <p className="text-slate-500 mb-6 max-w-sm mx-auto">
                      Create a proposal with a title and description. {chamberInfo.quorum} of {chamberInfo.seats} directors must confirm before execution.
                    </p>
                    <button
                      onClick={() => setActiveTab('new')}
                      className="btn btn-primary inline-flex"
                    >
                      <FiPlus className="w-4 h-4" />
                      New Proposal
                    </button>
                  </>
                )}
              </div>
            )}

            {/* Non-director banner when there are pending txs */}
            {!canAct && (pendingTransactions.length > 0 || readyTransactions.length > 0 || expiredTransactions.length > 0 || cancelledTransactions.length > 0) && (
              <div className="panel p-4 border-amber-500/30 bg-amber-500/5">
                <p className="text-amber-400 text-sm">
                  You&apos;re not a director. Delegate shares to a member to participate in governance.
                </p>
                <Link
                  to={`/chamber/${chamberAddress}/delegation`}
                  className="text-accent-400 text-sm hover:underline mt-2 inline-block"
                >
                  Go to Delegation →
                </Link>
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'history' && (
          <motion.div
            key="history"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="space-y-3"
          >
            {executedTransactions.length > 0 ? (
              executedTransactions.map((tx) => (
                <TransactionCard
                  key={tx.id}
                  transaction={tx}
                  chamberAddress={chamberAddress}
                  quorum={tx.requiredConfirmations}
                  userTokenId={actionTokenId}
                  leftoverTokenId={tx.leftoverTokenId}
                  paused={chamberInfo.paused}
                  chainId={chainId}
                  {...writeReporters}
                />
              ))
            ) : (
              <div className="panel p-12 text-center">
                <FiCheck className="w-12 h-12 text-slate-600 mx-auto mb-4" />
                <h3 className="font-heading text-xl font-semibold text-slate-300 mb-2">
                  No Transaction History
                </h3>
                <p className="text-slate-500">
                  Executed transactions will appear here
                </p>
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'new' && (
          <motion.div
            key="new"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
          >
            {canAct ? (
              <NewTransactionForm
                key={registryUpgradeDraft?.newImplementation ?? 'default'}
                chamberAddress={chamberAddress}
                userTokenId={userTokenId}
                nextTransactionId={transactionCount}
                currentSeats={chamberInfo.seats ?? 5}
                quorum={chamberInfo.quorum ?? 1}
                hasSeatProposal={hasSeatProposal}
                registryUpgradeDraft={registryUpgradeDraft}
                {...writeReporters}
              />
            ) : (
              <div className="space-y-4">
                {registryUpgradeDraft && (
                  <div className="panel p-4 border border-amber-400/30 bg-amber-500/[0.08] rounded-xl text-left text-sm text-amber-50/95">
                    <p className="font-medium text-amber-100 flex items-center gap-2 mb-2">
                      <FiAlertCircle className="w-4 h-4 shrink-0 text-amber-400" aria-hidden />
                      Registry upgrade available
                    </p>
                    <p className="text-amber-100/85 mb-3 leading-relaxed">
                      Align this Chamber proxy with the Registry’s default implementation{' '}
                      <span className="font-mono tabular-nums">
                        ({shortenAddress(registryUpgradeDraft.newImplementation, 6)}
                        {registryUpgradeDraft.registryVersionLabel
                          ? ` · v${registryUpgradeDraft.registryVersionLabel}`
                          : ''}
                        )
                      </span>
                      . Ask a director to open this link (with{' '}
                      <span className="font-mono">?proposal=upgrade</span>
                      ), review the prefilled multisig proposal, then submit.
                    </p>
                    <div className="flex flex-wrap gap-2">
                      {chainId !== 31337 && (
                        <a
                          href={getBlockExplorerAddressUrl(registryUpgradeDraft.newImplementation, chainId)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="btn btn-secondary inline-flex py-2 text-sm"
                        >
                          New impl on explorer
                          <FiExternalLink className="w-4 h-4" />
                        </a>
                      )}
                    </div>
                  </div>
                )}
                <div className="panel p-10 text-center space-y-4">
                  <FiShield className="w-8 h-8 text-slate-600 mx-auto" />
                  <div>
                    <h3 className="font-heading text-lg font-semibold text-slate-300 mb-1">Directors only</h3>
                    <p className="text-slate-500 text-sm max-w-sm mx-auto">
                      Only active board directors can submit governance proposals. Delegate shares to a member to earn a board seat.
                    </p>
                  </div>
                  <Link
                    to={`/chamber/${chamberAddress}/delegation`}
                    className="btn btn-secondary inline-flex"
                  >
                    Go to Delegation
                    <FiArrowLeft className="w-4 h-4 rotate-180" />
                  </Link>
                </div>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

// Transaction Card Component
interface TransactionCardProps extends QueueWriteReporters {
  transaction: TransactionQueueItem & { cancelled?: boolean; cancelConfirmations?: number; metadataURI?: string; leftoverTokenId?: bigint }
  chamberAddress: `0x${string}`
  quorum: number
  userTokenId?: bigint
  leftoverTokenId?: bigint
  paused?: boolean
  chainId: number
}

function TransactionCard({
  transaction,
  chamberAddress,
  quorum,
  userTokenId,
  leftoverTokenId,
  paused,
  chainId,
  onWriteStart,
  onWriteSent,
  onWriteClear,
}: TransactionCardProps) {
  const { confirm, isPending: isConfirmPending, isConfirming: isConfirmWaiting, hash: confirmHash } = useConfirmTransaction(chamberAddress)
  const { execute, isPending: isExecutePending, isConfirming: isExecuteWaiting, hash: executeHash } = useExecuteTransaction(chamberAddress)
  const { revoke, isPending: isRevokePending, isConfirming: isRevokeWaiting, hash: revokeHash } = useRevokeConfirmation(chamberAddress)
  const { cancel, isPending: isCancelPending, isConfirming: isCancelWaiting, hash: cancelHash } = useCancelTransaction(chamberAddress)
  const isConfirming = isConfirmPending || isConfirmWaiting
  const isExecuting = isExecutePending || isExecuteWaiting
  const isRevoking = isRevokePending || isRevokeWaiting
  const isCancelling = isCancelPending || isCancelWaiting
  const cardWriteKind: QueueWriteKind | undefined = isConfirming
    ? 'confirm'
    : isExecuting
      ? 'execute'
      : isRevoking
        ? 'revoke'
        : isCancelling
          ? 'cancel'
          : undefined
  const cardWriteHash = isConfirming
    ? confirmHash
    : isExecuting
      ? executeHash
      : isRevoking
        ? revokeHash
        : isCancelling
          ? cancelHash
          : undefined
  const [executeCalldata, setExecuteCalldata] = useState('0x')
  const [calldataTouched, setCalldataTouched] = useState(false)
  const onchainMeta = parseProposalMetadataURI(transaction.metadataURI)
  const proposalMeta = onchainMeta || getProposalMetadata(chamberAddress, transaction.id)
  const metadataCalldata =
    proposalMeta?.calldata ??
    (() => {
      const custom = (proposalMeta as { custom?: { calldata?: string } } | null)?.custom
      return typeof custom?.calldata === 'string' ? custom.calldata : undefined
    })()
  const { data: resolvedCalldata, isLoading: isResolvingCalldata } = useProposalCalldata(
    chamberAddress,
    transaction.id,
    transaction.dataHash,
    metadataCalldata,
  )
  const { data: onchainStoredCalldata } = useReadContract({
    address: chamberAddress,
    abi: chamberAbi,
    functionName: 'getTransactionCalldata',
    args: [BigInt(transaction.id)],
    query: { enabled: hasProposalCalldata(transaction.dataHash), retry: false },
  })
  const hasOnchainPreimage =
    (typeof onchainStoredCalldata === 'string' && onchainStoredCalldata !== '0x') ||
    resolvedCalldata?.source === 'onchain'

  useEffect(() => {
    setExecuteCalldata('0x')
    setCalldataTouched(false)
  }, [transaction.id])

  useEffect(() => {
    if (calldataTouched || !resolvedCalldata) return
    setExecuteCalldata(resolvedCalldata.calldata)
  }, [resolvedCalldata, calldataTouched])
  const { isConfirmed: userHasConfirmed } = useTransactionConfirmation(
    chamberAddress,
    leftoverTokenId ?? userTokenId,
    transaction.id
  )
  const { hasVotedToCancel } = useTransactionCancelConfirmation(
    chamberAddress,
    userTokenId,
    transaction.id
  )

  const handleConfirm = async () => {
    if (!userTokenId) {
      toast.error('You must be a seated director to confirm')
      return
    }
    if (transaction.expired) {
      toast.error('This transaction has expired')
      return
    }
    onWriteStart('confirm')
    try {
      const hash = await confirm(userTokenId, BigInt(transaction.id))
      if (hash) onWriteSent(hash, 'confirm')
      else onWriteClear()
    } catch (err) {
      console.error(err)
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Confirmation failed'))
    }
  }

  const handleExecute = async () => {
    if (!userTokenId) {
      toast.error('You must be a seated director to execute')
      return
    }
    if (transaction.expired) {
      toast.error('This transaction has expired')
      return
    }
    const needsCalldata = hasProposalCalldata(transaction.dataHash)
    let calldata: `0x${string}` = '0x'
    if (needsCalldata) {
      const raw = executeCalldata.trim()
      if (!raw || raw === '0x') {
        if (hasOnchainPreimage) {
          calldata = '0x'
        } else {
          toast.error(
            isResolvingCalldata
              ? 'Loading calldata from chain… try again in a moment.'
              : 'Calldata not found. Paste the hex from the proposer or wait for archive sync — it must match the onchain hash.',
          )
          return
        }
      } else {
        calldata = (raw.startsWith('0x') ? raw : `0x${raw}`) as `0x${string}`
        if (!proposalCalldataMatchesHash(calldata, transaction.dataHash)) {
          toast.error('Calldata does not match the onchain commitment hash.')
          return
        }
      }
    }
    onWriteStart('execute')
    try {
      const hash = await execute(userTokenId, BigInt(transaction.id), calldata)
      if (hash) onWriteSent(hash, 'execute')
      else onWriteClear()
    } catch (err) {
      console.error(err)
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Execution failed'))
    }
  }

  const revokeTokenId = leftoverTokenId ?? userTokenId

  const handleRevoke = async () => {
    if (!revokeTokenId) {
      toast.error('No leftover confirmation to revoke')
      return
    }
    if (transaction.expired) {
      toast.error('This transaction has expired')
      return
    }
    onWriteStart('revoke')
    try {
      const hash = await revoke(revokeTokenId, BigInt(transaction.id))
      if (hash) onWriteSent(hash, 'revoke')
      else onWriteClear()
    } catch (err) {
      console.error(err)
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Revoke failed'))
    }
  }

  const handleCancel = async () => {
    if (!userTokenId) {
      toast.error('You must be a director to vote to cancel')
      return
    }
    onWriteStart('cancel')
    try {
      const hash = await cancel(userTokenId, BigInt(transaction.id))
      if (hash) onWriteSent(hash, 'cancel')
      else onWriteClear()
    } catch (err) {
      console.error(err)
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Cancel vote failed'))
    }
  }

  const shortTarget = `${transaction.target.slice(0, 10)}...${transaction.target.slice(-8)}`
  const hasData = hasProposalCalldata(transaction.dataHash)
  const displayTitle = proposalMeta?.title || (hasData ? 'Contract call' : 'Transaction')
  const risk = classifyTransactionRiskFromDataHash(chamberAddress, transaction.target, transaction.value, transaction.dataHash)
  const riskLevel = proposalMeta?.riskLevel || risk.level
  const riskSummary = proposalMeta?.riskSummary || risk.summary

  const isCancelled = transaction.cancelled === true
  const isExpired = transaction.status === 'expired' || transaction.expired === true
  const liveConfirmations = transaction.liveConfirmations ?? transaction.confirmations
  const requiredConfirmations = transaction.requiredConfirmations || quorum
  const executeBlockedByPause =
    !!paused &&
    !isUnpauseCall(
      chamberAddress,
      transaction.target,
      (resolvedCalldata?.calldata ?? executeCalldata) as `0x${string}`,
    )

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      className={`panel p-4 ${
        isCancelled
          ? 'opacity-60 border-slate-600/50 bg-slate-800/30'
          : isExpired
          ? 'opacity-70 border-red-500/25 bg-red-500/5'
          : transaction.executed
          ? 'opacity-75'
          : transaction.status === 'ready'
          ? 'border-emerald-500/30 bg-emerald-500/5'
          : ''
      }`}
    >
      <div className="flex items-start gap-4">
        {/* Transaction ID */}
        <div className={`
          w-12 h-12 rounded-xl flex items-center justify-center text-sm font-bold shrink-0
          ${isCancelled
            ? 'bg-slate-600/30 text-slate-500'
            : isExpired
            ? 'bg-red-500/15 text-red-400'
            : transaction.executed 
            ? 'bg-slate-500/20 text-slate-500' 
            : transaction.status === 'ready'
            ? 'bg-emerald-500/20 text-emerald-400'
            : 'bg-amber-500/20 text-amber-400'
          }
        `}>
          #{transaction.id}
        </div>

        {/* Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1 flex-wrap">
            <span className="font-semibold text-slate-100">{displayTitle}</span>
            <span className="font-mono text-slate-500 text-xs">{shortTarget}</span>
            <a
              href={chainId !== 31337 ? getBlockExplorerAddressUrl(transaction.target, chainId) : '#'}
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-500 hover:text-accent-400"
            >
              <FiExternalLink className="w-3 h-3" />
            </a>
            {transaction.executed && (
              <span className="badge badge-success">
                <FiCheck className="w-3 h-3 mr-1" />
                Executed
              </span>
            )}
            {!transaction.executed && transaction.status === 'ready' && !isCancelled && !isExpired && (
              <span className="badge badge-success">Ready</span>
            )}
            {isExpired && !transaction.executed && !isCancelled && (
              <span className="badge bg-red-500/15 text-red-400 border-red-500/30">Expired</span>
            )}
            {isCancelled && (
              <span className="badge bg-slate-600/50 text-slate-400 border-slate-500/30">
                <FiX className="w-3 h-3 mr-1" />
                Cancelled
              </span>
            )}
            <span className={`badge ${
              riskLevel === 'high'
                ? 'bg-red-500/10 text-red-400 border-red-500/30'
                : riskLevel === 'medium'
                ? 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
            }`}>
              {risk.label}
            </span>
          </div>

          {proposalMeta?.description && (
            <p className="text-slate-400 text-sm mb-2 line-clamp-2">{proposalMeta.description}</p>
          )}
          {!transaction.executed && !isCancelled && (
            <div className="mb-3 rounded-lg border border-slate-700/50 bg-slate-900/40 p-3 text-xs text-slate-400">
              <div className="flex items-start gap-2">
                <FiAlertCircle className="w-4 h-4 mt-0.5 text-amber-400 shrink-0" />
                <span>{riskSummary}</span>
              </div>
            </div>
          )}
          <div className="flex items-center gap-4 text-sm text-slate-400">
            <span className="flex items-center gap-1">
              <FiDollarSign className="w-3 h-3" />
              {formatEther(transaction.value)} ETH
            </span>
            {hasData && (
              <span className="flex items-center gap-1 font-mono text-[11px]" title={transaction.dataHash}>
                <FiCode className="w-3 h-3" />
                {`${transaction.dataHash.slice(0, 12)}…`}
              </span>
            )}
            <span className="flex items-center gap-1">
              <FiCheck className="w-3 h-3" />
              {liveConfirmations} / {requiredConfirmations}
            </span>
            {!isCancelled && !transaction.executed && (transaction.cancelConfirmations ?? 0) > 0 && (
              <span className="flex items-center gap-1 text-amber-400/80">
                <FiX className="w-3 h-3" />
                {transaction.cancelConfirmations} / {quorum} cancel votes
              </span>
            )}
          </div>

          {!transaction.executed && !isCancelled && transaction.status === 'ready' && hasData && (
            <div className="mt-3 space-y-1.5">
              <label className="block text-slate-500 text-xs font-medium">
                Execution calldata (hex)
              </label>
              {isResolvingCalldata && !calldataTouched && (
                <p className="text-slate-500 text-xs flex items-center gap-1.5">
                  <FiLoader className="w-3 h-3 animate-spin" />
                  Loading calldata from submission event…
                </p>
              )}
              {resolvedCalldata && !calldataTouched && (
                <p className="text-emerald-400/90 text-xs">
                  Calldata loaded from{' '}
                  {resolvedCalldata.source === 'onchain'
                    ? 'on-chain calldata store'
                    : resolvedCalldata.source === 'event'
                      ? 'onchain submit event'
                      : resolvedCalldata.source === 'metadata'
                        ? 'proposal metadata'
                        : 'this browser'}
                  — review before executing.
                </p>
              )}
              {!isResolvingCalldata && !resolvedCalldata && executeCalldata === '0x' && hasOnchainPreimage && (
                <p className="text-emerald-400/90 text-xs">
                  Calldata is stored on-chain. Execute may pass empty data.
                </p>
              )}
              {!isResolvingCalldata && !resolvedCalldata && executeCalldata === '0x' && !hasOnchainPreimage && (
                <p className="text-amber-400/90 text-xs">
                  Calldata not archived here. Ask the proposer for the hex, or paste from your records.
                </p>
              )}
              <textarea
                className="input font-mono text-xs min-h-[4rem] resize-y w-full"
                placeholder="0x… (must match onchain hash)"
                value={executeCalldata}
                onChange={(e) => {
                  setCalldataTouched(true)
                  setExecuteCalldata(e.target.value)
                }}
                spellCheck={false}
              />
            </div>
          )}

          {/* Progress bar */}
          {!transaction.executed && !isCancelled && (
            <div className="mt-3 h-1.5 bg-slate-800 rounded-full overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${(liveConfirmations / Math.max(1, requiredConfirmations)) * 100}%` }}
                className={`h-full rounded-full ${
                  transaction.status === 'ready'
                    ? 'bg-emerald-500'
                    : 'bg-amber-500'
                }`}
              />
            </div>
          )}
        </div>

        {/* Actions */}
        {!transaction.executed && !isCancelled && (userTokenId !== undefined || leftoverTokenId !== undefined) && (
          <div className="flex items-center gap-2">
            {userTokenId !== undefined && (
              <button
                onClick={handleCancel}
                disabled={isCancelling || hasVotedToCancel}
                className="btn btn-secondary py-2 px-3 border-slate-600 hover:border-slate-500 text-slate-400 hover:text-slate-200"
                title={hasVotedToCancel ? 'You have voted to cancel' : `Vote to cancel (${requiredConfirmations} directors must confirm)`}
              >
                {isCancelling ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : hasVotedToCancel ? (
                  <>
                    <FiX className="w-4 h-4" />
                    Voted to cancel
                  </>
                ) : (
                  <>
                    <FiX className="w-4 h-4" />
                    Cancel
                  </>
                )}
              </button>
            )}
            {!isExpired && (leftoverTokenId !== undefined || userHasConfirmed) && (
              <button
                onClick={handleRevoke}
                disabled={isRevoking}
                className="btn btn-secondary py-2 px-3 border-amber-500/30 hover:border-amber-500/50"
                title={leftoverTokenId !== undefined && userTokenId === undefined
                  ? 'Revoke leftover confirmation from a former seat'
                  : 'Revoke your confirmation'}
              >
                {isRevoking ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : (
                  'Revoke'
                )}
              </button>
            )}
            {userTokenId !== undefined && !isExpired && transaction.status !== 'ready' && (
              <button
                onClick={handleConfirm}
                disabled={isConfirming || userHasConfirmed}
                className="btn btn-secondary py-2 px-3"
              >
                {isConfirming ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <FiCheck className="w-4 h-4" />
                    Confirm
                  </>
                )}
              </button>
            )}
            {userTokenId !== undefined && !isExpired && transaction.status === 'ready' && (
              <button
                onClick={handleExecute}
                disabled={isExecuting || executeBlockedByPause}
                className="btn btn-primary py-2 px-3"
                title={executeBlockedByPause ? 'Chamber is paused' : undefined}
              >
                {isExecuting ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <FiPlay className="w-4 h-4" />
                    Execute
                  </>
                )}
              </button>
            )}
          </div>
        )}
      </div>

      {cardWriteKind && (
        <div className="mt-4">
          <PendingTxBanner kind={cardWriteKind} hash={cardWriteHash} chainId={chainId} />
        </div>
      )}

      {/* Calldata hash / preimage note */}
      {hasData ? (
        <div className="mt-4 pt-4 border-t border-slate-700/30">
          <div className="text-slate-500 text-xs mb-1">Calldata commitment (keccak256)</div>
          <code className="block text-slate-400 text-xs font-mono bg-slate-800/50 p-2 rounded-lg overflow-x-auto break-all">
            {transaction.dataHash}
          </code>
          <p className="text-slate-500 text-xs mt-2">
            {hasOnchainPreimage
              ? 'Self-call calldata is stored on-chain. Execute may pass empty data, or re-supply the original bytes.'
              : 'Only the hash is stored onchain. To execute, directors must supply the exact calldata bytes (or use 0x for plain ETH with no call data).'}
          </p>
        </div>
      ) : null}
        {transaction.metadataURI && (
          <div className="mt-3 text-[11px] text-slate-500 font-mono break-all">
            Metadata: {transaction.metadataURI}
          </div>
        )}
    </motion.div>
  )
}

// Proposal templates for quick creation
const PROPOSAL_TEMPLATES = [
  { id: 'grant', label: 'Grant', title: 'Grant', description: '', txType: 'eth' as const },
  { id: 'token-payment', label: 'Token Payment', title: 'Token Payment', description: '', txType: 'token' as const },
  { id: 'treasury-transfer', label: 'Treasury Transfer', title: 'Treasury Transfer', description: '', txType: 'eth' as const },
  { id: 'custom', label: 'Custom Call', title: '', description: '', txType: 'custom' as const },
]

function formatDurationSeconds(total: number): string {
  if (total <= 0) return '0m'
  const d = Math.floor(total / 86400)
  const h = Math.floor((total % 86400) / 3600)
  const m = Math.floor((total % 3600) / 60)
  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${Math.max(1, m)}m`
}

function BoardProposalCard({
  chamberAddress,
  userTokenId,
  currentSeats,
  seatUpdate,
  onWriteStart,
  onWriteSent,
  onWriteClear,
}: {
  chamberAddress: `0x${string}`
  userTokenId: bigint | undefined
  currentSeats: number
  seatUpdate: SeatUpdate
} & QueueWriteReporters) {
  const chainId = useChainId()
  const { updateSeats, isPending: isSupportPending, isConfirming: isSupportConfirming, hash: supportHash } =
    useUpdateSeats(chamberAddress)
  const {
    executeSeatsUpdate,
    isPending: isExecPending,
    isConfirming: isExecConfirming,
    hash: execHash,
  } = useExecuteSeatsUpdate(chamberAddress)
  const {
    cancelSeatUpdate,
    isPending: isCancelPending,
    isConfirming: isCancelConfirming,
    hash: cancelHash,
  } = useCancelSeatUpdate(chamberAddress)
  const seatWriteKind: QueueWriteKind | undefined =
    isSupportPending || isSupportConfirming
      ? 'seat-support'
      : isExecPending || isExecConfirming
        ? 'seat-execute'
        : isCancelPending || isCancelConfirming
          ? 'seat-cancel'
          : undefined
  const seatWriteHash =
    isSupportPending || isSupportConfirming
      ? supportHash
      : isExecPending || isExecConfirming
        ? execHash
        : isCancelPending || isCancelConfirming
          ? cancelHash
          : undefined

  const supported =
    userTokenId !== undefined &&
    seatUpdate.supporters.some((id) => id === userTokenId)
  const nowSec = BigInt(Math.floor(Date.now() / 1000))
  const timelockEnd = seatUpdate.timestamp + SEAT_UPDATE_TIMELOCK_SEC
  const expiryEnd = seatUpdate.timestamp + SEAT_UPDATE_EXPIRY_SEC
  const timelockExpired = nowSec >= timelockEnd
  const proposalExpired = nowSec >= expiryEnd
  const supporterCount = seatUpdate.supporters.length
  const requiredQuorum = Number(seatUpdate.requiredQuorum)
  const quorumReached = supporterCount >= requiredQuorum
  const ready = quorumReached && timelockExpired
  const isProposer =
    userTokenId !== undefined &&
    seatUpdate.supporters.length > 0 &&
    seatUpdate.supporters[0] === userTokenId
  const canCancelProposal = userTokenId !== undefined && (isProposer || proposalExpired)
  const busy = isSupportPending || isSupportConfirming || isExecPending || isExecConfirming || isCancelPending || isCancelConfirming

  const support = async () => {
    if (userTokenId === undefined) {
      toast.error('You must be a director to support board proposals')
      return
    }
    onWriteStart('seat-support')
    try {
      const hash = await updateSeats(userTokenId, seatUpdate.proposedSeats)
      if (hash) onWriteSent(hash, 'seat-support')
      else onWriteClear()
    } catch (err) {
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Support failed'))
    }
  }

  const execute = async () => {
    if (userTokenId === undefined) {
      toast.error('You must be a director to execute board proposals')
      return
    }
    onWriteStart('seat-execute')
    try {
      const hash = await executeSeatsUpdate(userTokenId)
      if (hash) onWriteSent(hash, 'seat-execute')
      else onWriteClear()
    } catch (err) {
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Execute failed'))
    }
  }

  const cancelProposal = async () => {
    if (userTokenId === undefined) {
      toast.error('You must be a director to cancel board proposals')
      return
    }
    onWriteStart('seat-cancel')
    try {
      const hash = await cancelSeatUpdate(userTokenId)
      if (hash) onWriteSent(hash, 'seat-cancel')
      else onWriteClear()
    } catch (err) {
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Cancel failed'))
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      className={`panel p-4 ${ready ? 'border-emerald-500/30 bg-emerald-500/5' : 'border-amber-500/30 bg-amber-500/5'}`}
    >
      <div className="flex items-start gap-4">
        <div className={`
          w-12 h-12 rounded-xl flex items-center justify-center text-sm font-bold shrink-0
          ${ready ? 'bg-emerald-500/20 text-emerald-400' : 'bg-amber-500/20 text-amber-400'}
        `}>
          <FiUsers className="w-5 h-5" />
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1 flex-wrap">
            <span className="font-semibold text-slate-100">Board changes</span>
            <span className="badge bg-accent-500/10 text-accent-400 border-accent-500/30">Board changes</span>
            <span className={ready ? 'badge badge-success' : 'badge bg-amber-500/10 text-amber-400 border-amber-500/30'}>
              {ready ? 'Ready' : 'Pending'}
            </span>
          </div>

          <p className="text-slate-400 text-sm mb-3">
            Change board seats from <span className="text-slate-200 font-mono">{currentSeats}</span> to{' '}
            <span className="text-slate-200 font-mono">{String(seatUpdate.proposedSeats)}</span>.
          </p>

          <div className="mb-3 rounded-lg border border-slate-700/50 bg-slate-900/40 p-3 text-xs text-slate-400">
            <div className="grid gap-2 sm:grid-cols-3">
              <span>
                Support:{' '}
                <span className="text-slate-200 font-mono">
                  {supporterCount} / {requiredQuorum}
                </span>
              </span>
              <span>
                Timelock:{' '}
                <span className={timelockExpired ? 'text-emerald-400' : 'text-slate-200'}>
                  {timelockExpired ? 'Unlocked' : `~${formatDurationSeconds(Math.max(0, Number(timelockEnd - nowSec)))} left`}
                </span>
              </span>
              <span>
                Cancel after:{' '}
                <span className={proposalExpired ? 'text-amber-300' : 'text-slate-200'}>
                  {proposalExpired ? 'Any director' : `~${formatDurationSeconds(Math.max(0, Number(expiryEnd - nowSec)))} (14d)`}
                </span>
              </span>
              <span>
                Supporters:{' '}
                <span className="text-slate-200 font-mono">
                  {seatUpdate.supporters.map((id) => `#${id.toString()}`).join(', ') || 'None'}
                </span>
              </span>
            </div>
          </div>

          <div className="h-1.5 bg-slate-800 rounded-full overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${Math.min(100, (supporterCount / Math.max(1, requiredQuorum)) * 100)}%` }}
              className={ready ? 'h-full rounded-full bg-emerald-500' : 'h-full rounded-full bg-amber-500'}
            />
          </div>
        </div>

        {userTokenId !== undefined && (
          <div className="flex items-center gap-2">
            {!supported && (
              <button
                type="button"
                onClick={() => void support()}
                disabled={busy}
                className="btn btn-secondary py-2 px-3"
              >
                {isSupportPending || isSupportConfirming ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <FiCheck className="w-4 h-4" />
                    Support
                  </>
                )}
              </button>
            )}
            {canCancelProposal && (
              <button
                type="button"
                onClick={() => void cancelProposal()}
                disabled={busy}
                className="btn btn-secondary py-2 px-3 border-slate-600 hover:border-slate-500 text-slate-400 hover:text-slate-200"
                title={isProposer ? 'Proposer can cancel anytime' : 'Proposal expired — any director may cancel'}
              >
                {isCancelPending || isCancelConfirming ? (
                  <FiLoader className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <FiX className="w-4 h-4" />
                    Cancel
                  </>
                )}
              </button>
            )}
            <button
              type="button"
              onClick={() => void execute()}
              disabled={busy || !ready}
              className="btn btn-primary py-2 px-3"
            >
              {isExecPending || isExecConfirming ? (
                <FiLoader className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <FiPlay className="w-4 h-4" />
                  Execute
                </>
              )}
            </button>
          </div>
        )}
      </div>

      {seatWriteKind && (
        <div className="mt-4">
          <PendingTxBanner kind={seatWriteKind} hash={seatWriteHash} chainId={chainId} />
        </div>
      )}
    </motion.div>
  )
}

// New Transaction Form
interface NewTransactionFormProps extends QueueWriteReporters {
  chamberAddress: `0x${string}`
  userTokenId?: bigint
  nextTransactionId: number
  currentSeats: number
  quorum: number
  hasSeatProposal: boolean
  registryUpgradeDraft?: {
    newImplementation: `0x${string}`
    chamberVersionLabel?: string
    registryVersionLabel?: string
  }
}

// Helper to get placeholder text for different parameter types
function getPlaceholder(type: string): string {
  if (type === 'address') return '0x...'
  if (type.startsWith('uint') || type.startsWith('int')) return '0'
  if (type === 'bool') return 'true or false'
  if (type === 'bytes' || type.startsWith('bytes')) return '0x...'
  if (type === 'string') return 'Enter text...'
  if (type.endsWith('[]')) return 'Comma-separated values or JSON array'
  return 'Enter value...'
}

// Helper to parse function signature and extract parameter info
interface ParsedParam {
  name: string
  type: string
}

function parseFunctionSignature(sig: string): { name: string; params: ParsedParam[] } | null {
  try {
    // Match pattern like "functionName(type1,type2)" or "functionName(type1 name1, type2 name2)"
    const match = sig.match(/^(\w+)\((.*)\)$/)
    if (!match) return null

    const name = match[1]
    const paramsStr = match[2].trim()
    
    if (!paramsStr) {
      return { name, params: [] }
    }

    const params: ParsedParam[] = paramsStr.split(',').map((param, index) => {
      const parts = param.trim().split(/\s+/)
      const type = parts[0]
      const paramName = parts[1] || `param${index}`
      return { name: paramName, type }
    })

    return { name, params }
  } catch {
    return null
  }
}

// Helper to convert input value to the correct type for encoding
function parseParamValue(value: string, type: string): unknown {
  if (type === 'address') {
    return value as `0x${string}`
  }
  if (type.startsWith('uint') || type.startsWith('int')) {
    if (value.includes('.')) {
      // Use parseUnits for decimal input to avoid float precision loss
      try {
        return parseUnits(value, 18)
      } catch {
        return BigInt(Math.trunc(Number(value)))
      }
    }
    return BigInt(value)
  }
  if (type === 'bool') {
    return value.toLowerCase() === 'true' || value === '1'
  }
  if (type === 'bytes' || type.startsWith('bytes')) {
    return value as `0x${string}`
  }
  if (type.endsWith('[]')) {
    // Array type - parse as JSON
    try {
      return JSON.parse(value)
    } catch {
      return value.split(',').map(v => v.trim())
    }
  }
  return value
}

function NewTransactionForm({
  chamberAddress,
  userTokenId,
  nextTransactionId,
  currentSeats,
  quorum,
  hasSeatProposal,
  registryUpgradeDraft,
  onWriteStart,
  onWriteSent,
  onWriteClear,
}: NewTransactionFormProps) {
  const { address: userAddress } = useAccount()
  const chainId = useChainId()
  const [proposalType, setProposalType] = useState<'transaction' | 'seats'>('transaction')
  const [txType, setTxType] = useState<'eth' | 'token' | 'custom'>('eth')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [target, setTarget] = useState('')
  const [value, setValue] = useState('')
  const [data, setData] = useState('0x')
  const [tokenAddress, setTokenAddress] = useState('')
  const [tokenAmount, setTokenAmount] = useState('')
  const [seatDraft, setSeatDraft] = useState(String(currentSeats))

  // Fetch decimals for the token being proposed — avoids hardcoding 18
  const { data: tokenDecimalsData } = useReadContract({
    address: isAddress(tokenAddress) ? tokenAddress as `0x${string}` : undefined,
    abi: erc20Abi,
    functionName: 'decimals',
    query: { enabled: isAddress(tokenAddress) },
  })
  const tokenDecimals = typeof tokenDecimalsData === 'number' ? tokenDecimalsData : 18
  
  // Custom transaction state
  const [functionSig, setFunctionSig] = useState('')
  const [parsedFunction, setParsedFunction] = useState<{ name: string; params: ParsedParam[] } | null>(null)
  const [paramValues, setParamValues] = useState<Record<string, string>>({})
  const [sigError, setSigError] = useState<string | null>(null)
  const [encodedData, setEncodedData] = useState<string>('0x')

  const { submit, isPending, isConfirming, hash: submitHash } = useSubmitTransaction(chamberAddress)
  const {
    updateSeats: proposeSeats,
    isPending: isSeatPending,
    isConfirming: isSeatConfirming,
    hash: seatHash,
  } = useUpdateSeats(chamberAddress)

  const previewTarget = (txType === 'token' ? tokenAddress : target) as `0x${string}`
  const previewValue = txType === 'eth' && value ? (() => { try { return parseEther(value) } catch { return 0n } })() : 0n
  const previewData = txType === 'custom' ? (encodedData as `0x${string}`) : txType === 'token' ? (data as `0x${string}`) : '0x'
  const previewRisk = proposalType === 'transaction' && isAddress(previewTarget)
    ? classifyTransactionRisk(chamberAddress, previewTarget, previewValue, previewData)
    : null
  const busy = isPending || isConfirming || isSeatPending || isSeatConfirming

  const registryUpgradePrefilledRef = useRef<string | undefined>(undefined)

  useEffect(() => {
    if (!registryUpgradeDraft?.newImplementation) {
      registryUpgradePrefilledRef.current = undefined
      return
    }
    const impl = registryUpgradeDraft.newImplementation
    if (registryUpgradePrefilledRef.current === impl) return
    registryUpgradePrefilledRef.current = impl

    setProposalType('transaction')
    setTxType('custom')
    setTarget(chamberAddress)
    setValue('0')

    const regV = registryUpgradeDraft.registryVersionLabel
    const curV = registryUpgradeDraft.chamberVersionLabel
    setTitle(`Upgrade Chamber to Registry implementation${regV ? ` v${regV}` : ''}`)
    setDescription(
      `Multisig: upgradeImplementation(${impl}, 0x). Current proxy implementation VERSION reports ${curV ?? 'unknown'}. Confirm audit status and migrations before approving; init calldata left empty.`,
    )
    setFunctionSig('upgradeImplementation(address,bytes)')
  }, [
    chamberAddress,
    registryUpgradeDraft?.newImplementation,
    registryUpgradeDraft?.registryVersionLabel,
    registryUpgradeDraft?.chamberVersionLabel,
    registryUpgradeDraft,
  ])

  // Parse function signature when it changes
  useEffect(() => {
    if (!functionSig.trim()) {
      setParsedFunction(null)
      setSigError(null)
      setEncodedData('0x')
      return
    }

    const parsed = parseFunctionSignature(functionSig.trim())
    if (parsed) {
      setParsedFunction(parsed)
      setSigError(null)
      // Reset param values when signature changes
      setParamValues({})
    } else {
      setParsedFunction(null)
      setSigError('Invalid function signature. Example: transfer(address,uint256)')
    }
  }, [functionSig])

  // After Registry-upgrade prefill parses, repopulate params (signature effect resets param maps).
  useEffect(() => {
    const impl = registryUpgradeDraft?.newImplementation
    if (!impl) return
    if (parsedFunction?.name !== 'upgradeImplementation') return
    setParamValues({ param0: impl, param1: '0x' })
  }, [registryUpgradeDraft?.newImplementation, parsedFunction])

  // Encode function data when params change
  useEffect(() => {
    if (!parsedFunction) {
      setEncodedData('0x')
      return
    }

    try {
      // Build the ABI from the signature
      const abiStr = `function ${functionSig}`
      const abi = parseAbi([abiStr])
      
      // Parse all param values
      const args = parsedFunction.params.map((param, index) => {
        const value = paramValues[`param${index}`] || ''
        return parseParamValue(value, param.type)
      })

      // Only encode if all required params have values
      const hasAllParams = parsedFunction.params.every((_, index) => paramValues[`param${index}`]?.trim())
      
      if (hasAllParams || parsedFunction.params.length === 0) {
        // parseAbi returns a fully validated ABI; cast needed for dynamic function names
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const encoded = encodeFunctionData({
          abi: abi as any,
          functionName: parsedFunction.name,
          args,
        })
        setEncodedData(encoded)
        setData(encoded)
      } else {
        setEncodedData('0x')
      }
    } catch (err) {
      console.error('Encoding error:', err)
      setEncodedData('0x')
    }
  }, [parsedFunction, paramValues, functionSig])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!userTokenId) {
      toast.error('You must be a director to submit proposals')
      return
    }

    if (proposalType === 'seats') {
      if (hasSeatProposal) {
        toast.error('A board change is already active. Support or execute it from Proposals.')
        return
      }
      const n = Number(seatDraft)
      if (!Number.isInteger(n) || n < 1) {
        toast.error('Invalid seat count')
        return
      }
      if (n > MAX_BOARD_SEATS) {
        toast.error(`Seat count cannot exceed ${MAX_BOARD_SEATS}`)
        return
      }
      if (n === currentSeats) {
        toast.error('Choose a different seat count than the current configuration')
        return
      }

      onWriteStart('seat-propose')
      try {
        const hash = await proposeSeats(userTokenId, BigInt(n))
        if (hash) onWriteSent(hash, 'seat-propose')
        else onWriteClear()
      } catch (err) {
        console.error(err)
        onWriteClear()
        toast.error(formatWalletSendError(err, 'Board change failed'))
      }
      return
    }

    if (!isAddress(target)) {
      toast.error('Invalid target address')
      return
    }

    try {
      let txData = data as `0x${string}`
      let txValue = BigInt(0)

      if (txType === 'eth') {
        try {
          txValue = parseEther(value)
        } catch {
          toast.error('Invalid ETH amount')
          return
        }
        txData = '0x'
      } else if (txType === 'token') {
        if (!isAddress(tokenAddress)) {
          toast.error('Invalid token contract address')
          return
        }
        let parsedTokenAmount: bigint
        try {
          parsedTokenAmount = parseUnits(tokenAmount, tokenDecimals ?? 18)
        } catch {
          toast.error('Invalid token amount')
          return
        }
        // Encode ERC20 transfer call
        txData = encodeFunctionData({
          abi: erc20Abi,
          functionName: 'transfer',
          args: [target as `0x${string}`, parsedTokenAmount],
        })
        if (!isAllowedChamberSelfCall(chamberAddress, tokenAddress, txData)) {
          toast.error('Chamber self-calls are only allowed for upgrades. Use Board changes for seat changes.')
          return
        }
        // Target becomes token address
        const metaTitle = title.trim() || `Send ${tokenAmount} tokens`
        const metadata = {
          title: metaTitle,
          description: description.trim() || undefined,
          templateId: txType,
          target: tokenAddress,
          valueEth: '0',
          functionName: 'transfer',
          calldata: txData,
          riskLevel: 'medium' as RiskLevel,
          riskSummary: 'Token transfer proposal. Verify token contract, recipient, amount, and treasury balance.',
        }
        const metadataURI = createProposalMetadataURI(metadata)
        onWriteStart('submit')
        const hash = await submit(userTokenId, tokenAddress as `0x${string}`, 0n, txData, metadataURI)
        setStoredProposalCalldata(chamberAddress, nextTransactionId, txData)
        setProposalMetadata(chamberAddress, nextTransactionId, { ...metadata, metadataURI })
        if (hash) onWriteSent(hash, 'submit')
        else onWriteClear()
        return
      } else if (txType === 'custom') {
        try {
          txValue = value ? parseEther(value) : 0n
        } catch {
          toast.error('Invalid ETH value')
          return
        }
        txData = encodedData as `0x${string}`
      }

      if (!isAllowedChamberSelfCall(chamberAddress, target, txData)) {
        toast.error('Chamber self-calls are only allowed for upgrades. Use Board changes for seat changes.')
        return
      }

      // Store proposal metadata (title/description) for display
      const metaTitle = title.trim() || (txType === 'eth' ? `Send ${value} ETH` : parsedFunction?.name || 'Custom Transaction')
      const risk = classifyTransactionRisk(chamberAddress, target as `0x${string}`, txValue, txData)
      const metadata = {
        title: metaTitle,
        description: description.trim() || undefined,
        templateId: txType,
        target,
        valueEth: formatEther(txValue),
        functionName: txType === 'custom' ? parsedFunction?.name : undefined,
        calldata: txData !== '0x' ? txData : undefined,
        riskLevel: risk.level,
        riskSummary: risk.summary,
      }
      const metadataURI = createProposalMetadataURI(metadata)
      const writeKind: QueueWriteKind =
        parsedFunction?.name === 'upgradeImplementation' || selectorOf(txData) === UPGRADE_SELECTOR
          ? 'upgrade'
          : 'submit'
      onWriteStart(writeKind)
      const hash = await submit(userTokenId, target as `0x${string}`, txValue, txData, metadataURI)
      if (txData !== '0x') {
        setStoredProposalCalldata(chamberAddress, nextTransactionId, txData)
      }
      setProposalMetadata(chamberAddress, nextTransactionId, { ...metadata, metadataURI })
      if (hash) onWriteSent(hash, writeKind)
      else onWriteClear()
    } catch (err) {
      console.error(err)
      onWriteClear()
      toast.error(formatWalletSendError(err, 'Failed to submit transaction'))
    }
  }

  if (!userTokenId) {
    return (
      <div className="panel p-8 text-center">
        <FiAlertCircle className="w-12 h-12 text-amber-500 mx-auto mb-4" />
        <h3 className="font-heading text-xl font-semibold text-slate-100 mb-2">
          Director Access Required
        </h3>
        <p className="text-slate-400 mb-4">
          You must be a board director to submit proposals.
          Delegate shares to your member token to become a director.
        </p>
        <div className="text-left bg-slate-800/50 rounded-lg p-4 mt-4 text-xs">
          <div className="text-slate-500 mb-2">Debug Info:</div>
          <div className="font-mono text-slate-400 space-y-1">
            <div>Your Address: {userAddress || 'Not connected'}</div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="panel p-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="icon-container-accent">
          <FiSend className="w-5 h-5" />
        </div>
        <div>
          <h3 className="font-heading font-semibold text-slate-100">New Proposal</h3>
          <p className="text-slate-500 text-xs">Create a treasury proposal or board change</p>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 mb-6">
        {[
          {
            id: 'transaction',
            icon: FiDollarSign,
            title: 'Treasury proposals',
            description: 'Submit a wallet transaction for director confirmation.',
          },
          {
            id: 'seats',
            icon: FiUsers,
            title: 'Board changes',
            description: 'Use the Chamber native seat proposal and timelock flow.',
          },
        ].map((type) => {
          const Icon = type.icon
          return (
            <button
              key={type.id}
              type="button"
              onClick={() => setProposalType(type.id as typeof proposalType)}
              className={`
                text-left rounded-xl border p-4 transition-all
                ${proposalType === type.id
                  ? 'bg-accent-500/20 text-accent-400 border-accent-500/30'
                  : 'bg-slate-800/50 text-slate-400 border-slate-700/50 hover:text-slate-200 hover:border-slate-600'
                }
              `}
            >
              <div className="flex items-start gap-3">
                <Icon className="w-5 h-5 mt-0.5 shrink-0" />
                <div>
                  <div className="font-medium text-sm">{type.title}</div>
                  <p className="text-xs text-slate-500 mt-1">{type.description}</p>
                </div>
              </div>
            </button>
          )
        })}
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {proposalType === 'seats' ? (
          <>
            <div className="rounded-xl border border-accent-500/30 bg-accent-500/5 p-4">
              <div className="flex items-start gap-3">
                <FiUsers className="w-5 h-5 text-accent-400 mt-0.5" />
                <div>
                  <h4 className="font-medium text-slate-100 text-sm">Board changes</h4>
                  <p className="text-slate-400 text-xs mt-1">
                    Directors propose and support seat changes directly. {quorum} of {currentSeats} directors must confirm. Execution then unlocks after the 7-day timelock. The proposer can cancel anytime; any current director can cancel after 14 days.
                  </p>
                </div>
              </div>
            </div>

            {hasSeatProposal && (
              <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 p-4 text-sm text-amber-300">
                A board change is already active. Return to Proposals to support or execute it.
              </div>
            )}

            <div className="space-y-3">
              <label className="block text-slate-300 text-sm font-medium">Proposed seat count</label>
              <div className="flex items-center gap-4">
                <button
                  type="button"
                  onClick={() => setSeatDraft((s) => String(Math.max(1, Number(s) - 1)))}
                  disabled={busy || Number(seatDraft) <= 1}
                  className="w-10 h-10 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 flex items-center justify-center transition-colors text-xl font-bold disabled:opacity-40"
                >
                  −
                </button>
                <div className="flex-1 text-center">
                  <span className="font-heading text-3xl font-bold text-slate-100">{seatDraft}</span>
                  <span className="text-slate-500 text-sm ml-2">seats</span>
                </div>
                <button
                  type="button"
                  onClick={() => setSeatDraft((s) => String(Math.min(MAX_BOARD_SEATS, Number(s) + 1)))}
                  disabled={busy || Number(seatDraft) >= MAX_BOARD_SEATS}
                  className="w-10 h-10 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 flex items-center justify-center transition-colors text-xl font-bold disabled:opacity-40"
                >
                  +
                </button>
              </div>
              <p className="text-slate-500 text-xs">
                Current seats: <span className="text-slate-300 font-mono">{currentSeats}</span>. Maximum seats: {MAX_BOARD_SEATS}.
              </p>
            </div>
          </>
        ) : (
          <>
            {registryUpgradeDraft && (
              <div className="rounded-xl border border-accent-400/35 bg-accent-500/[0.08] px-4 py-3 text-sm text-slate-100/95">
                <p className="font-medium text-accent-300 mb-1">Prefilled Registry upgrade proposal</p>
                <p className="text-slate-400 text-xs leading-relaxed">
                  Target is this Chamber. Calldata invokes <span className="font-mono">upgradeImplementation</span> using
                  the Registry’s default implementation{' '}
                  <span className="font-mono text-slate-300">
                    {shortenAddress(registryUpgradeDraft.newImplementation, 6)}
                  </span>
                  {registryUpgradeDraft.registryVersionLabel
                    ? ` (VERSION ${registryUpgradeDraft.registryVersionLabel})`
                    : ''}
                  . Other directors still need to confirm — {quorum} of {currentSeats} directors must confirm — before execution.
                </p>
              </div>
            )}

            {/* Proposal Templates */}
            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">Template</label>
              <div className="flex flex-wrap gap-2">
                {PROPOSAL_TEMPLATES.map((tpl) => (
                  <button
                    key={tpl.id}
                    type="button"
                    onClick={() => {
                      setTxType(tpl.txType)
                      if (tpl.title) setTitle(tpl.title)
                      if (tpl.description) setDescription(tpl.description)
                    }}
                    className={`
                      px-3 py-1.5 rounded-lg text-sm font-medium transition-all border
                      ${txType === tpl.txType
                        ? 'bg-accent-500/20 text-accent-400 border-accent-500/30'
                        : 'bg-slate-800/50 text-slate-400 border-slate-700/50 hover:text-slate-200 hover:border-slate-600'
                      }
                    `}
                  >
                    {tpl.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title & Description */}
            <div className="space-y-4">
              <div>
                <label className="block text-slate-300 text-sm font-medium mb-2">Title</label>
                <input
                  type="text"
                  placeholder="e.g., Grant to Builder X"
                  className="input"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                />
              </div>
              <div>
                <label className="block text-slate-300 text-sm font-medium mb-2">Description (optional)</label>
                <textarea
                  placeholder="Context for other directors..."
                  className="input min-h-[80px] resize-y"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={3}
                />
              </div>
            </div>

            {/* Transaction Type */}
            <div className="flex gap-2 p-1 bg-slate-800/50 rounded-xl">
              {[
                { id: 'eth', label: 'Send ETH', icon: FiDollarSign },
                { id: 'token', label: 'Send Token', icon: FiHash },
                { id: 'custom', label: 'Custom', icon: FiCode },
              ].map((type) => {
                const Icon = type.icon
                return (
                  <button
                    key={type.id}
                    type="button"
                    onClick={() => setTxType(type.id as typeof txType)}
                    className={`
                      flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-lg transition-all
                      ${txType === type.id 
                        ? 'bg-accent-500/20 text-accent-400 border border-accent-500/30' 
                        : 'text-slate-400 hover:text-slate-200'
                      }
                    `}
                  >
                    <Icon className="w-4 h-4" />
                    <span className="text-sm font-medium">{type.label}</span>
                  </button>
                )
              })}
            </div>

        {txType === 'token' && (
          <div>
            <label className="block text-slate-300 text-sm font-medium mb-2">
              Token Address
            </label>
            <input
              type="text"
              placeholder="0x..."
              className="input font-mono"
              value={tokenAddress}
              onChange={(e) => setTokenAddress(e.target.value)}
              required
            />
          </div>
        )}

        <div>
          <label className="block text-slate-300 text-sm font-medium mb-2">
            {txType === 'token' ? 'Recipient Address' : 'Target Address'}
          </label>
          <input
            type="text"
            placeholder="0x..."
            className="input font-mono"
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            required
          />
        </div>

        {(txType === 'eth' || txType === 'custom') && (
          <div>
            <label className="block text-slate-300 text-sm font-medium mb-2">
              {txType === 'eth' ? 'Amount (ETH)' : 'ETH Value (optional)'}
            </label>
            <input
              type="number"
              placeholder="0.0"
              className="input"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              min="0"
              step="any"
              required={txType === 'eth'}
            />
          </div>
        )}

        {txType === 'token' && (
          <div>
            <label className="block text-slate-300 text-sm font-medium mb-2">
              Token Amount
            </label>
            <input
              type="number"
              placeholder="0.0"
              className="input"
              value={tokenAmount}
              onChange={(e) => setTokenAmount(e.target.value)}
              min="0"
              step="any"
              required
            />
          </div>
        )}

        {txType === 'custom' && (
          <>
            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">
                Function Signature
              </label>
              <input
                type="text"
                placeholder="e.g., transfer(address,uint256) or mint(address to, uint256 amount)"
                className={`input font-mono ${sigError ? 'border-red-500/50' : ''}`}
                value={functionSig}
                onChange={(e) => setFunctionSig(e.target.value)}
              />
              {sigError && (
                <p className="text-red-400 text-xs mt-1">{sigError}</p>
              )}
              <p className="text-slate-500 text-xs mt-1">
                Enter the function signature with parameter types (and optional names)
              </p>
            </div>

            {/* Dynamic Parameter Inputs */}
            {parsedFunction && parsedFunction.params.length > 0 && (
              <div className="space-y-3 p-4 bg-slate-800/30 rounded-xl border border-slate-700/50">
                <div className="text-slate-400 text-xs font-medium uppercase tracking-wider mb-3">
                  Function Parameters
                </div>
                {parsedFunction.params.map((param, index) => (
                  <div key={index}>
                    <label className="block text-slate-300 text-sm font-medium mb-2">
                      <span className="text-accent-400">{param.type}</span>
                      <span className="text-slate-500 ml-2">{param.name}</span>
                    </label>
                    <input
                      type="text"
                      placeholder={getPlaceholder(param.type)}
                      className="input font-mono"
                      value={paramValues[`param${index}`] || ''}
                      onChange={(e) => setParamValues(prev => ({
                        ...prev,
                        [`param${index}`]: e.target.value
                      }))}
                    />
                  </div>
                ))}
              </div>
            )}

            {/* Encoded Data Preview */}
            {encodedData && encodedData !== '0x' && (
              <div className="p-4 bg-slate-800/30 rounded-xl border border-slate-700/50">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-slate-400 text-xs font-medium uppercase tracking-wider">
                    Encoded Transaction Data
                  </span>
                  <span className="badge badge-success text-xs">Valid</span>
                </div>
                <code className="block text-slate-400 text-xs font-mono bg-slate-900/50 p-2 rounded-lg overflow-x-auto break-all">
                  {encodedData}
                </code>
              </div>
            )}
          </>
        )}

        <div className={`rounded-xl border p-4 ${
          previewRisk?.level === 'high'
            ? 'border-red-500/30 bg-red-500/5'
            : previewRisk?.level === 'medium'
            ? 'border-amber-500/30 bg-amber-500/5'
            : 'border-slate-700/50 bg-slate-800/30'
        }`}>
          <div className="flex items-start gap-3">
            <FiAlertCircle className={`w-5 h-5 mt-0.5 ${
              previewRisk?.level === 'high'
                ? 'text-red-400'
                : previewRisk?.level === 'medium'
                ? 'text-amber-400'
                : 'text-slate-400'
            }`} />
            <div>
              <div className="text-sm font-medium text-slate-200">
                {previewRisk ? previewRisk.label : 'Risk preview pending'}
              </div>
              <p className="text-xs text-slate-400 mt-1">
                {previewRisk
                  ? previewRisk.summary
                  : 'Enter a valid target address to generate a governance risk summary for directors.'}
              </p>
              <p className="text-[11px] text-slate-500 mt-2">
                Proposal title, description, and risk summary will be committed onchain as metadata for auditability.
              </p>
            </div>
          </div>
        </div>
          </>
        )}

        {busy && (
          <PendingTxBanner
            kind={
              proposalType === 'seats'
                ? 'seat-propose'
                : parsedFunction?.name === 'upgradeImplementation' || !!registryUpgradeDraft
                  ? 'upgrade'
                  : 'submit'
            }
            hash={isSeatPending || isSeatConfirming ? seatHash : submitHash}
            chainId={chainId}
          />
        )}

        <button
          type="submit"
          disabled={busy || (proposalType === 'seats' && hasSeatProposal)}
          className="btn btn-primary w-full py-3"
        >
          {busy ? (
            <>
              <FiLoader className="w-4 h-4 animate-spin" />
              {isPending || isSeatPending ? 'Confirm in Wallet...' : 'Waiting for confirmation...'}
            </>
          ) : (
            <>
              <FiSend className="w-4 h-4" />
              {proposalType === 'seats' ? 'Create board change' : 'Submit proposal'}
            </>
          )}
        </button>
      </form>
    </div>
  )
}

