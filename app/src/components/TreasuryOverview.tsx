import { useState, useEffect, useMemo } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useAccount, useReadContract } from 'wagmi'
import { formatUnits, parseUnits, maxUint256 } from 'viem'
import {
  FiArrowDownCircle,
  FiArrowUpCircle,
  FiPieChart,
  FiTrendingUp,
  FiLoader,
  FiAlertCircle,
  FiCheck,
  FiUnlock,
  FiUser,
} from 'react-icons/fi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import toast from 'react-hot-toast'
import { 
  useDeposit, 
  useWithdraw, 
  useChamberInfo, 
  useTokenAllowance, 
  useTokenApprove,
  useTokenBalance,
  useChamberEvents,
  useSimulateDeposit,
  useSimulateWithdraw,
} from '@/hooks'
import { erc20Abi } from '@/contracts'

interface TreasuryOverviewProps {
  chamberAddress: `0x${string}`
  chamberInfo: ReturnType<typeof useChamberInfo>
  userBalance: bigint | undefined
  /** Total shares the user has delegated (locked, non-withdrawable) */
  totalDelegated?: bigint
}

export default function TreasuryOverview({ chamberAddress, chamberInfo, userBalance, totalDelegated = 0n }: TreasuryOverviewProps) {
  const { address: userAddress, isConnected } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [pollAllowanceAfterApprove, setPollAllowanceAfterApprove] = useState(false)

  const depositAmountBigInt = useMemo(() => {
    try {
      return depositAmount ? parseUnits(depositAmount, 18) : 0n
    } catch {
      return 0n
    }
  }, [depositAmount])

  const withdrawAmountBigInt = useMemo(() => {
    try {
      return withdrawAmount ? parseUnits(withdrawAmount, 18) : 0n
    } catch {
      return 0n
    }
  }, [withdrawAmount])

  // Get asset token symbol
  const { data: assetSymbol } = useReadContract({
    address: chamberInfo.assetToken,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: !!chamberInfo.assetToken },
  })

  // Get user's token balance and allowance
  const { balance: tokenBalance, refetch: refetchTokenBalance } = useTokenBalance(
    chamberInfo.assetToken,
    userAddress
  )
  const { allowance, refetch: refetchAllowance } = useTokenAllowance(
    chamberInfo.assetToken,
    userAddress,
    chamberAddress,
    {
      refetchInterval:
        pollAllowanceAfterApprove && depositAmountBigInt > 0n ? 2500 : false,
    }
  )

  const { approve, isPending: isApproving, isConfirming: isApproveConfirming, isSuccess: isApproveSuccess } = useTokenApprove(chamberInfo.assetToken)
  const { deposit, isPending: isDepositing, isConfirming: isDepositConfirming } = useDeposit(chamberAddress)
  const { withdraw, isPending: isWithdrawing, isConfirming: isWithdrawConfirming } = useWithdraw(chamberAddress)

  // Watch for vault events and refresh data when transactions are mined
  useChamberEvents(chamberAddress, {
    onVaultEvent: () => {
      refetchTokenBalance()
      refetchAllowance()
    },
  })

  // Refetch allowance after approval succeeds
  useEffect(() => {
    if (isApproveSuccess) {
      void refetchAllowance()
    }
  }, [isApproveSuccess, refetchAllowance])

  useEffect(() => {
    if (isApproveSuccess) setPollAllowanceAfterApprove(true)
  }, [isApproveSuccess])

  // Calculate if approval is needed
  const needsApproval = allowance !== undefined && depositAmountBigInt > 0n && allowance < depositAmountBigInt

  const syncingAllowanceAfterApprove =
    pollAllowanceAfterApprove && needsApproval && !isApproving && !isApproveConfirming

  useEffect(() => {
    if (!needsApproval) setPollAllowanceAfterApprove(false)
  }, [needsApproval])

  useEffect(() => {
    if (!pollAllowanceAfterApprove || depositAmountBigInt === 0n) return
    const t = window.setTimeout(() => setPollAllowanceAfterApprove(false), 120_000)
    return () => window.clearTimeout(t)
  }, [pollAllowanceAfterApprove, depositAmountBigInt])

  // Simulate transactions to catch errors before user submits
  const { 
    isValid: isDepositValid, 
    error: depositSimError,
    isLoading: isDepositSimulating,
  } = useSimulateDeposit(
    chamberAddress,
    depositAmountBigInt > 0n ? depositAmountBigInt : undefined,
    userAddress,
    {
      queryEnabled:
        !needsApproval && !isDepositing && !isDepositConfirming,
    }
  )

  const { 
    isValid: isWithdrawValid, 
    error: withdrawSimError,
    isLoading: isWithdrawSimulating,
  } = useSimulateWithdraw(
    chamberAddress,
    withdrawAmountBigInt > 0n ? withdrawAmountBigInt : undefined,
    userAddress,
    userAddress,
    { queryEnabled: !isWithdrawing && !isWithdrawConfirming }
  )

  // Helper to extract readable error message
  const getErrorMessage = (error: Error | null): string | null => {
    if (!error) return null
    const message = error.message || ''
    
    // Map custom error names to user-friendly messages
    const errorMessages: Record<string, string> = {
      'InsufficientChamberBalance': 'You don\'t have enough shares',
      'InsufficientDelegatedAmount': 'Insufficient delegated amount',
      'ZeroAmount': 'Amount cannot be zero',
      'ExceedsDelegatedAmount': 'Cannot withdraw - some shares are delegated',
      'ERC20InsufficientAllowance': 'Token approval required',
      'ERC20InsufficientBalance': 'Insufficient token balance',
      'AssetAmountMismatch': 'Fee-on-transfer or rebasing tokens revert on deposit',
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
    
    // Common error patterns
    if (message.includes('insufficient')) return 'Insufficient balance'
    if (message.includes('exceeds')) return 'Amount exceeds balance'
    if (message.includes('allowance')) return 'Insufficient token allowance'
    
    // Return truncated message
    return message.length > 100 ? message.slice(0, 100) + '...' : message
  }

  const handleApprove = async () => {
    if (!chamberAddress) return
    try {
      await approve(chamberAddress, maxUint256) // Approve max for convenience
      toast.success('Approval submitted!')
    } catch (err) {
      console.error(err)
      toast.error('Approval failed')
    }
  }

  const handleDeposit = async () => {
    if (!depositAmount || !userAddress) return
    try {
      const amount = parseUnits(depositAmount, 18)
      await deposit(amount, userAddress)
      toast.success('Deposit submitted!')
      setDepositAmount('')
      refetchTokenBalance()
    } catch (err) {
      console.error(err)
      toast.error('Deposit failed')
    }
  }

  const handleWithdraw = async () => {
    if (!withdrawAmount || !userAddress) return
    try {
      const amount = parseUnits(withdrawAmount, 18)
      await withdraw(amount, userAddress, userAddress)
      toast.success('Withdrawal submitted!')
      setWithdrawAmount('')
    } catch (err) {
      console.error(err)
      toast.error('Withdrawal failed')
    }
  }

  const vaultPaused = chamberInfo.paused === true

  return (
    <div className="space-y-6">
      {vaultPaused && (
        <div className="rounded-xl border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-200">
          This chamber is paused. Deposits and withdrawals are halted until the board unpauses.{' '}
          <Link to="/docs/protocol/governance" className="text-accent-400 hover:underline">
            How governance works →
          </Link>
        </div>
      )}
      {/* Treasury Stats */}
      <div className="grid md:grid-cols-3 gap-5">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="panel p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="icon-container-emerald w-12 h-12">
              <FiPieChart className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Total Assets</p>
              <p className="font-heading text-2xl font-bold gradient-text">
                {chamberInfo.totalAssets !== undefined
                  ? parseFloat(formatUnits(chamberInfo.totalAssets, 18)).toLocaleString(undefined, {
                      maximumFractionDigits: 2,
                    })
                  : '...'
                }
                {assetSymbol && (
                  <span className="text-lg text-slate-400 ml-2">{assetSymbol as string}</span>
                )}
              </p>
            </div>
          </div>
          <div className="h-2 bg-slate-800 rounded-full overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: '75%' }}
              transition={{ duration: 1 }}
              className="h-full bg-gradient-to-r from-emerald-500 to-emerald-400 rounded-full"
            />
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="panel p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="icon-container bg-blue-500/15 text-blue-400 w-12 h-12">
              <FiTrendingUp className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Total Shares</p>
              <p className="font-heading text-2xl font-bold text-slate-100">
                {chamberInfo.totalSupply !== undefined
                  ? parseFloat(formatUnits(chamberInfo.totalSupply, 18)).toLocaleString(undefined, {
                      maximumFractionDigits: 2,
                    })
                  : '...'
                }
                {chamberInfo.symbol && (
                  <span className="text-lg text-slate-400 ml-2">{chamberInfo.symbol}</span>
                )}
              </p>
            </div>
          </div>
          <div className="text-slate-500 text-sm">
            1 {chamberInfo.symbol || 'share'} = {chamberInfo.totalSupply && chamberInfo.totalAssets && chamberInfo.totalSupply > 0n
              ? (Number(chamberInfo.totalAssets) / Number(chamberInfo.totalSupply)).toFixed(4)
              : '1.0000'
            } {assetSymbol as string || 'assets'}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="panel p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="icon-container-accent w-12 h-12">
              <FiPieChart className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Your Shares</p>
              <p className="font-heading text-2xl font-bold gradient-text">
                {userBalance !== undefined
                  ? parseFloat(formatUnits(userBalance, 18)).toLocaleString(undefined, {
                      maximumFractionDigits: 4,
                    })
                  : '—'}
                {userBalance !== undefined && chamberInfo.symbol && (
                  <span className="text-lg text-slate-400 ml-2">{chamberInfo.symbol}</span>
                )}
              </p>
            </div>
          </div>
          {userBalance !== undefined && chamberInfo.totalSupply && chamberInfo.totalSupply > 0n ? (
            <div className="text-slate-500 text-sm">
              {((Number(userBalance) / Number(chamberInfo.totalSupply)) * 100).toFixed(2)}% of total supply
            </div>
          ) : null}
        </motion.div>
      </div>

      {!isConnected ? (
        <div className="panel p-10 text-center space-y-4">
          <FiUser className="w-8 h-8 text-slate-600 mx-auto" />
          <div>
            <h3 className="font-heading text-lg font-semibold text-slate-300 mb-1">Connect your wallet</h3>
            <p className="text-slate-500 text-sm">Connect to deposit assets and withdraw shares.</p>
          </div>
          <div className="flex justify-center pt-2">
            <ConnectButton accountStatus="address" chainStatus="icon" showBalance={false} />
          </div>
        </div>
      ) : (
      <div className="grid md:grid-cols-2 gap-5 md:items-stretch">
        {/* Deposit */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="panel p-6 flex flex-col h-full"
        >
          <div className="flex items-center gap-3 mb-5">
            <div className="icon-container-emerald shrink-0">
              <FiArrowDownCircle className="w-5 h-5" />
            </div>
            <div className="min-w-0">
              <h3 className="font-heading font-semibold text-slate-100 leading-tight">Deposit</h3>
              <p className="text-slate-500 text-xs mt-0.5">Add assets to receive shares</p>
            </div>
          </div>

          <div className="flex flex-col flex-1 min-h-0 space-y-4">
            <div className="rounded-xl border border-slate-700/50 bg-slate-950/40 px-3.5 py-3">
              <div className="flex items-center justify-between gap-3 text-sm">
                <span className="text-slate-500 shrink-0">Wallet balance</span>
                <span className="text-slate-200 font-mono text-right tabular-nums">
                  {tokenBalance !== undefined
                    ? `${parseFloat(formatUnits(tokenBalance, 18)).toLocaleString(undefined, { maximumFractionDigits: 4 })} ${assetSymbol as string || ''}`
                    : '—'}
                </span>
              </div>
            </div>

            <div className="flex-1 min-h-0 flex flex-col space-y-4">
              <div>
                <label className="block text-slate-300 text-sm font-medium mb-2">Amount</label>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="0.00"
                    className="input pr-20"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    min="0"
                    step="any"
                  />
                  <button
                    type="button"
                    onClick={() => tokenBalance && setDepositAmount(formatUnits(tokenBalance, 18))}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-accent-400 hover:text-accent-300 text-sm font-medium"
                  >
                    MAX
                  </button>
                </div>
              </div>

              <div className="min-h-[2.75rem] flex items-center">
                {depositAmount ? (
                  <div className="flex items-center gap-2 text-sm">
                    {syncingAllowanceAfterApprove ? (
                      <>
                        <FiLoader className="w-4 h-4 text-amber-400 shrink-0 animate-spin" />
                        <span className="text-amber-400/95">Updating allowance onchain…</span>
                      </>
                    ) : needsApproval ? (
                      <>
                        <FiUnlock className="w-4 h-4 text-amber-400 shrink-0" />
                        <span className="text-amber-400/95">Approval required before deposit</span>
                      </>
                    ) : allowance !== undefined && depositAmountBigInt > 0n ? (
                      <>
                        <FiCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                        <span className="text-emerald-400/95">Allowance sufficient</span>
                      </>
                    ) : null}
                  </div>
                ) : (
                  <span className="text-xs text-slate-600">Enter an amount to validate allowance</span>
                )}
              </div>

              {depositAmount && !needsApproval && depositSimError && (
                <div className="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                  <FiAlertCircle className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
                  <div className="text-red-400 text-sm">
                    <span className="font-medium">Transaction will fail: </span>
                    {getErrorMessage(depositSimError)}
                  </div>
                </div>
              )}
            </div>

            <div className="mt-auto pt-1 space-y-3">
              {needsApproval ? (
                <button
                  type="button"
                  onClick={handleApprove}
                  disabled={
                    isApproving ||
                    isApproveConfirming ||
                    syncingAllowanceAfterApprove
                  }
                  className="btn w-full border border-amber-500/40 bg-amber-600/85 text-white hover:bg-amber-500 shadow-sm"
                >
                  {isApproving || isApproveConfirming ? (
                    <>
                      <FiLoader className="w-4 h-4 animate-spin" />
                      {isApproving ? 'Confirm...' : 'Approving...'}
                    </>
                  ) : syncingAllowanceAfterApprove ? (
                    <>
                      <FiLoader className="w-4 h-4 animate-spin" />
                      Updating allowance…
                    </>
                  ) : (
                    <>
                      <FiUnlock className="w-4 h-4" />
                      Approve token
                    </>
                  )}
                </button>
              ) : (
                <button
                  type="button"
                  onClick={handleDeposit}
                  disabled={vaultPaused || isDepositing || isDepositConfirming || !depositAmount || !!(depositAmount && !isDepositValid && !isDepositSimulating)}
                  className="btn btn-primary w-full"
                >
                  {isDepositing || isDepositConfirming ? (
                    <>
                      <FiLoader className="w-4 h-4 animate-spin" />
                      {isDepositing ? 'Confirm...' : 'Processing...'}
                    </>
                  ) : isDepositSimulating ? (
                    <>
                      <FiLoader className="w-4 h-4 animate-spin" />
                      Validating...
                    </>
                  ) : (
                    <>
                      <FiArrowDownCircle className="w-4 h-4" />
                      Deposit
                    </>
                  )}
                </button>
              )}
            </div>
          </div>
        </motion.div>

        {/* Withdraw */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="panel p-6 flex flex-col h-full"
        >
          <div className="flex items-center gap-3 mb-5">
            <div className="icon-container-rose shrink-0">
              <FiArrowUpCircle className="w-5 h-5" />
            </div>
            <div className="min-w-0">
              <h3 className="font-heading font-semibold text-slate-100 leading-tight">Withdraw</h3>
              <p className="text-slate-500 text-xs mt-0.5">Burn shares to receive assets</p>
            </div>
          </div>

          <div className="flex flex-col flex-1 min-h-0 space-y-4">
            <div className="rounded-xl border border-slate-700/50 bg-slate-950/40 px-3.5 py-3">
              <div className="flex items-center justify-between gap-3 text-sm">
                <span className="text-slate-500 shrink-0">Withdrawable</span>
                <span className="text-slate-200 font-mono text-right tabular-nums">
                  {userBalance !== undefined
                    ? `${parseFloat(formatUnits(userBalance > totalDelegated ? userBalance - totalDelegated : 0n, 18)).toFixed(4)} ${chamberInfo.symbol || ''}`
                    : '—'}
                </span>
              </div>
              {totalDelegated > 0n && userBalance !== undefined && (
                <p className="mt-2.5 text-xs leading-relaxed text-amber-200/90 border-l-2 border-amber-500/45 pl-2.5">
                  <span className="font-medium text-amber-300">
                    {parseFloat(formatUnits(totalDelegated, 18)).toFixed(4)} {chamberInfo.symbol || 'shares'} delegated
                  </span>
                  <span className="text-amber-200/75"> — locked until you undelegate.</span>
                </p>
              )}
            </div>

            <div className="flex-1 min-h-0 flex flex-col space-y-4">
              <div>
                <label className="block text-slate-300 text-sm font-medium mb-2">Amount</label>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="0.00"
                    className="input pr-20"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                    min="0"
                    step="any"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      if (userBalance === undefined) return
                      const withdrawable = userBalance > totalDelegated ? userBalance - totalDelegated : 0n
                      setWithdrawAmount(formatUnits(withdrawable, 18))
                    }}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-accent-400 hover:text-accent-300 text-sm font-medium"
                  >
                    MAX
                  </button>
                </div>
              </div>

              <div className="min-h-[2.75rem] flex items-center">
                {withdrawAmount ? (
                  <span className="text-xs text-slate-500">
                    {totalDelegated > 0n
                      ? 'Only withdrawable shares can be burned for assets.'
                      : 'Shares will be redeemed for underlying assets.'}
                  </span>
                ) : (
                  <span className="text-xs text-slate-600">Enter an amount to simulate withdrawal</span>
                )}
              </div>

              {withdrawAmount && withdrawSimError && (
                <div className="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                  <FiAlertCircle className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
                  <div className="text-red-400 text-sm">
                    <span className="font-medium">Transaction will fail: </span>
                    {getErrorMessage(withdrawSimError)}
                  </div>
                </div>
              )}
            </div>

            <div className="mt-auto pt-1">
              <button
                type="button"
                onClick={handleWithdraw}
                disabled={vaultPaused || isWithdrawing || isWithdrawConfirming || !withdrawAmount || !!(withdrawAmount && !isWithdrawValid && !isWithdrawSimulating)}
                className="btn w-full border border-rose-500/40 bg-rose-600/90 text-white hover:bg-rose-500 shadow-sm disabled:opacity-50"
              >
                {isWithdrawing || isWithdrawConfirming ? (
                  <>
                    <FiLoader className="w-4 h-4 animate-spin" />
                    {isWithdrawing ? 'Confirm...' : 'Processing...'}
                  </>
                ) : isWithdrawSimulating ? (
                  <>
                    <FiLoader className="w-4 h-4 animate-spin" />
                    Validating...
                  </>
                ) : (
                  <>
                    <FiArrowUpCircle className="w-4 h-4" />
                    Withdraw
                  </>
                )}
              </button>
            </div>
          </div>
        </motion.div>
      </div>
      )}

      {/* Info Box */}
      <div className="panel p-6 bg-accent-500/5 border-accent-500/20">
        <div className="flex items-start gap-4">
          <FiAlertCircle className="w-5 h-5 text-accent-400 flex-shrink-0 mt-0.5" />
          <div>
            <h4 className="font-medium text-slate-100 mb-1">About ERC4626 Vaults</h4>
            <p className="text-slate-400 text-sm leading-relaxed">
              This chamber implements the ERC4626 tokenized vault standard. When you deposit assets, 
              you receive shares that represent your proportional ownership of the vault. You need to 
              approve the Chamber to spend your tokens before depositing.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
