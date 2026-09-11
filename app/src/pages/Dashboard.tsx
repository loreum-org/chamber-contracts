import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { useAccount, useChainId, useReadContracts, useSwitchChain } from 'wagmi'
import { formatUnits, isAddress } from 'viem'
import { useChainModal, useConnectModal } from '@rainbow-me/rainbowkit'
import {
  FiLayers,
  FiPlus,
  FiAlertTriangle,
  FiUser,
  FiBriefcase,
  FiShield,
  FiArrowRight,
  FiRefreshCw,
  FiLoader,
} from 'react-icons/fi'
import { useHasValidConfig, useMyChambers, useOrganizationsByNFT } from '@/hooks'
import { erc721Abi } from '@/contracts'
import {
  getNetworkName,
  getPreferredSupportedChainId,
  isMainnetConfigured,
} from '@/lib/wagmi'
import {
  readSimulatedChainId,
  showMainnetUnsupportedBanner,
  switchToSupportedChainLabel,
} from '@/lib/supportedChain'
import ChamberCard from '@/components/ChamberCard'

export default function Dashboard() {
  const { isConnected } = useAccount()
  const location = useLocation()
  const navigate = useNavigate()
  const chainId = useChainId()
  const { switchChainAsync, isPending: isSwitching } = useSwitchChain()
  const { openChainModal } = useChainModal()
  const { openConnectModal } = useConnectModal()
  const [viewMode, setViewMode] = useState<'mine' | 'organizations'>('mine')
  const [openAddress, setOpenAddress] = useState('')
  const [openError, setOpenError] = useState<string | null>(null)
  const preferredChainId = getPreferredSupportedChainId()
  const bannerChainId = readSimulatedChainId(location.search, import.meta.env.DEV) ?? chainId
  const showUnsupportedMainnet = showMainnetUnsupportedBanner(bannerChainId, isMainnetConfigured)
  const switchLabel = switchToSupportedChainLabel(preferredChainId)

  const {
    chambers: myChambers,
    isLoading,
    refetch: refetchMine,
    error: chambersError,
    recents,
    remember,
    factoryAddress,
    registryAddress,
  } = useMyChambers()
  const myAddresses = myChambers.map((entry) => entry.address)
  const { organizations, isLoading: orgsLoading } = useOrganizationsByNFT(myAddresses)
  const { isValid } = useHasValidConfig()

  useEffect(() => {
    if (location.pathname === '/') {
      refetchMine()
    }
  }, [location.pathname, refetchMine])

  const handleSwitchToSupportedChain = async () => {
    if (!isConnected) {
      openConnectModal?.()
      return
    }
    if (preferredChainId && switchChainAsync) {
      try {
        await switchChainAsync({ chainId: preferredChainId })
        return
      } catch {
        openChainModal?.()
        return
      }
    }
    if (openChainModal) {
      openChainModal()
      return
    }
    openConnectModal?.()
  }

  const handleOpenAddress = (e: React.FormEvent) => {
    e.preventDefault()
    const value = openAddress.trim()
    if (!isAddress(value)) {
      setOpenError('Enter a valid chamber address')
      return
    }
    setOpenError(null)
    remember(value)
    navigate(`/chamber/${value}`)
  }

  return (
    <div className="space-y-10">
      {showUnsupportedMainnet && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="panel p-4 border-slate-600/40 bg-slate-800/20"
        >
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <p className="text-slate-300 text-sm">
              This deployment does not include <strong className="text-slate-200">Ethereum mainnet</strong>. Use your
              wallet to switch to <strong className="text-slate-200">Sepolia</strong> (or another supported network).
            </p>
            <button
              type="button"
              className="btn btn-primary shrink-0 self-start sm:self-auto"
              onClick={() => void handleSwitchToSupportedChain()}
              disabled={isSwitching}
            >
              {isSwitching ? (
                <FiLoader className="w-4 h-4 animate-spin" aria-hidden />
              ) : (
                <FiRefreshCw className="w-4 h-4" aria-hidden />
              )}
              {isSwitching ? 'Switching…' : switchLabel}
            </button>
          </div>
        </motion.div>
      )}

      {!isValid && !showUnsupportedMainnet && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="panel p-4 border-amber-500/30 bg-amber-500/5"
        >
          <div className="flex items-start gap-3">
            <FiAlertTriangle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
            <div>
              <h4 className="font-medium text-amber-400 mb-1">Contract Addresses Not Configured</h4>
              <p className="text-slate-400 text-sm">
                No Factory or Registry address configured for <strong>{getNetworkName(chainId)}</strong> (Chain ID: {chainId}).
                {chainId === 31337 ? (
                  <>
                    {' '}Deploy contracts to Anvil and update your <code className="text-accent-400">.env</code> file
                    (Factory preferred; Registry is enough for legacy deploys):
                    <code className="block mt-2 p-2 bg-slate-800/50 rounded text-xs">
                      VITE_LOCALHOST_FACTORY=0x...your_factory_address
                    </code>
                    <code className="block mt-1 p-2 bg-slate-800/50 rounded text-xs">
                      VITE_LOCALHOST_REGISTRY=0x...your_registry_address
                    </code>
                  </>
                ) : (
                  <>
                    {' '}Set <code className="text-accent-400">VITE_*_FACTORY</code> or{' '}
                    <code className="text-accent-400">VITE_*_REGISTRY</code> in your <code className="text-accent-400">.env</code> file.
                  </>
                )}
              </p>
            </div>
          </div>
        </motion.div>
      )}

      {import.meta.env.DEV && (chambersError || !isValid) && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="panel p-4 border-slate-700/50 bg-slate-800/30"
        >
          <div className="text-xs font-mono text-slate-400 space-y-1">
            <div><strong>Chain ID:</strong> {chainId} ({getNetworkName(chainId)})</div>
            <div><strong>Factory Address:</strong> {factoryAddress || 'Not set'}</div>
            <div><strong>Registry Address:</strong> {registryAddress || 'Not set'}</div>
            <div><strong>Config Valid:</strong> {isValid ? 'Yes' : 'No'}</div>
            {chambersError && <div className="text-red-400"><strong>My Chambers Error:</strong> {chambersError.message}</div>}
            <div><strong>My Chambers:</strong> {myChambers.length}</div>
          </div>
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative overflow-hidden panel px-4 py-3 md:px-5 md:py-3.5"
      >
        <div className="absolute inset-0 bg-mesh-gradient pointer-events-none opacity-[0.85]" />
        <div className="absolute top-0 right-0 w-[280px] h-[160px] md:w-[360px] md:h-[200px] bg-gradient-radial from-accent-600/[0.06] via-transparent to-transparent pointer-events-none" />

        <div className="relative flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4">
          <div className="flex items-center gap-3 min-w-0">
            <img
              src="https://cdn.loreum.org/logos/white.svg"
              alt="Chamber Logo"
              className="w-11 h-11 shrink-0 object-contain"
            />
            <div className="min-w-0">
              <p className="text-slate-500 text-[10px] font-semibold uppercase tracking-wider leading-none mb-1">
                Governance
              </p>
              <h1 className="font-heading text-xl sm:text-2xl font-bold text-slate-100 tracking-tight leading-tight">
                Loreum Chambers
              </h1>
              <p className="text-slate-500 text-xs sm:text-sm mt-0.5 leading-snug">
                Your chambers, not a global directory.
              </p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 sm:justify-end sm:shrink-0 text-sm border-t border-slate-700/35 pt-3 sm:border-0 sm:pt-0">
            <div className="flex items-baseline gap-1.5">
              <span className="text-lg font-heading font-bold gradient-text tabular-nums">
                {isLoading && isConnected ? '…' : myChambers.length}
              </span>
              <span className="text-slate-500 text-xs">mine</span>
            </div>
            <span className="hidden sm:inline h-3 w-px bg-slate-600/60" aria-hidden />
            <div className="flex items-center gap-1.5">
              <div className={`w-1.5 h-1.5 rounded-full shrink-0 ${isConnected ? 'bg-emerald-500' : 'bg-slate-600'}`} />
              <span className="text-slate-200 text-sm font-medium">
                {isConnected ? 'Connected' : 'Disconnected'}
              </span>
            </div>
            <span className="hidden sm:inline h-3 w-px bg-slate-600/60" aria-hidden />
            <div className="flex items-baseline">
              <span
                title="Chamber Solidity VERSION constant (implementation)"
                className="text-slate-200 text-sm font-mono font-semibold tabular-nums"
              >
                v1.1.6
              </span>
            </div>
          </div>
        </div>
      </motion.div>

      <section className="space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h2 className="font-heading text-2xl font-bold text-slate-100">My chambers</h2>
            <p className="text-slate-500 text-sm mt-1">Chambers you created, direct, or hold shares in</p>
          </div>

          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1 p-1 bg-slate-900/80 rounded-xl border border-slate-700/50">
              <button
                onClick={() => setViewMode('mine')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                  viewMode === 'mine' ? 'bg-accent-500/10 text-accent-400 shadow-sm' : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                <FiUser className="w-4 h-4" />
                Mine
              </button>
              <button
                onClick={() => setViewMode('organizations')}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                  viewMode === 'organizations' ? 'bg-accent-500/10 text-accent-400 shadow-sm' : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                <FiBriefcase className="w-4 h-4" />
                Organizations
              </button>
            </div>

            <Link to="/deploy" className="btn btn-primary text-sm">
              <FiPlus className="w-4 h-4" />
              New Chamber
            </Link>
          </div>
        </div>

        <form onSubmit={handleOpenAddress} className="panel p-4 flex flex-col sm:flex-row gap-3 sm:items-end">
          <div className="flex-1 min-w-0">
            <label className="block text-slate-400 text-xs font-medium mb-1.5">Open address</label>
            <input
              type="text"
              placeholder="0x… chamber address"
              className="input font-mono"
              value={openAddress}
              onChange={(e) => {
                setOpenAddress(e.target.value)
                if (openError) setOpenError(null)
              }}
            />
            {openError && <p className="text-red-400 text-xs mt-1.5">{openError}</p>}
          </div>
          <button type="submit" className="btn btn-secondary shrink-0">
            Open
            <FiArrowRight className="w-4 h-4" />
          </button>
        </form>

        {recents.length > 0 && (
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-slate-500 text-xs uppercase tracking-wider">Recents</span>
            {recents.map((addr) => (
              <Link
                key={addr}
                to={`/chamber/${addr}`}
                className="badge bg-slate-800 text-slate-300 border-slate-600/60 font-mono text-[11px] hover:text-slate-100"
              >
                {addr.slice(0, 8)}…{addr.slice(-6)}
              </Link>
            ))}
          </div>
        )}

        <AnimatePresence mode="wait">
          {viewMode === 'mine' ? (
            <motion.div
              key="my-chambers"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              transition={{ duration: 0.2 }}
            >
              {!isConnected ? (
                <EmptyChambers disconnected />
              ) : isLoading ? (
                <div className="grid gap-5" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 340px), 1fr))' }}>
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="card animate-pulse">
                      <div className="h-5 bg-slate-800 rounded-lg w-1/3 mb-4" />
                      <div className="h-4 bg-slate-800 rounded-lg w-full mb-2" />
                      <div className="h-4 bg-slate-800 rounded-lg w-2/3" />
                    </div>
                  ))}
                </div>
              ) : myChambers.length > 0 ? (
                <div className="grid gap-5" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 340px), 1fr))' }}>
                  {myChambers.map((entry, index) => (
                    <motion.div
                      key={entry.address}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                      className="relative"
                    >
                      {entry.isDirector && (
                        <div className="absolute -top-2 -left-2 z-10">
                          <span className="badge bg-accent-600/80 text-white border-accent-500/40 text-[10px]">
                            <FiShield className="w-3 h-3 mr-1" />
                            Director
                          </span>
                        </div>
                      )}
                      {entry.balance > 0n && !entry.isDirector && (
                        <div className="absolute -top-2 -left-2 z-10">
                          <span className="badge bg-slate-700 text-slate-300 border-slate-600 text-[10px]">
                            {parseFloat(formatUnits(entry.balance, 18)).toFixed(2)} shares
                          </span>
                        </div>
                      )}
                      <ChamberCard address={entry.address} />
                    </motion.div>
                  ))}
                </div>
              ) : (
                <EmptyChambers />
              )}
            </motion.div>
          ) : (
            <motion.div
              key="org-chambers"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.2 }}
              className="space-y-8"
            >
              {!isConnected ? (
                <EmptyChambers disconnected />
              ) : orgsLoading ? (
                <div className="space-y-8">
                  {[1, 2].map((i) => (
                    <div key={i} className="space-y-4">
                      <div className="h-8 bg-slate-800 rounded-lg w-1/4 animate-pulse" />
                      <div className="grid gap-5" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 340px), 1fr))' }}>
                        {[1, 2].map((j) => (
                          <div key={j} className="card h-40 animate-pulse" />
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              ) : organizations && organizations.length > 0 ? (
                organizations.map((org, index) => (
                  <OrganizationGroup key={org.nft} nftToken={org.nft} chambers={org.chambers} index={index} />
                ))
              ) : (
                <EmptyChambers />
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </section>
    </div>
  )
}

function OrganizationGroup({ nftToken, chambers, index }: { nftToken: `0x${string}`; chambers: `0x${string}`[]; index: number }) {
  const { data: symbol } = useReadContracts({
    contracts: [
      { address: nftToken, abi: erc721Abi, functionName: 'symbol' as const },
      { address: nftToken, abi: erc721Abi, functionName: 'name' as const },
    ],
  })

  const nftSymbol = symbol?.[0]?.result as string | undefined
  const nftName = symbol?.[1]?.result as string | undefined
  const shortNft = `${nftToken.slice(0, 8)}…${nftToken.slice(-6)}`

  if (!chambers || chambers.length === 0) return null

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      className="space-y-4"
    >
      <div className="flex items-center gap-3 px-2">
        <div className="w-10 h-10 rounded-lg bg-slate-800/90 flex items-center justify-center border border-slate-600/45">
          <FiBriefcase className="w-5 h-5 text-accent-400" />
        </div>
        <div>
          <h3 className="font-heading text-lg font-bold text-slate-100 flex items-center gap-2">
            {nftName || 'Loading...'}
            {nftSymbol && <span className="text-slate-500 text-sm font-normal">({nftSymbol})</span>}
          </h3>
          <p className="text-slate-500 text-xs font-mono">
            Member Token: {shortNft}
          </p>
        </div>
      </div>

      <div className="grid gap-5" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 340px), 1fr))' }}>
        {chambers.map((address) => (
          <ChamberCard key={address} address={address} />
        ))}
      </div>
    </motion.div>
  )
}

function EmptyChambers({ disconnected = false }: { disconnected?: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="panel p-12 text-center"
    >
      <div className="w-16 h-16 bg-slate-800/80 rounded-2xl flex items-center justify-center mx-auto mb-5">
        <FiLayers className="w-8 h-8 text-slate-600" />
      </div>
      <h3 className="font-heading text-xl font-semibold text-slate-300 mb-2">
        {disconnected ? 'Connect to see your chambers' : 'No chambers yet'}
      </h3>
      <p className="text-slate-500 max-w-md mx-auto mb-6">
        {disconnected
          ? 'Connect a wallet to list chambers you created, direct, or hold. You can also open one by address.'
          : 'Deploy a chamber, or paste an address above if it is not in this wallet’s recents yet.'}
      </p>
      <Link to="/deploy" className="btn btn-primary inline-flex">
        <FiPlus className="w-4 h-4" />
        Deploy a Chamber
      </Link>
    </motion.div>
  )
}
