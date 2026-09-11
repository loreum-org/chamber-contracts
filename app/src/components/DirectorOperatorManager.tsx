import { useEffect, useMemo, useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { getAddress, isAddress, zeroAddress } from 'viem'
import { FiKey, FiLoader, FiTrash2, FiAlertCircle } from 'react-icons/fi'
import toast from 'react-hot-toast'
import { erc721Abi } from '@/contracts/abis'
import {
  useDirectorOperator,
  useIsContractAccount,
  useSetDirectorOperator,
  useUserNFTs,
  useReceiptRefresh,
} from '@/hooks'
import { formatWalletSendError, shortenAddress } from '@/lib/utils'

/**
 * Write path for `setDirectorOperator`. Shown only when the connected wallet
 * is `ownerOf(tokenId)` and that owner is a contract (`code.length > 0`).
 * Hidden for EOAs — the protocol rejects that path (no EIP-1271).
 */
export function DirectorOperatorManager({
  chamberAddress,
  nftToken,
  tokenId: lockedTokenId,
  preferredTokenId,
}: {
  chamberAddress: `0x${string}`
  nftToken?: `0x${string}`
  /** When set (DirectorProfile), only this membership token is eligible. */
  tokenId?: bigint
  /** Default selection on ChamberDetail when the connected wallet is a seated owner. */
  preferredTokenId?: bigint
}) {
  const { address: userAddress } = useAccount()
  const { isContract, isFetched: bytecodeFetched } = useIsContractAccount(userAddress)
  const {
    tokenIds: ownedTokenIds,
    isLoading: nftsLoading,
  } = useUserNFTs(
    lockedTokenId === undefined ? nftToken : undefined,
    lockedTokenId === undefined ? userAddress : undefined,
    { chamberAddress },
  )

  const { data: lockedOwner, isFetched: lockedOwnerFetched } = useReadContract({
    address: nftToken,
    abi: erc721Abi,
    functionName: 'ownerOf',
    args: lockedTokenId !== undefined ? [lockedTokenId] : undefined,
    query: {
      enabled: !!nftToken && lockedTokenId !== undefined,
      retry: false,
    },
  })

  const isOwnerOfLocked =
    !!userAddress &&
    typeof lockedOwner === 'string' &&
    lockedOwner.toLowerCase() === userAddress.toLowerCase()

  const eligibleTokenIds = useMemo(() => {
    if (lockedTokenId !== undefined) {
      return isOwnerOfLocked ? [lockedTokenId] : []
    }
    const ids = [...ownedTokenIds]
    if (
      preferredTokenId !== undefined &&
      !ids.some((id) => id === preferredTokenId)
    ) {
      ids.unshift(preferredTokenId)
    }
    return ids
  }, [lockedTokenId, isOwnerOfLocked, ownedTokenIds, preferredTokenId])

  const [selectedId, setSelectedId] = useState('')
  const [operatorInput, setOperatorInput] = useState('')
  const [lastWrite, setLastWrite] = useState<'set' | 'clear' | null>(null)

  useEffect(() => {
    if (eligibleTokenIds.length === 0) {
      setSelectedId('')
      return
    }
    setSelectedId((current) => {
      if (current && eligibleTokenIds.some((id) => id.toString() === current)) {
        return current
      }
      if (preferredTokenId !== undefined) {
        const preferred = preferredTokenId.toString()
        if (eligibleTokenIds.some((id) => id.toString() === preferred)) {
          return preferred
        }
      }
      return eligibleTokenIds[0].toString()
    })
  }, [eligibleTokenIds, preferredTokenId])

  const selectedTokenId = selectedId && /^\d+$/.test(selectedId) ? BigInt(selectedId) : undefined
  const { operator, isSet, refetch: refetchOperator } = useDirectorOperator(
    chamberAddress,
    selectedTokenId,
  )
  const { setDirectorOperator, isPending, isConfirming, hash } = useSetDirectorOperator(chamberAddress)

  useReceiptRefresh({
    chamberAddress,
    hash,
    successMessage: lastWrite === 'clear' ? 'Session key cleared' : 'Session key registered',
    errorMessage: 'Session key update failed',
    onSuccess: () => {
      void refetchOperator()
      setOperatorInput('')
      setLastWrite(null)
    },
  })

  const waitingForEligibility =
    !!userAddress &&
    (!bytecodeFetched ||
      (lockedTokenId !== undefined
        ? !lockedOwnerFetched
        : nftsLoading && ownedTokenIds.length === 0 && preferredTokenId === undefined))

  if (!userAddress || waitingForEligibility) return null
  if (!isContract) return null
  if (eligibleTokenIds.length === 0) return null

  const parsedOperator = (() => {
    const raw = operatorInput.trim()
    if (!raw || !isAddress(raw)) return undefined
    try {
      return getAddress(raw) as `0x${string}`
    } catch {
      return undefined
    }
  })()

  const operatorLooksValid = !!parsedOperator && parsedOperator !== zeroAddress
  const sameAsCurrent =
    operatorLooksValid &&
    !!operator &&
    parsedOperator.toLowerCase() === operator.toLowerCase()
  const busy = isPending || isConfirming
  const canSet = !busy && operatorLooksValid && !sameAsCurrent && selectedTokenId !== undefined
  const canClear = !busy && isSet && selectedTokenId !== undefined

  const handleSet = async () => {
    if (!selectedTokenId || !parsedOperator || parsedOperator === zeroAddress) return
    setLastWrite('set')
    try {
      await setDirectorOperator(selectedTokenId, parsedOperator)
    } catch (err) {
      setLastWrite(null)
      toast.error(formatWalletSendError(err, 'Failed to set session key'))
    }
  }

  const handleClear = async () => {
    if (!selectedTokenId) return
    setLastWrite('clear')
    try {
      await setDirectorOperator(selectedTokenId, zeroAddress)
    } catch (err) {
      setLastWrite(null)
      toast.error(formatWalletSendError(err, 'Failed to clear session key'))
    }
  }

  return (
    <div className="mt-4 rounded-xl border border-sky-500/25 bg-sky-500/5 px-4 py-3 text-sm">
      <div className="flex items-start gap-2">
        <FiKey className="w-4 h-4 mt-0.5 shrink-0 text-sky-400" aria-hidden />
        <div className="flex-1 min-w-0 space-y-3">
          <div>
            <p className="font-medium text-sky-100">Session key</p>
            <p className="text-slate-400 text-xs mt-0.5 leading-relaxed">
              This membership NFT is owned by a contract wallet. Register an operator that can act
              for it, or clear the key. Chamber never checks ERC-1271.
            </p>
          </div>

          {eligibleTokenIds.length > 1 && (
            <div>
              <label className="block text-slate-300 text-xs font-medium mb-1.5" htmlFor="session-key-token">
                Member ID
              </label>
              <select
                id="session-key-token"
                className="input py-2 text-sm"
                value={selectedId}
                onChange={(e) => setSelectedId(e.target.value)}
                disabled={busy}
              >
                {eligibleTokenIds.map((id) => (
                  <option key={id.toString()} value={id.toString()}>
                    #{id.toString()}
                  </option>
                ))}
              </select>
            </div>
          )}

          {eligibleTokenIds.length === 1 && (
            <p className="text-slate-400 text-xs font-mono">
              Member #{eligibleTokenIds[0].toString()}
            </p>
          )}

          <p className="text-slate-300 text-xs">
            Current operator:{' '}
            {isSet && operator ? (
              <span className="font-mono text-sky-100">{shortenAddress(operator, 6)}</span>
            ) : (
              <span className="text-slate-500">none</span>
            )}
          </p>

          <div>
            <label className="block text-slate-300 text-xs font-medium mb-1.5" htmlFor="session-key-operator">
              Operator address
            </label>
            <input
              id="session-key-operator"
              type="text"
              spellCheck={false}
              autoComplete="off"
              placeholder="0x…"
              className="input font-mono text-sm py-2"
              value={operatorInput}
              onChange={(e) => setOperatorInput(e.target.value)}
              disabled={busy}
            />
            {operatorInput.trim() && !operatorLooksValid && (
              <div className="flex items-start gap-1.5 mt-1.5 text-red-400 text-xs">
                <FiAlertCircle className="w-3.5 h-3.5 mt-0.5 shrink-0" aria-hidden />
                Enter a non-zero address to register a session key.
              </div>
            )}
          </div>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => void handleSet()}
              disabled={!canSet}
              className="btn btn-primary py-2 text-xs"
            >
              {isPending || isConfirming ? (
                <>
                  <FiLoader className="w-3.5 h-3.5 animate-spin" aria-hidden />
                  {isPending ? 'Confirm…' : 'Processing…'}
                </>
              ) : (
                <>
                  <FiKey className="w-3.5 h-3.5" aria-hidden />
                  Set operator
                </>
              )}
            </button>
            <button
              type="button"
              onClick={() => void handleClear()}
              disabled={!canClear}
              className="btn btn-secondary py-2 text-xs"
            >
              <FiTrash2 className="w-3.5 h-3.5" aria-hidden />
              Clear
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
