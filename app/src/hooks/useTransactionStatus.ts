import { useEffect, useCallback, useRef, useState } from 'react'
import { useWaitForTransactionReceipt, useWatchPendingTransactions, useWriteContract } from 'wagmi'
import { type Abi, type Hash, type TransactionReceipt } from 'viem'
import toast from 'react-hot-toast'
import { chamberAbi, erc20Abi, factoryAbi, registryAbi } from '@/contracts/abis'

export type TransactionStatus = 'idle' | 'pending' | 'confirming' | 'success' | 'error'

export interface UseTransactionStatusOptions {
  /** Transaction hash to watch */
  hash?: Hash
  /** Callback when transaction succeeds */
  onSuccess?: (receipt?: TransactionReceipt) => void
  /** Callback when transaction fails */
  onError?: (error: Error) => void
  /** Success message to show (default: "Transaction confirmed!") */
  successMessage?: string
  /** Error message to show (default: "Transaction failed") */
  errorMessage?: string
  /** Whether to show toast notifications (default: true) */
  showNotifications?: boolean
  /** Whether to automatically reset after success/error (default: false) */
  autoReset?: boolean
  /** Reset delay in milliseconds (default: 3000) */
  resetDelay?: number
}

export interface UseTransactionStatusReturn {
  /** Current transaction status */
  status: TransactionStatus
  /** Transaction hash */
  hash: Hash | undefined
  /** Whether transaction is pending (waiting for user confirmation) */
  isPending: boolean
  /** Whether transaction is confirming (waiting for blockchain confirmation) */
  isConfirming: boolean
  /** Whether transaction succeeded */
  isSuccess: boolean
  /** Whether transaction failed */
  isError: boolean
  /** Error object if transaction failed */
  error: Error | null
  /** Transaction receipt if successful */
  receipt: TransactionReceipt | null
  /** Reset the transaction status */
  reset: () => void
  /** Set a new transaction hash to watch */
  setHash: (hash: Hash | undefined) => void
}

/**
 * Hook to track transaction status with event listeners and notifications
 * 
 * @example
 * ```tsx
 * const { status, hash, isPending, isConfirming, isSuccess, reset } = useTransactionStatus({
 *   hash: txHash,
 *   onSuccess: () => {
 *     console.log('Transaction completed!')
 *     refetchData()
 *   },
 *   onError: (error) => {
 *     console.error('Transaction failed:', error)
 *   }
 * })
 * ```
 */
export function useTransactionStatus(
  options: UseTransactionStatusOptions = {}
): UseTransactionStatusReturn {
  const {
    hash: providedHash,
    onSuccess,
    onError,
    successMessage = 'Transaction confirmed!',
    errorMessage = 'Transaction failed',
    showNotifications = true,
    autoReset = false,
    resetDelay = 3000,
  } = options

  const [internalHash, setInternalHash] = useState<Hash | undefined>(providedHash)
  const [status, setStatus] = useState<TransactionStatus>('idle')
  const [error, setError] = useState<Error | null>(null)
  const [receipt, setReceipt] = useState<TransactionReceipt | null>(null)
  
  const hasNotifiedRef = useRef(false)
  const resetTimeoutRef = useRef<NodeJS.Timeout | null>(null)
  const onSuccessRef = useRef(onSuccess)
  const onErrorRef = useRef(onError)

  // Keep refs updated
  useEffect(() => {
    onSuccessRef.current = onSuccess
    onErrorRef.current = onError
  }, [onSuccess, onError])

  // Update internal hash when provided hash changes
  useEffect(() => {
    const prevHash = internalHash
    setInternalHash(providedHash)
    
    // When hash changes from undefined to a value, set status to pending
    if (providedHash && !prevHash) {
      setStatus('pending')
      setError(null)
      setReceipt(null)
      hasNotifiedRef.current = false
    }
    // When hash changes from a value to undefined, reset to idle
    if (!providedHash && prevHash) {
      setStatus('idle')
      hasNotifiedRef.current = false
    }
    // Only depend on providedHash to avoid loops when internalHash is written above.
    // eslint-disable-next-line react-hooks/exhaustive-deps -- internalHash is synced from providedHash
  }, [providedHash])

  // Watch for transaction receipt - enable whenever we have a hash
  const {
    data: transactionReceipt,
    isLoading: isConfirming,
    isSuccess: receiptSuccess,
    isError: receiptError,
    error: receiptErrorData,
  } = useWaitForTransactionReceipt({
    hash: internalHash,
    query: {
      enabled: !!internalHash,
      retry: 3,
      retryDelay: 2000,
    },
  })

  // Watch for pending transactions (optional - helps detect when tx is submitted)
  useWatchPendingTransactions({
    onTransactions: (transactions) => {
      if (internalHash && transactions.includes(internalHash) && status === 'idle') {
        setStatus('pending')
      }
    },
  })

  // Reset function (defined early so it can be used in useEffects)
  const reset = useCallback(() => {
    // Clear any pending reset timeout
    if (resetTimeoutRef.current) {
      clearTimeout(resetTimeoutRef.current)
      resetTimeoutRef.current = null
    }

    setStatus('idle')
    setError(null)
    setReceipt(null)
    setInternalHash(undefined)
    hasNotifiedRef.current = false
  }, [])

  // Handle transaction receipt success
  useEffect(() => {
    if (receiptSuccess && transactionReceipt && internalHash && status !== 'success' && !hasNotifiedRef.current) {
      setStatus('success')
      setReceipt(transactionReceipt)
      setError(null)
      hasNotifiedRef.current = true

      if (showNotifications) {
        toast.success(successMessage, {
          duration: 5000,
        })
      }

      // Call success callback
      if (onSuccessRef.current) {
        onSuccessRef.current(transactionReceipt)
      }

      // Auto reset if enabled
      if (autoReset) {
        resetTimeoutRef.current = setTimeout(() => {
          reset()
        }, resetDelay)
      }
    }
  }, [receiptSuccess, transactionReceipt, internalHash, status, successMessage, showNotifications, autoReset, resetDelay, reset])

  // Handle transaction receipt error
  useEffect(() => {
    if (receiptError && receiptErrorData && internalHash && status !== 'error' && !hasNotifiedRef.current) {
      const errorObj = receiptErrorData instanceof Error
        ? receiptErrorData
        : new Error(errorMessage)
      
      setStatus('error')
      setError(errorObj)
      hasNotifiedRef.current = true

      if (showNotifications) {
        toast.error(errorMessage, {
          duration: 5000,
        })
      }

      // Call error callback
      if (onErrorRef.current) {
        onErrorRef.current(errorObj)
      }

      // Auto reset if enabled
      if (autoReset) {
        resetTimeoutRef.current = setTimeout(() => {
          reset()
        }, resetDelay)
      }
    }
  }, [receiptError, receiptErrorData, internalHash, status, errorMessage, showNotifications, autoReset, resetDelay, reset])

  // Update status based on confirmation state
  useEffect(() => {
    if (!internalHash) {
      if (status !== 'idle') {
        setStatus('idle')
      }
      return
    }

    // If we have a hash but haven't started confirming yet, set to pending
    if (status === 'idle' && !isConfirming && !receiptSuccess && !receiptError) {
      setStatus('pending')
      hasNotifiedRef.current = false
    }
    
    // When receipt starts loading, move to confirming
    if (isConfirming && status !== 'confirming' && status !== 'success' && status !== 'error') {
      setStatus('confirming')
      hasNotifiedRef.current = false
    }
  }, [internalHash, isConfirming, receiptSuccess, receiptError, status])

  // Set hash function
  const setHash = useCallback((newHash: Hash | undefined) => {
    // Clear any pending reset timeout
    if (resetTimeoutRef.current) {
      clearTimeout(resetTimeoutRef.current)
      resetTimeoutRef.current = null
    }

    setInternalHash(newHash)
    setStatus(newHash ? 'pending' : 'idle')
    setError(null)
    setReceipt(null)
    hasNotifiedRef.current = false
  }, [])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (resetTimeoutRef.current) {
        clearTimeout(resetTimeoutRef.current)
      }
    }
  }, [])

  return {
    status,
    hash: internalHash,
    isPending: status === 'pending',
    isConfirming: status === 'confirming' || isConfirming,
    isSuccess: status === 'success',
    isError: status === 'error',
    error,
    receipt,
    reset,
    setHash,
  }
}

/**
 * Enhanced hook for submitting transactions with status tracking
 */
export function useSubmitTransactionWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const submit = async (
    tokenId: bigint,
    target: `0x${string}`,
    value: bigint,
    data: `0x${string}`
  ) => {
    if (!chamberAddress) return
    try {
      // Reset transaction status before new transaction
      transactionStatus.reset()
      
      // Call writeContract - wagmi will automatically update the hash state
      // which will trigger useTransactionStatus to start watching
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'submitTransaction',
        args: [tokenId, target, value, data],
      })
    } catch (err) {
      // On error, reset the status
      transactionStatus.reset()
      throw err
    }
  }

  return {
    submit,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for confirming transactions with status tracking
 */
export function useConfirmTransactionWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const confirm = async (tokenId: bigint, transactionId: bigint) => {
    if (!chamberAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'confirmTransaction',
        args: [tokenId, transactionId],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    confirm,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for executing transactions with status tracking
 */
export function useExecuteTransactionWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const execute = async (tokenId: bigint, transactionId: bigint, calldata: `0x${string}` = '0x') => {
    if (!chamberAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'executeTransaction',
        args: [tokenId, transactionId, calldata],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    execute,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for delegating with status tracking
 */
export function useDelegateWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const delegate = async (tokenId: bigint, amount: bigint) => {
    if (!chamberAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'delegate',
        args: [tokenId, amount],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    delegate,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for depositing with status tracking
 */
export function useDepositWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const deposit = async (assets: bigint, receiver: `0x${string}`) => {
    if (!chamberAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'deposit',
        args: [assets, receiver],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    deposit,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for withdrawing with status tracking
 */
export function useWithdrawWithStatus(
  chamberAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const withdraw = async (assets: bigint, receiver: `0x${string}`, owner: `0x${string}`) => {
    if (!chamberAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: chamberAddress,
        abi: chamberAbi,
        functionName: 'withdraw',
        args: [assets, receiver, owner],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    withdraw,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for token approval with status tracking
 */
export function useTokenApproveWithStatus(
  tokenAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const approve = async (spender: `0x${string}`, amount: bigint) => {
    if (!tokenAddress) return
    try {
      transactionStatus.reset()
      await writeContract({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [spender, amount],
      })
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    approve,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Enhanced hook for creating chambers with status tracking
 */
export function useCreateChamberWithStatus(
  createAddress: `0x${string}` | undefined,
  options?: UseTransactionStatusOptions & { abi?: typeof factoryAbi | typeof registryAbi }
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })
  const createAbi = options?.abi ?? registryAbi

  const createChamber = async (
    erc20Token: `0x${string}`,
    erc721Token: `0x${string}`,
    seats: number,
    name: string,
    symbol: string
  ) => {
    if (!createAddress) return
    try {
      transactionStatus.reset()
      const txHash = await writeContract({
        address: createAddress,
        abi: createAbi,
        functionName: 'createChamber',
        args: [erc20Token, erc721Token, BigInt(seats), name, symbol],
      })
      return txHash
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    createChamber,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}

/**
 * Generic hook wrapper for any write contract operation with transaction status tracking
 * 
 * @example
 * ```tsx
 * const { execute, status, isSuccess, reset } = useWriteContractWithStatus({
 *   address: chamberAddress,
 *   abi: chamberAbi,
 *   functionName: 'submitTransaction',
 *   onSuccess: () => refetch(),
 * })
 * 
 * await execute({ args: [tokenId, target, value, data] })
 * ```
 */
export function useWriteContractWithStatus(
  contractConfig: {
    address?: `0x${string}`
    abi: Abi
    functionName: string
  },
  options?: UseTransactionStatusOptions
) {
  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const transactionStatus = useTransactionStatus({
    hash,
    ...options,
  })

  const execute = async (callArgs: { args?: readonly unknown[]; value?: bigint }) => {
    if (!contractConfig.address) {
      throw new Error('Contract address is required')
    }

    try {
      transactionStatus.reset()
      const txHash = await writeContract({
        address: contractConfig.address,
        abi: contractConfig.abi,
        functionName: contractConfig.functionName,
        ...callArgs,
      } as Parameters<typeof writeContract>[0])
      return txHash
    } catch (err) {
      transactionStatus.reset()
      throw err
    }
  }

  return {
    execute,
    ...transactionStatus,
    writeError,
    isPending: isPending || transactionStatus.isPending,
  }
}
