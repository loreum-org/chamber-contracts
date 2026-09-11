import { useEffect, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWaitForTransactionReceipt } from 'wagmi'
import { type Hash } from 'viem'
import toast from 'react-hot-toast'
import { invalidateChamberQueries } from './useChamberEvents'

export type QueueWriteKind =
  | 'submit'
  | 'upgrade'
  | 'confirm'
  | 'execute'
  | 'revoke'
  | 'cancel'
  | 'seat-propose'
  | 'seat-support'
  | 'seat-execute'
  | 'seat-cancel'

export function queueWritePendingLabel(kind: QueueWriteKind, phase: 'wallet' | 'chain'): string {
  if (phase === 'wallet') {
    switch (kind) {
      case 'upgrade':
        return 'Confirm upgrade in wallet'
      case 'submit':
        return 'Confirm submit in wallet'
      case 'confirm':
        return 'Confirm vote in wallet'
      case 'execute':
        return 'Confirm execute in wallet'
      case 'revoke':
        return 'Confirm revoke in wallet'
      case 'cancel':
        return 'Confirm cancel vote in wallet'
      case 'seat-propose':
        return 'Confirm board change in wallet'
      case 'seat-support':
        return 'Confirm support in wallet'
      case 'seat-execute':
        return 'Confirm board execute in wallet'
      case 'seat-cancel':
        return 'Confirm board cancel in wallet'
    }
  }

  switch (kind) {
    case 'upgrade':
      return 'Upgrade submitted, waiting for confirmation'
    case 'submit':
      return 'Proposal submitted, waiting for confirmation'
    case 'confirm':
      return 'Confirmation submitted, waiting for the chain'
    case 'execute':
      return 'Execution submitted, waiting for confirmation'
    case 'revoke':
      return 'Revoke submitted, waiting for confirmation'
    case 'cancel':
      return 'Cancel vote submitted, waiting for confirmation'
    case 'seat-propose':
      return 'Board change submitted, waiting for confirmation'
    case 'seat-support':
      return 'Support submitted, waiting for confirmation'
    case 'seat-execute':
      return 'Board change execution submitted, waiting for confirmation'
    case 'seat-cancel':
      return 'Board change cancel submitted, waiting for confirmation'
  }
}

export function queueWriteSuccessMessage(kind: QueueWriteKind): string {
  switch (kind) {
    case 'upgrade':
      return 'Upgrade proposal confirmed on-chain'
    case 'submit':
      return 'Proposal confirmed on-chain'
    case 'confirm':
      return 'Confirmation recorded on-chain'
    case 'execute':
      return 'Transaction executed'
    case 'revoke':
      return 'Confirmation revoked'
    case 'cancel':
      return 'Cancel vote recorded'
    case 'seat-propose':
      return 'Board change created'
    case 'seat-support':
      return 'Board change supported'
    case 'seat-execute':
      return 'Board change executed'
    case 'seat-cancel':
      return 'Board change cancelled'
  }
}

export function queueWriteErrorMessage(kind: QueueWriteKind): string {
  switch (kind) {
    case 'upgrade':
      return 'Upgrade transaction failed'
    case 'submit':
      return 'Submit transaction failed'
    case 'confirm':
      return 'Confirmation failed on-chain'
    case 'execute':
      return 'Execution failed on-chain'
    case 'revoke':
      return 'Revoke failed on-chain'
    case 'cancel':
      return 'Cancel vote failed on-chain'
    case 'seat-propose':
      return 'Board change failed on-chain'
    case 'seat-support':
      return 'Support failed on-chain'
    case 'seat-execute':
      return 'Board execute failed on-chain'
    case 'seat-cancel':
      return 'Board cancel failed on-chain'
  }
}

/**
 * Watch a sent tx hash until the receipt lands, then refetch chamber reads.
 * Event watches stay as a fast path; this receipt path is the source of truth.
 */
export function useReceiptRefresh(options: {
  chamberAddress: `0x${string}` | undefined
  hash: Hash | undefined
  successMessage: string
  errorMessage: string
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  const { chamberAddress, hash, successMessage, errorMessage, onSuccess, onError } = options
  const queryClient = useQueryClient()
  const handledRef = useRef<string | undefined>()
  const onSuccessRef = useRef(onSuccess)
  const onErrorRef = useRef(onError)

  useEffect(() => {
    onSuccessRef.current = onSuccess
    onErrorRef.current = onError
  })

  const {
    isLoading: isConfirming,
    isSuccess,
    isError,
    error,
  } = useWaitForTransactionReceipt({
    hash,
    query: { enabled: !!hash },
  })

  useEffect(() => {
    if (!hash || handledRef.current === hash) return

    if (isSuccess) {
      handledRef.current = hash
      invalidateChamberQueries(queryClient, chamberAddress)
      toast.success(successMessage)
      onSuccessRef.current?.()
      // Public RPCs can lag the receipt; a second invalidate catches a stale first read.
      window.setTimeout(() => {
        invalidateChamberQueries(queryClient, chamberAddress)
      }, 2000)
      return
    }

    if (isError) {
      handledRef.current = hash
      const err = error instanceof Error ? error : new Error(errorMessage)
      toast.error(errorMessage)
      onErrorRef.current?.(err)
    }
  }, [hash, isSuccess, isError, error, chamberAddress, queryClient, successMessage, errorMessage])

  return { isConfirming, isSuccess, isError, error }
}
