import { useState, useEffect } from 'react'
import { useSearchParams, Link } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { useAccount, useReadContract, useSwitchChain } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { isAddress, parseEventLogs, zeroAddress } from 'viem'
import { useQueryClient } from '@tanstack/react-query'
import { FiAlertCircle, FiAlertTriangle, FiCheck, FiLoader, FiArrowRight, FiArrowLeft, FiCopy } from 'react-icons/fi'
import { useCreateChamberTarget, useCreateChamberWithStatus } from '@/hooks'
import {
  getConfiguredChainName,
  getContractAddresses,
  getPreferredCreateChainId,
  isNonZeroAddress,
} from '@/lib/wagmi'
import { addRecentChamber } from '@/lib/recentChambers'
import { factoryAbi, registryAbi } from '@/contracts/abis'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { erc20Abi, erc721Abi } from '@/contracts'
import SeatTheBoard from '@/components/SeatTheBoard'
import toast from 'react-hot-toast'

type Step = 'form' | 'review' | 'deploying' | 'success'

const CREATE_TARGET_MISSING =
  'No Factory or Registry is configured on this network. Switch to a supported chain to deploy.'

function quorumForSeats(seats: number) {
  return 1 + Math.floor((seats * 51) / 100)
}

function isValidAddress(s: string): boolean {
  return isAddress(s)
}

function shortenAddress(addr: `0x${string}`) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export default function DeployChamber() {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const { address: createAddress, abi: createAbi, source: createSource } = useCreateChamberTarget()
  const canCreate = createSource !== 'none' && !!createAddress
  const preferredCreateChainId = getPreferredCreateChainId()
  const preferredCreateChainName = getConfiguredChainName(preferredCreateChainId)
  const currentNetworkName = getConfiguredChainName(chainId)
  const sepoliaAddrs = getContractAddresses(sepolia.id)
  const sepoliaDemoReady =
    isNonZeroAddress(sepoliaAddrs?.mockERC20) && isNonZeroAddress(sepoliaAddrs?.mockERC721)
  const queryClient = useQueryClient()

  const [step, setStep] = useState<Step>('form')
  const [deployedTxHash, setDeployedTxHash] = useState<string | undefined>()
  const [deployedChamber, setDeployedChamber] = useState<`0x${string}` | undefined>()
  const [formData, setFormData] = useState({
    erc20Token: '',
    erc721Token: '',
    seats: '5',
    name: '',
    symbol: '',
  })

  const {
    createChamber,
    status,
    isPending,
    isConfirming,
    error,
    hash,
    reset,
  } = useCreateChamberWithStatus(createAddress, {
    abi: createAbi,
    onSuccess: (receipt) => {
      const createAddrLower = createAddress?.toLowerCase()
      queryClient.invalidateQueries({
        predicate: (query) => {
          try {
            const str = JSON.stringify(query.queryKey).toLowerCase()
            return str.includes('my-chambers') ||
              (createAddrLower ? str.includes(createAddrLower) : false)
          } catch { return false }
        },
      })
      try {
        const parsed = parseEventLogs({
          abi: createSource === 'factory' ? factoryAbi : registryAbi,
          logs: receipt?.logs ?? [],
          eventName: 'ChamberCreated',
        })
        const chamber = parsed[0]?.args?.chamber as `0x${string}` | undefined
        if (chamber && typeof chainId === 'number') {
          addRecentChamber(chainId, chamber)
          setDeployedChamber(chamber)
        }
      } catch {
        // receipt may omit decoded logs; dashboard indexer / getLogs / recents still pick it up
      }
      setDeployedTxHash(hash)
      setStep('success')
    },
    onError: () => {
      setTimeout(() => reset(), 4000)
    },
    successMessage: 'Chamber deployed successfully!',
    errorMessage: 'Failed to deploy chamber. Please try again.',
    showNotifications: true,
    autoReset: false,
  })

  const [searchParams] = useSearchParams()

  useEffect(() => {
    const erc20 = searchParams.get('erc20')
    const erc721 = searchParams.get('erc721')
    if (erc20 && erc721 && isValidAddress(erc20) && isValidAddress(erc721)) {
      setFormData((prev) => ({ ...prev, erc20Token: erc20, erc721Token: erc721 }))
      return
    }
    if (typeof chainId !== 'number') return
    const addresses = getContractAddresses(chainId)
    const mock20 =
      addresses?.mockERC20 &&
      addresses.mockERC20 !== zeroAddress
        ? addresses.mockERC20
        : undefined
    const mock721 =
      addresses?.mockERC721 &&
      addresses.mockERC721 !== zeroAddress
        ? addresses.mockERC721
        : undefined
    if (mock20 && mock721) {
      setFormData((prev) => ({
        ...prev,
        erc20Token: prev.erc20Token || mock20,
        erc721Token: prev.erc721Token || mock721,
      }))
    }
  }, [searchParams, chainId])

  // Live validation: read token names/symbols to confirm addresses are real contracts
  const erc20Valid = isValidAddress(formData.erc20Token)
  const erc721Valid = isValidAddress(formData.erc721Token)

  const { data: erc20Symbol, isLoading: erc20Loading } = useReadContract({
    address: erc20Valid ? (formData.erc20Token as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'symbol',
    query: { enabled: erc20Valid, retry: 1 },
  })

  const { data: erc20Name } = useReadContract({
    address: erc20Valid ? (formData.erc20Token as `0x${string}`) : undefined,
    abi: erc20Abi,
    functionName: 'name',
    query: { enabled: erc20Valid, retry: 1 },
  })

  const { data: erc721Name, isLoading: erc721Loading } = useReadContract({
    address: erc721Valid ? (formData.erc721Token as `0x${string}`) : undefined,
    abi: erc721Abi,
    functionName: 'name',
    query: { enabled: erc721Valid, retry: 1 },
  })

  const { data: erc721Symbol } = useReadContract({
    address: erc721Valid ? (formData.erc721Token as `0x${string}`) : undefined,
    abi: erc721Abi,
    functionName: 'symbol',
    query: { enabled: erc721Valid, retry: 1 },
  })

  const erc20Confirmed = erc20Valid && !!erc20Symbol
  const erc721Confirmed = erc721Valid && !!erc721Name
  const erc20Error = erc20Valid && !erc20Loading && !erc20Symbol
  const erc721Error = erc721Valid && !erc721Loading && !erc721Name

  const canProceedToReview =
    canCreate &&
    !!formData.name &&
    !!formData.symbol &&
    erc20Confirmed &&
    erc721Confirmed

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!canCreate) {
      toast.error(CREATE_TARGET_MISSING)
      return
    }
    if (canProceedToReview) setStep('review')
  }

  const handleConfirmDeploy = async () => {
    if (!createAddress) {
      toast.error(CREATE_TARGET_MISSING)
      return
    }
    setStep('deploying')
    reset()
    try {
      await createChamber(
        formData.erc20Token as `0x${string}`,
        formData.erc721Token as `0x${string}`,
        parseInt(formData.seats),
        formData.name,
        formData.symbol
      )
    } catch (err) {
      console.error('Failed to initiate deployment:', err)
      if (err instanceof Error && err.message.includes('No Factory or Registry')) {
        toast.error(CREATE_TARGET_MISSING)
      }
      setStep('review')
    }
  }

  const handleSwitchToCreateChain = () => {
    if (preferredCreateChainId == null) return
    switchChain(
      { chainId: preferredCreateChainId },
      {
        onError: (err) => {
          toast.error(err.message || `Failed to switch to ${preferredCreateChainName}`)
        },
      },
    )
  }

  const seats = parseInt(formData.seats)
  const quorum = quorumForSeats(seats)

  if (step === 'success') {
    return (
      <div className="max-w-2xl mx-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          className="panel p-10 text-center space-y-6"
        >
          <div className="w-16 h-16 bg-emerald-500/15 rounded-2xl flex items-center justify-center mx-auto">
            <FiCheck className="w-8 h-8 text-emerald-400" />
          </div>
          <div>
            <h2 className="font-heading text-2xl font-bold text-slate-100 mb-2">Chamber Deployed</h2>
            <p className="text-slate-400">
              Your chamber is live. The board is empty until you hold a membership NFT and delegate to it.
            </p>
          </div>
          {(deployedTxHash || hash) && (
            <div className="stat-card flex items-center justify-between gap-3">
              <span className="text-slate-500 text-xs">Transaction</span>
              <div className="flex items-center gap-2">
                <span className="font-mono text-xs text-slate-300">
                  {(deployedTxHash || hash)!.slice(0, 12)}…{(deployedTxHash || hash)!.slice(-8)}
                </span>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(deployedTxHash || hash || '')
                    toast.success('Copied!')
                  }}
                  className="p-1 rounded text-slate-500 hover:text-slate-200 transition-colors"
                >
                  <FiCopy className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
          {deployedChamber && (
            <div className="text-left">
              <SeatTheBoard
                chamberAddress={deployedChamber}
                nftToken={
                  isValidAddress(formData.erc721Token)
                    ? (formData.erc721Token as `0x${string}`)
                    : undefined
                }
                assumeEmpty
              />
            </div>
          )}
          <div className="flex gap-3 justify-center">
            <Link
              to={deployedChamber ? `/chamber/${deployedChamber}/delegation` : '/'}
              className="btn btn-secondary"
            >
              {deployedChamber ? 'Open Chamber' : 'Go to Dashboard'}
              <FiArrowRight className="w-4 h-4" />
            </Link>
            <button
              onClick={() => { reset(); setStep('form'); setFormData({ erc20Token: '', erc721Token: '', seats: '5', name: '', symbol: '' }) }}
              className="btn btn-secondary"
            >
              Deploy Another
            </button>
          </div>
        </motion.div>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="space-y-8"
      >
        {/* Header */}
        <div className="text-center">
          <img src="https://cdn.loreum.org/logos/white.svg" alt="Chamber Logo" className="w-20 h-20 object-contain mx-auto mb-5" />
          <h1 className="font-heading text-3xl font-bold text-slate-100 mb-2 tracking-tight">
            {step === 'review' ? 'Review Chamber' : 'Deploy New Chamber'}
          </h1>
          <p className="text-slate-400">
            {step === 'review'
              ? 'Confirm your parameters before committing to the blockchain'
              : 'Create a new decentralized governance contract.'}
          </p>
        </div>

        {/* Form / Review Panel */}
        <div className="panel p-8">
          {!isConnected ? (
            <div className="text-center py-8">
              <div className="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-5">
                <FiAlertCircle className="w-8 h-8 text-accent-500" />
              </div>
              <h3 className="font-heading text-xl font-semibold text-slate-100 mb-2">Connect Your Wallet</h3>
              <p className="text-slate-400 mb-6">Connect your wallet to deploy a new Chamber</p>
              <div className="flex justify-center">
                <ConnectButton accountStatus="address" chainStatus="icon" showBalance={false} />
              </div>
              {sepoliaDemoReady && (
                <p className="text-slate-500 text-xs mt-6 max-w-md mx-auto leading-relaxed">
                  On Sepolia the form pre-fills demo ERC-20 {shortenAddress(sepoliaAddrs.mockERC20)} and membership
                  ERC-721 {shortenAddress(sepoliaAddrs.mockERC721)}. After connecting, mint from the header so your
                  wallet holds the membership NFT.
                </p>
              )}
            </div>
          ) : !canCreate ? (
            <CreateTargetMissing
              chainId={chainId}
              networkName={currentNetworkName}
              preferredCreateChainId={preferredCreateChainId}
              preferredCreateChainName={preferredCreateChainName}
              isSwitching={isSwitching}
              onSwitch={handleSwitchToCreateChain}
            />
          ) : (
            <AnimatePresence mode="wait">
              {step === 'form' && (
                <motion.form
                  key="form"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  onSubmit={handleSubmit}
                  className="space-y-6"
                >
                  {/* Chamber Name */}
                  <div>
                    <label className="block text-slate-300 text-sm font-medium mb-2">Chamber Name *</label>
                    <input
                      type="text"
                      placeholder="e.g., Treasury Alpha"
                      className="input"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      required
                    />
                    <p className="text-slate-500 text-xs mt-1.5">The name for the chamber's share token</p>
                  </div>

                  {/* Symbol */}
                  <div>
                    <label className="block text-slate-300 text-sm font-medium mb-2">Symbol *</label>
                    <input
                      type="text"
                      placeholder="e.g., ALPHA"
                      className="input"
                      value={formData.symbol}
                      onChange={(e) => setFormData({ ...formData, symbol: e.target.value })}
                      maxLength={10}
                      required
                    />
                    <p className="text-slate-500 text-xs mt-1.5">Short symbol for the share token (max 10 characters)</p>
                  </div>

                  {/* ERC20 Token */}
                  <div>
                    <label className="block text-slate-300 text-sm font-medium mb-2">Asset Contract (ERC20) *</label>
                    <input
                      type="text"
                      placeholder="0x..."
                      className={`input font-mono ${erc20Error ? 'border-red-500/60 focus:border-red-500' : erc20Confirmed ? 'border-emerald-500/60' : ''}`}
                      value={formData.erc20Token}
                      onChange={(e) => setFormData({ ...formData, erc20Token: e.target.value })}
                      required
                    />
                    <div className="mt-1.5 min-h-[1.25rem]">
                      {erc20Loading && erc20Valid && (
                        <span className="text-slate-500 text-xs flex items-center gap-1">
                          <FiLoader className="w-3 h-3 animate-spin" /> Verifying contract…
                        </span>
                      )}
                      {erc20Confirmed && (
                        <span className="text-emerald-400 text-xs flex items-center gap-1">
                          <FiCheck className="w-3 h-3" /> {erc20Name as string} ({erc20Symbol as string})
                        </span>
                      )}
                      {erc20Error && (
                        <span className="text-red-400 text-xs flex items-center gap-1">
                          <FiAlertCircle className="w-3 h-3" /> Address is not a valid ERC20 contract
                        </span>
                      )}
                      {!erc20Valid && !formData.erc20Token && (
                        <span className="text-slate-500 text-xs">The ERC20 token managed by this chamber</span>
                      )}
                      <p className="text-amber-400/90 text-xs mt-2">
                        Fee-on-transfer and rebasing tokens revert on deposit (`AssetAmountMismatch`). Use a standard ERC-20.
                      </p>
                    </div>
                  </div>

                  {/* ERC721 Token */}
                  <div>
                    <label className="block text-slate-300 text-sm font-medium mb-2">Member Contract (ERC721) *</label>
                    <input
                      type="text"
                      placeholder="0x..."
                      className={`input font-mono ${erc721Error ? 'border-red-500/60 focus:border-red-500' : erc721Confirmed ? 'border-emerald-500/60' : ''}`}
                      value={formData.erc721Token}
                      onChange={(e) => setFormData({ ...formData, erc721Token: e.target.value })}
                      required
                    />
                    <div className="mt-1.5 min-h-[1.25rem]">
                      {erc721Loading && erc721Valid && (
                        <span className="text-slate-500 text-xs flex items-center gap-1">
                          <FiLoader className="w-3 h-3 animate-spin" /> Verifying contract…
                        </span>
                      )}
                      {erc721Confirmed && (
                        <span className="text-emerald-400 text-xs flex items-center gap-1">
                          <FiCheck className="w-3 h-3" /> {erc721Name as string}{erc721Symbol ? ` (${erc721Symbol})` : ''}
                        </span>
                      )}
                      {erc721Error && (
                        <span className="text-red-400 text-xs flex items-center gap-1">
                          <FiAlertCircle className="w-3 h-3" /> Address is not a valid ERC721 contract
                        </span>
                      )}
                      {!erc721Valid && !formData.erc721Token && (
                        <span className="text-slate-500 text-xs">Contract holders can become board members via delegation</span>
                      )}
                      {chainId === sepolia.id && erc20Valid && erc721Valid && (
                        <p className="text-slate-500 text-xs mt-2">
                          Sepolia demo tokens are pre-filled. Use <span className="text-accent-400">Mint Test NFT</span> and{' '}
                          <span className="text-accent-400">Mint Test ERC20</span> in the header so your wallet holds the
                          membership NFT and demo asset.
                        </p>
                      )}
                    </div>
                  </div>

                  {/* Seats */}
                  <div>
                    <label className="block text-slate-300 text-sm font-medium mb-2">Board Seats</label>
                    <div className="flex items-center gap-4">
                      <input
                        type="range"
                        min="1"
                        max="20"
                        className="flex-1 h-2 rounded-lg bg-slate-700 appearance-none cursor-pointer accent-accent-600"
                        value={formData.seats}
                        onChange={(e) => setFormData({ ...formData, seats: e.target.value })}
                      />
                      <div className="w-16 text-center">
                        <span className="text-2xl font-heading font-bold gradient-text">{formData.seats}</span>
                      </div>
                    </div>
                    <p className="text-slate-500 text-xs mt-1.5">
                      Number of board seats. Quorum: {quorum} of {seats} director confirmations required.
                    </p>
                  </div>

                  {/* Submit */}
                  <button
                    type="submit"
                    disabled={!canProceedToReview}
                    className="btn btn-primary w-full py-3.5 text-base"
                  >
                    <span>Review & Deploy</span>
                    <FiArrowRight className="w-5 h-5" />
                  </button>
                  {!canProceedToReview && (formData.erc20Token || formData.erc721Token) && (
                    <p className="text-slate-500 text-xs text-center -mt-2">
                      Both token addresses must resolve to valid contracts before you can continue.
                    </p>
                  )}
                </motion.form>
              )}

              {(step === 'review' || step === 'deploying') && (
                <motion.div
                  key="review"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="space-y-6"
                >
                  <div className="space-y-3">
                    {[
                      { label: 'Chamber Name', value: formData.name },
                      { label: 'Share Token Symbol', value: formData.symbol },
                      {
                        label: 'Asset Contract (ERC20)',
                        value: `${erc20Name} (${erc20Symbol})`,
                        sub: formData.erc20Token,
                      },
                      {
                        label: 'Member Contract (ERC721)',
                        value: `${erc721Name}${erc721Symbol ? ` (${erc721Symbol})` : ''}`,
                        sub: formData.erc721Token,
                      },
                      { label: 'Board Seats', value: seats.toString() },
                      { label: 'Required Quorum', value: `${quorum} of ${seats} directors` },
                    ].map(({ label, value, sub }) => (
                      <div key={label} className="stat-card flex items-start justify-between gap-4">
                        <span className="text-slate-500 text-sm shrink-0">{label}</span>
                        <div className="text-right">
                          <div className="text-slate-100 font-medium text-sm">{value}</div>
                          {sub && (
                            <div className="text-slate-500 text-xs font-mono mt-0.5">
                              {sub.slice(0, 10)}…{sub.slice(-8)}
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Transaction Status (while deploying) */}
                  {step === 'deploying' && status !== 'idle' && (
                    <div className={`rounded-xl p-4 flex items-start gap-3 ${
                      status === 'error'
                        ? 'bg-red-500/10 border border-red-500/30'
                        : 'bg-accent-500/10 border border-accent-500/30'
                    }`}>
                      {status === 'error' ? (
                        <FiAlertCircle className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
                      ) : (
                        <FiLoader className="w-5 h-5 text-accent-400 shrink-0 mt-0.5 animate-spin" />
                      )}
                      <div>
                        {status === 'error' && (
                          <>
                            <p className="text-red-400 font-medium">Deployment Error</p>
                            <p className="text-red-400/80 text-sm">
                              {error?.message?.includes('User rejected') || error?.message?.includes('user rejected')
                                ? 'Transaction rejected in wallet.'
                                : error?.message?.includes('AssetAmountMismatch')
                                  ? 'Fee-on-transfer or rebasing tokens revert on chamber creation/deposit.'
                                  : 'Deployment failed. Check your wallet and network, then try again.'}
                            </p>
                          </>
                        )}
                        {(status === 'pending' || status === 'confirming') && (
                          <>
                            <p className="text-accent-400 font-medium">
                              {status === 'pending' ? 'Waiting for wallet confirmation…' : 'Confirming onchain…'}
                            </p>
                            {hash && (
                              <p className="text-accent-400/60 text-xs mt-1 font-mono">
                                {hash.slice(0, 12)}…{hash.slice(-8)}
                              </p>
                            )}
                          </>
                        )}
                      </div>
                    </div>
                  )}

                  <div className="flex gap-3">
                    <button
                      onClick={() => { setStep('form'); reset() }}
                      disabled={isPending || isConfirming}
                      className="btn btn-secondary flex-1"
                    >
                      <FiArrowLeft className="w-4 h-4" />
                      Edit
                    </button>
                    <button
                      onClick={handleConfirmDeploy}
                      disabled={!canCreate || isPending || isConfirming || step === 'deploying'}
                      className="btn btn-primary flex-1 py-3.5"
                    >
                      {isPending || isConfirming ? (
                        <>
                          <FiLoader className="w-5 h-5 animate-spin" />
                          {status === 'pending' ? 'Confirm in wallet…' : 'Deploying…'}
                        </>
                      ) : (
                        <>
                          <img src="https://cdn.loreum.org/logos/white.svg" alt="" className="w-5 h-5 object-contain" />
                          Confirm Deploy
                        </>
                      )}
                    </button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          )}
        </div>

        {/* Info Cards */}
        {step === 'form' && (canCreate || !isConnected) && (
          <div className="grid md:grid-cols-2 gap-4">
            <div className="card">
              <h4 className="font-heading font-semibold text-slate-100 mb-2">What is a Chamber?</h4>
              <p className="text-slate-400 text-sm leading-relaxed">
                A Chamber is a smart vault that combines ERC4626 tokenized treasury with board-based governance.
                Members can receive delegations to compete for board seats and control transactions.
              </p>
            </div>
            <div className="card">
              <h4 className="font-heading font-semibold text-slate-100 mb-2">How does voting work?</h4>
              <p className="text-slate-400 text-sm leading-relaxed">
                Share holders delegate voting power to member IDs. The top delegated members become board directors
                and can submit, confirm, and execute transactions once quorum is reached.
              </p>
            </div>
          </div>
        )}
      </motion.div>
    </div>
  )
}

function CreateTargetMissing({
  chainId,
  networkName,
  preferredCreateChainId,
  preferredCreateChainName,
  isSwitching,
  onSwitch,
}: {
  chainId: number | undefined
  networkName: string
  preferredCreateChainId: number | undefined
  preferredCreateChainName: string
  isSwitching: boolean
  onSwitch: () => void
}) {
  const canSwitch =
    preferredCreateChainId != null &&
    (typeof chainId !== 'number' || preferredCreateChainId !== chainId)

  return (
    <div className="text-center py-6">
      <div className="w-16 h-16 bg-amber-500/10 border border-amber-500/20 rounded-2xl flex items-center justify-center mx-auto mb-5">
        <FiAlertTriangle className="w-8 h-8 text-amber-400" />
      </div>
      <h3 className="font-heading text-xl font-semibold text-slate-100 mb-2">
        This network cannot deploy Chambers
      </h3>
      <p className="text-slate-400 mb-6 max-w-md mx-auto">
        No Factory or Registry address is configured for{' '}
        <strong className="text-slate-200">{networkName}</strong>
        {typeof chainId === 'number' ? ` (Chain ID: ${chainId})` : ''}. Review and Confirm stay
        locked until a create target exists.
      </p>
      {canSwitch && (
        <button
          type="button"
          onClick={onSwitch}
          disabled={isSwitching}
          className="btn btn-primary mx-auto"
        >
          {isSwitching ? (
            <>
              <FiLoader className="w-4 h-4 animate-spin" />
              Switching…
            </>
          ) : (
            <>Switch to {preferredCreateChainName}</>
          )}
        </button>
      )}
      {chainId === 31337 ? (
        <p className="text-slate-500 text-xs mt-6 max-w-md mx-auto leading-relaxed text-left">
          Deploy contracts to Anvil and set Factory (preferred) or Registry in your{' '}
          <code className="text-accent-400">.env</code>:
          <code className="block mt-2 p-2 bg-slate-800/50 rounded text-xs text-slate-300">
            VITE_LOCALHOST_FACTORY=0x...your_factory_address
          </code>
          <code className="block mt-1 p-2 bg-slate-800/50 rounded text-xs text-slate-300">
            VITE_LOCALHOST_REGISTRY=0x...your_registry_address
          </code>
        </p>
      ) : !canSwitch ? (
        <p className="text-slate-500 text-xs mt-6 max-w-md mx-auto leading-relaxed">
          Set <code className="text-accent-400">VITE_*_FACTORY</code> or{' '}
          <code className="text-accent-400">VITE_*_REGISTRY</code> for this chain. Do not invent
          mainnet addresses.
        </p>
      ) : (
        <p className="text-slate-500 text-xs mt-6 max-w-md mx-auto leading-relaxed">
          Or switch with your wallet to any network that already has a Factory or Registry in this
          build.
        </p>
      )}
    </div>
  )
}
