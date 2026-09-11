import { useWatchContractEvent, usePublicClient } from 'wagmi'
import { useQueryClient, type QueryClient } from '@tanstack/react-query'
import { isAddress } from 'viem'
import { chamberAbi } from '@/contracts/abis'

/** Invalidate every cached read that mentions this chamber. Used by event watches (fast path) and receipt refresh (source of truth). */
export function invalidateChamberQueries(
  queryClient: QueryClient,
  chamberAddress: `0x${string}` | undefined,
) {
  if (!chamberAddress) return

  const chamberAddrLower = chamberAddress.toLowerCase()

  queryClient.invalidateQueries({
    predicate: (query) => {
      try {
        const keyStr = JSON.stringify(query.queryKey).toLowerCase()
        return keyStr.includes(chamberAddrLower)
      } catch {
        return false
      }
    },
  })
}

type RefetchCallback = () => void

interface UseChamberEventsOptions {
  /** Callback when any vault-related event occurs (Deposit, Withdraw, Transfer) */
  onVaultEvent?: RefetchCallback
  /** Callback when delegation-related event occurs */
  onDelegationEvent?: RefetchCallback
  /** Callback when transaction-related event occurs */
  onTransactionEvent?: RefetchCallback
  /** Callback when seats/board changes */
  onBoardEvent?: RefetchCallback
  /** Enable/disable event watching */
  enabled?: boolean
}

/**
 * Hook that watches for Chamber contract events and triggers refetches.
 * Event subscriptions are a fast path only — public RPCs often drop `eth_subscribe`.
 * Receipt + `invalidateChamberQueries` is the source of truth after a wallet write.
 *
 * Usage:
 * ```tsx
 * useChamberEvents(chamberAddress, {
 *   onVaultEvent: () => {
 *     refetchBalance()
 *     refetchTotalAssets()
 *   },
 *   onDelegationEvent: () => {
 *     refetchDelegations()
 *     refetchBoardMembers()
 *   },
 * })
 * ```
 */
export function useChamberEvents(
  chamberAddress: `0x${string}` | undefined,
  options: UseChamberEventsOptions = {}
) {
  const {
    onVaultEvent,
    onDelegationEvent,
    onTransactionEvent,
    onBoardEvent,
    enabled = true,
  } = options

  const queryClient = useQueryClient()
  const publicClient = usePublicClient()

  function invalidate() {
    invalidateChamberQueries(queryClient, chamberAddress)
  }

  const isValidAddress = chamberAddress &&
    chamberAddress !== '0x0000000000000000000000000000000000000000' &&
    isAddress(chamberAddress)

  const watchEnabled = enabled && !!isValidAddress && !!publicClient

  // Watch for Deposit events (ERC4626)
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Deposit' as any, // ERC4626 Deposit event
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Deposit event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for Withdraw events (ERC4626)
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Withdraw' as any, // ERC4626 Withdraw event
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Withdraw event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for Transfer events (share transfers)
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Transfer' as any,
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Transfer event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for DelegationUpdated events
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'DelegationUpdated',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber DelegationUpdated event:', logs)
      invalidate()
      onDelegationEvent?.()
      onBoardEvent?.() // Delegations affect board
    },
    enabled: watchEnabled,
  })

  // Watch for TransactionSubmitted events
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'TransactionSubmitted',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber TransactionSubmitted event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for TransactionConfirmed events
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'TransactionConfirmed',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber TransactionConfirmed event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for TransactionExecuted events
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'TransactionExecuted',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber TransactionExecuted event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for CancelTransaction and TransactionCancelled events
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'CancelTransaction',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber CancelTransaction event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'TransactionCancelled',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber TransactionCancelled event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  // Watch for SetSeats events (board size changes)
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'TransactionDeadlineSet',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber TransactionDeadlineSet event:', logs)
      invalidate()
      onTransactionEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Paused',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Paused event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Unpaused',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Unpaused event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'SeatUpdateCancelled',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber SeatUpdateCancelled event:', logs)
      invalidate()
      onBoardEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'SetSeats',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber SetSeats event:', logs)
      invalidate()
      onBoardEvent?.()
    },
    enabled: watchEnabled,
  })

  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'DirectorOperatorSet',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber DirectorOperatorSet event:', logs)
      invalidate()
    },
    enabled: watchEnabled,
  })

  // Watch for ETH received
  useWatchContractEvent({
    address: isValidAddress ? chamberAddress : undefined,
    abi: chamberAbi,
    eventName: 'Received',
    onLogs: (logs) => {
      if (import.meta.env.DEV) console.log('Chamber Received event:', logs)
      invalidate()
      onVaultEvent?.()
    },
    enabled: watchEnabled,
  })

  return { invalidateChamberQueries: invalidate }
}

/**
 * Simplified hook that just invalidates queries on any Chamber event.
 * Use this when you don't need fine-grained control over which callbacks to run.
 */
export function useChamberEventRefresh(chamberAddress: `0x${string}` | undefined) {
  return useChamberEvents(chamberAddress, { enabled: true })
}
