import { useState, useMemo, useEffect } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useAccount } from 'wagmi'
import { formatUnits, parseUnits, zeroAddress } from 'viem'
import {
  FiSend,
  FiArrowRight,
  FiArrowLeft,
  FiUser,
  FiLoader,
  FiInfo,
  FiAlertCircle,
  FiTrendingUp,
} from 'react-icons/fi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import toast from 'react-hot-toast'
import { useQueryClient } from '@tanstack/react-query'
import {
  useDelegate,
  useUndelegate,
  useChamberEventRefresh,
  useSimulateDelegate,
  useSimulateUndelegate,
  useUserNFTs,
  useNftTokenImage,
} from '@/hooks'
import { NftRetryableImage } from '@/components/NftRetryableImage'
import type { BoardMember } from '@/types'

interface DelegationManagerProps {
  chamberAddress: `0x${string}`
  userBalance: bigint | undefined
  delegations: { tokenId: bigint; amount: bigint }[]
  members: BoardMember[]
  vaultSymbol?: string
  nftToken?: `0x${string}`
  /** Number of board seats — used for director rank badge threshold */
  seats?: number
}

export default function DelegationManager({
  chamberAddress,
  userBalance,
  delegations,
  members,
  vaultSymbol,
  nftToken,
  seats = 5,
}: DelegationManagerProps) {
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()
  const { address: userAddress, isConnected } = useAccount()
  const {
    tokenIds: userNFTTokenIds,
    balance: nftBalance,
    isLoading: nftsLoading,
  } = useUserNFTs(nftToken, userAddress, { chamberAddress })
  const ownsMembershipNft =
    userNFTTokenIds.length > 0 || (nftBalance > 0n && nftsLoading)
  const [delegateTokenId, setDelegateTokenId] = useState('')
  const [delegateAmount, setDelegateAmount] = useState('')
  const [undelegateTokenId, setUndelegateTokenId] = useState('')
  const [undelegateAmount, setUndelegateAmount] = useState('')
  const boardEmpty = members.length === 0

  useEffect(() => {
    if (delegateTokenId) return
    const preset = searchParams.get('tokenId')
    if (preset && /^\d+$/.test(preset)) {
      setDelegateTokenId(preset)
      return
    }
    if (boardEmpty && userNFTTokenIds.length > 0) {
      setDelegateTokenId(userNFTTokenIds[0].toString())
    }
  }, [delegateTokenId, searchParams, boardEmpty, userNFTTokenIds])

  const { delegate, isPending: isDelegating, isConfirming: isDelegateConfirming } = useDelegate(chamberAddress)
  const { undelegate, isPending: isUndelegating, isConfirming: isUndelegateConfirming } = useUndelegate(chamberAddress)

  // Watch for delegation events and auto-refresh when transactions are mined
  useChamberEventRefresh(chamberAddress)

  const invalidateNftImagesForChamber = () => {
    const needle = chamberAddress.toLowerCase()
    queryClient.invalidateQueries({
      predicate: (q) => {
        try {
          const k = JSON.stringify(q.queryKey).toLowerCase()
          return (
            (k.includes('nft-token-image') || k.includes('nft-image-map')) &&
            k.includes(needle)
          )
        } catch {
          return false
        }
      },
    })
  }

  const totalDelegated = delegations.reduce((sum, d) => sum + d.amount, 0n)
  const availableBalance = userBalance ? userBalance - totalDelegated : 0n

  // Parse amounts for simulation
  const delegateAmountBigInt = useMemo(() => {
    try {
      return delegateAmount ? parseUnits(delegateAmount, 18) : undefined
    } catch {
      return undefined
    }
  }, [delegateAmount])

  const undelegateAmountBigInt = useMemo(() => {
    try {
      return undelegateAmount ? parseUnits(undelegateAmount, 18) : undefined
    } catch {
      return undefined
    }
  }, [undelegateAmount])

  // Simulate transactions to catch errors before user submits
  const { 
    isValid: isDelegateValid, 
    error: delegateSimError,
    isLoading: isDelegateSimulating,
  } = useSimulateDelegate(
    chamberAddress,
    delegateTokenId ? BigInt(delegateTokenId) : undefined,
    delegateAmountBigInt,
    { queryEnabled: !isDelegating && !isDelegateConfirming }
  )

  const { 
    isValid: isUndelegateValid, 
    error: undelegateSimError,
    isLoading: isUndelegateSimulating,
  } = useSimulateUndelegate(
    chamberAddress,
    undelegateTokenId ? BigInt(undelegateTokenId) : undefined,
    undelegateAmountBigInt,
    { queryEnabled: !isUndelegating && !isUndelegateConfirming }
  )

  // Rank-impact preview: compute where the target token would land after delegation
  const delegateRankPreview = useMemo(() => {
    if (!delegateTokenId || !delegateAmountBigInt || delegateAmountBigInt === 0n) return null
    const tokenIdBig = BigInt(delegateTokenId)
    const updated = members.map((m) =>
      m.tokenId === tokenIdBig
        ? { ...m, amount: m.amount + delegateAmountBigInt }
        : m
    )
    if (!updated.some((m) => m.tokenId === tokenIdBig)) {
      updated.push({
        tokenId: tokenIdBig, amount: delegateAmountBigInt,
        next: 0n, prev: 0n, rank: members.length + 1,
      })
    }
    const sorted = [...updated].sort((a, b) =>
      b.amount > a.amount ? 1 : b.amount < a.amount ? -1 : 0
    )
    const currentRank = members.findIndex((m) => m.tokenId === tokenIdBig)
    const newRank = sorted.findIndex((m) => m.tokenId === tokenIdBig)
    const willBeDirector = newRank + 1 <= seats
    return { currentRank: currentRank >= 0 ? currentRank + 1 : null, newRank: newRank + 1, willBeDirector }
  }, [delegateTokenId, delegateAmountBigInt, members, seats])

  // Helper to extract readable error message
  const getErrorMessage = (error: Error | null): string | null => {
    if (!error) return null
    const message = error.message || ''
    
    // Map custom error names to user-friendly messages
    const errorMessages: Record<string, string> = {
      'InsufficientChamberBalance': 'You don\'t have enough shares to delegate this amount',
      'InsufficientDelegatedAmount': 'You haven\'t delegated this much to this member',
      'ZeroTokenId': 'Token ID cannot be zero',
      'ZeroAmount': 'Amount cannot be zero',
      'InvalidTokenId': 'This member ID does not exist',
      'NotDirector': 'You are not a director',
      'DirectorNotSeated': 'Your seat is not mature yet',
      'ExceedsDelegatedAmount': 'Amount exceeds your delegated balance',
      'AssetAmountMismatch': 'Fee-on-transfer or rebasing tokens are not supported',
      'EnforcedPause': 'This chamber is paused',
    }
    
    // Check for custom error name in message
    for (const [errorName, friendlyMessage] of Object.entries(errorMessages)) {
      if (message.includes(errorName)) {
        return friendlyMessage
      }
    }
    
    // Extract revert reason if present
    const revertMatch = message.match(/reverted with reason string '([^']+)'/)
    if (revertMatch) return revertMatch[1]
    
    // Extract custom error name
    const customErrorMatch = message.match(/reverted with custom error '([^']+)'/)
    if (customErrorMatch) {
      const errorName = customErrorMatch[1]
      return errorMessages[errorName] || errorName
    }
    
    // Check for error signature and provide guidance
    if (message.includes('0x1fed7fc5')) return 'This member ID does not exist'
    if (message.includes('0xf4844814')) return 'You don\'t have enough shares'
    
    // Common error patterns
    if (message.includes('insufficient balance')) return 'Insufficient balance'
    if (message.includes('exceeds balance')) return 'Amount exceeds balance'
    if (message.includes('not owner')) return 'You do not own this member token'
    
    // Return truncated message
    return message.length > 100 ? message.slice(0, 100) + '...' : message
  }

  const handleDelegate = async () => {
    if (!delegateTokenId || !delegateAmount) return
    try {
      await delegate(BigInt(delegateTokenId), parseUnits(delegateAmount, 18))
      toast.success('Delegation submitted!')
      invalidateNftImagesForChamber()
      setDelegateTokenId('')
      setDelegateAmount('')
    } catch (err) {
      console.error(err)
      toast.error('Delegation failed')
    }
  }

  const handleUndelegate = async () => {
    if (!undelegateTokenId || !undelegateAmount) return
    try {
      await undelegate(BigInt(undelegateTokenId), parseUnits(undelegateAmount, 18))
      toast.success('Undelegation submitted!')
      invalidateNftImagesForChamber()
      setUndelegateTokenId('')
      setUndelegateAmount('')
    } catch (err) {
      console.error(err)
      toast.error('Undelegation failed')
    }
  }

  if (!isConnected) {
    return (
      <div className="panel p-10 text-center space-y-4">
        <FiUser className="w-8 h-8 text-slate-600 mx-auto" />
        <div>
          <h3 className="font-heading text-lg font-semibold text-slate-300 mb-1">Connect your wallet</h3>
          <p className="text-slate-500 text-sm">Connect to view your delegations and manage voting power.</p>
        </div>
        <div className="flex justify-center pt-2">
          <ConnectButton accountStatus="address" chainStatus="icon" showBalance={false} />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {boardEmpty && (
        <div className="panel p-4 border-accent-500/25 bg-accent-500/5">
          <p className="text-slate-200 text-sm font-medium">Seat the board</p>
          <p className="text-slate-400 text-xs mt-1 leading-relaxed">
            The board is empty. Delegate shares to a membership token you hold. Director rights unlock one block later.
          </p>
          <Link
            to="/docs/introduction/getting-started"
            className="text-accent-400 text-xs hover:underline mt-2 inline-block"
          >
            Getting started →
          </Link>
        </div>
      )}
      {/* Balance Overview */}
      <div className="grid md:grid-cols-3 gap-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="panel p-5"
        >
          <div className="text-slate-500 text-xs mb-1.5">Total Balance</div>
          <div className="font-heading text-xl font-bold text-slate-100">
            {userBalance !== undefined
              ? parseFloat(formatUnits(userBalance, 18)).toFixed(4)
              : '0.0000'}
            {vaultSymbol && <span className="text-lg text-slate-400 ml-1">{vaultSymbol}</span>}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="panel p-5"
        >
          <div className="text-slate-500 text-xs mb-1.5">Delegated</div>
          <div className="font-heading text-xl font-bold gradient-text">
            {parseFloat(formatUnits(totalDelegated, 18)).toFixed(4)}
            {vaultSymbol && <span className="text-lg text-slate-400 ml-1">{vaultSymbol}</span>}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="panel p-5"
        >
          <div className="text-slate-500 text-xs mb-1.5">Available</div>
          <div className="font-heading text-xl font-bold text-emerald-400">
            {parseFloat(formatUnits(availableBalance, 18)).toFixed(4)}
            {vaultSymbol && <span className="text-lg text-slate-400 ml-1">{vaultSymbol}</span>}
          </div>
        </motion.div>
      </div>

      {/* Delegate / Undelegate */}
      <div className="grid md:grid-cols-2 gap-5">
        {/* Delegate */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="panel p-6"
        >
          <div className="flex items-center gap-3 mb-6">
            <div className="icon-container-accent">
              <FiArrowRight className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-heading font-semibold text-slate-100">Delegate</h3>
              <p className="text-slate-500 text-xs">Point your shares at a member to give them a board seat</p>
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">
                Member #
              </label>
              {ownsMembershipNft ? (
                <select
                  className="input"
                  value={delegateTokenId}
                  onChange={(e) => setDelegateTokenId(e.target.value)}
                  disabled={nftsLoading && userNFTTokenIds.length === 0}
                >
                  <option value="">
                    {nftsLoading && userNFTTokenIds.length === 0
                      ? 'Loading your member tokens...'
                      : 'Select your member token...'}
                  </option>
                  {userNFTTokenIds.map((id) => (
                    <option key={id.toString()} value={id.toString()}>
                      #{id.toString()} {members.find(m => m.tokenId === id) ? `(Rank #${members.find(m => m.tokenId === id)?.rank})` : ''}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="number"
                  placeholder="Enter token ID"
                  className="input"
                  value={delegateTokenId}
                  onChange={(e) => setDelegateTokenId(e.target.value)}
                  min="1"
                />
              )}
              {ownsMembershipNft && (
                <p className="text-slate-500 text-xs mt-1">
                  Select a member token you own to delegate voting power to it
                </p>
              )}
            </div>

            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">
                Amount to Delegate
              </label>
              <div className="relative">
                <input
                  type="number"
                  placeholder="0.00"
                  className="input pr-20"
                  value={delegateAmount}
                  onChange={(e) => setDelegateAmount(e.target.value)}
                  min="0"
                  step="any"
                />
                <button
                  onClick={() => setDelegateAmount(formatUnits(availableBalance, 18))}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-accent-400 hover:text-accent-300 text-sm font-medium"
                >
                  MAX
                </button>
              </div>
            </div>

            {/* Simulation Error Display */}
            {delegateTokenId && delegateAmount && delegateSimError && (
              <div className="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                <FiAlertCircle className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
                <div className="text-red-400 text-sm">
                  <span className="font-medium">Transaction will fail: </span>
                  {getErrorMessage(delegateSimError)}
                </div>
              </div>
            )}

            {/* Rank impact preview */}
            {delegateRankPreview && !delegateSimError && (
              <div className={`flex items-start gap-2 p-3 rounded-lg border ${
                delegateRankPreview.willBeDirector
                  ? 'bg-accent-500/10 border-accent-500/25'
                  : 'bg-slate-800/50 border-slate-700/40'
              }`}>
                <FiTrendingUp className={`w-4 h-4 mt-0.5 shrink-0 ${delegateRankPreview.willBeDirector ? 'text-accent-400' : 'text-slate-500'}`} />
                <div className="text-sm">
                  {delegateRankPreview.currentRank ? (
                    <span className={delegateRankPreview.willBeDirector ? 'text-accent-300' : 'text-slate-400'}>
                      Member #{delegateTokenId} moves from Rank #{delegateRankPreview.currentRank} → Rank #{delegateRankPreview.newRank}
                      {delegateRankPreview.willBeDirector ? ' — would fill a board seat' : ''}
                    </span>
                  ) : (
                    <span className={delegateRankPreview.willBeDirector ? 'text-accent-300' : 'text-slate-400'}>
                      Member #{delegateTokenId} enters at Rank #{delegateRankPreview.newRank}
                      {delegateRankPreview.willBeDirector ? ' — would fill a board seat' : ''}
                    </span>
                  )}
                </div>
              </div>
            )}

            <button
              onClick={handleDelegate}
              disabled={isDelegating || isDelegateConfirming || !delegateTokenId || !delegateAmount || !!(delegateTokenId && delegateAmount && !isDelegateValid && !isDelegateSimulating)}
              className="btn btn-primary w-full"
            >
              {isDelegating || isDelegateConfirming ? (
                <>
                  <FiLoader className="w-4 h-4 animate-spin" />
                  {isDelegating ? 'Confirm...' : 'Processing...'}
                </>
              ) : isDelegateSimulating ? (
                <>
                  <FiLoader className="w-4 h-4 animate-spin" />
                  Validating...
                </>
              ) : (
                <>
                  <FiSend className="w-4 h-4" />
                  Delegate
                </>
              )}
            </button>
          </div>
        </motion.div>

        {/* Undelegate */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="panel p-6"
        >
          <div className="flex items-center gap-3 mb-6">
            <div className="icon-container bg-red-500/15 text-red-400">
              <FiArrowLeft className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-heading font-semibold text-slate-100">Undelegate</h3>
              <p className="text-slate-500 text-xs">Reclaim voting power</p>
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">
                Member #
              </label>
              <select
                className="input"
                value={undelegateTokenId}
                onChange={(e) => setUndelegateTokenId(e.target.value)}
              >
                <option value="">Select delegated member...</option>
                {delegations.map((d) => (
                  <option key={d.tokenId.toString()} value={d.tokenId.toString()}>
                    #{d.tokenId.toString()} - {parseFloat(formatUnits(d.amount, 18)).toFixed(4)} {vaultSymbol || ''} delegated
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-slate-300 text-sm font-medium mb-2">
                Amount to Undelegate
              </label>
              <div className="relative">
                <input
                  type="number"
                  placeholder="0.00"
                  className="input pr-20"
                  value={undelegateAmount}
                  onChange={(e) => setUndelegateAmount(e.target.value)}
                  min="0"
                  step="any"
                />
                <button
                  onClick={() => {
                    const del = delegations.find(d => d.tokenId.toString() === undelegateTokenId)
                    if (del) setUndelegateAmount(formatUnits(del.amount, 18))
                  }}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-accent-400 hover:text-accent-300 text-sm font-medium"
                >
                  MAX
                </button>
              </div>
            </div>

            {/* Simulation Error Display */}
            {undelegateTokenId && undelegateAmount && undelegateSimError && (
              <div className="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                <FiAlertCircle className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
                <div className="text-red-400 text-sm">
                  <span className="font-medium">Transaction will fail: </span>
                  {getErrorMessage(undelegateSimError)}
                </div>
              </div>
            )}

            <button
              onClick={handleUndelegate}
              disabled={isUndelegating || isUndelegateConfirming || !undelegateTokenId || !undelegateAmount || !!(undelegateTokenId && undelegateAmount && !isUndelegateValid && !isUndelegateSimulating)}
              className="btn btn-secondary w-full border-red-500/30 hover:border-red-500/50 hover:text-red-400"
            >
              {isUndelegating || isUndelegateConfirming ? (
                <>
                  <FiLoader className="w-4 h-4 animate-spin" />
                  {isUndelegating ? 'Confirm...' : 'Processing...'}
                </>
              ) : isUndelegateSimulating ? (
                <>
                  <FiLoader className="w-4 h-4 animate-spin" />
                  Validating...
                </>
              ) : (
                <>
                  <FiArrowLeft className="w-4 h-4" />
                  Undelegate
                </>
              )}
            </button>
          </div>
        </motion.div>
      </div>

      {/* Current Delegations */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5 }}
        className="panel"
      >
        <div className="p-4 border-b border-slate-700/30 flex items-center justify-between">
          <div>
            <h3 className="font-heading font-semibold text-slate-100">Your Delegations</h3>
            <p className="text-slate-500 text-xs mt-0.5">Members you've delegated voting power to</p>
          </div>
          <span className="badge badge-primary">{delegations.length} active</span>
        </div>

        {delegations.length > 0 ? (
          <div className="divide-y divide-slate-700/30">
            {delegations.map((delegation) => {
              const member = members.find(m => m.tokenId === delegation.tokenId)
              const isDirectorSeat = !!(member?.rank && member.rank <= seats)
              return (
                <div key={delegation.tokenId.toString()} className="p-4 flex items-center gap-4">
                  <DelegationMemberAvatar
                    key={`${chamberAddress}-${delegation.tokenId.toString()}`}
                    nftToken={nftToken && nftToken !== zeroAddress ? nftToken : undefined}
                    tokenId={delegation.tokenId}
                    chamberAddress={chamberAddress}
                    isDirector={isDirectorSeat}
                  />
                  <div className="flex-1">
                    <div className="font-mono text-slate-100">
                      Member #{delegation.tokenId.toString()}
                    </div>
                    {member && member.rank && member.rank <= seats && (
                      <span className="badge badge-primary text-[10px] mt-1">
                        Director · Rank #{member.rank}
                      </span>
                    )}
                  </div>
                  <div className="text-right">
                    <div className="font-mono text-slate-100">
                      {parseFloat(formatUnits(delegation.amount, 18)).toFixed(4)}
                      {vaultSymbol && <span className="text-slate-400 ml-1">{vaultSymbol}</span>}
                    </div>
                    <div className="text-slate-500 text-xs">delegated</div>
                  </div>
                </div>
              )
            })}
          </div>
        ) : (
          <div className="p-8 text-center">
            <FiInfo className="w-8 h-8 text-slate-600 mx-auto mb-3" />
            <p className="text-slate-500">You haven't delegated to any members yet</p>
            <p className="text-slate-600 text-sm mt-1">
              Delegate your shares to give voting power to board candidates
            </p>
          </div>
        )}
      </motion.div>
    </div>
  )
}

function DelegationMemberAvatar({
  nftToken,
  tokenId,
  chamberAddress,
  isDirector,
}: {
  nftToken: `0x${string}` | undefined
  tokenId: bigint
  chamberAddress: `0x${string}`
  isDirector: boolean
}) {
  const { data: imageUrl, resolvingImages } = useNftTokenImage(nftToken, tokenId, {
    chamberAddress,
  })
  const [broken, setBroken] = useState(false)
  useEffect(() => setBroken(false), [imageUrl])
  const showImg = !!(imageUrl && !broken)
  const pending = !!nftToken && resolvingImages && !imageUrl

  return (
    <div
      className={`w-11 h-11 rounded-full overflow-hidden flex items-center justify-center shrink-0 ring-2 ring-offset-2 ring-offset-slate-900/90
        ${isDirector ? 'ring-accent-500/55' : 'ring-slate-600/70'}
        ${showImg ? '' : isDirector ? 'bg-accent-500/15' : 'bg-slate-800/90'}`}
    >
      {showImg ? (
        <NftRetryableImage
          src={imageUrl}
          alt=""
          className="w-full h-full object-cover"
          onLoadFailed={() => setBroken(true)}
        />
      ) : pending ? (
        <div className="w-full h-full animate-pulse bg-slate-600/60" aria-hidden />
      ) : (
        <FiUser className={`w-5 h-5 ${isDirector ? 'text-accent-400' : 'text-slate-500'}`} />
      )}
    </div>
  )
}
