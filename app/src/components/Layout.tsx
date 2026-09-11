import { useState } from 'react'
import { Outlet, Link, useLocation } from 'react-router-dom'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { motion, AnimatePresence } from 'framer-motion'
import { FiHome, FiGithub, FiBook, FiPlus, FiMenu, FiX } from 'react-icons/fi'
import { useAccount, useWriteContract } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { simulateContract } from 'wagmi/actions'
import { zeroAddress, parseEther } from 'viem'
import { config, getContractAddresses, LOCAL_CHAIN_ID } from '@/lib/wagmi'
import { erc721Abi, erc20Abi } from '@/contracts'
import { formatLocalTestMintToast, formatWalletSendError } from '@/lib/utils'
import toast from 'react-hot-toast'

const navItems = [
  { path: '/', label: 'My Chambers', icon: FiHome },
  { path: '/deploy', label: 'Deploy Chamber', icon: FiPlus },
  { path: '/docs', label: 'Docs', icon: FiBook },
]

/** Default test mint size for MockERC20 (header “Mint Test ERC20”). */
const TEST_ERC20_MINT_AMOUNT = parseEther('10000')

function isNavActive(itemPath: string, locationPath: string): boolean {
  if (itemPath === '/') return locationPath === '/' || locationPath.startsWith('/chamber')
  return locationPath.startsWith(itemPath)
}

export default function Layout() {
  const location = useLocation()
  const { chainId, address } = useAccount()
  const { writeContractAsync } = useWriteContract()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [minting, setMinting] = useState<'none' | 'nft' | 'erc20'>('none')

  const onLocalRpc = typeof chainId === 'number' && chainId === LOCAL_CHAIN_ID
  const onSepolia = chainId === sepolia.id
  const canMintTestTokens = onLocalRpc || onSepolia
  const mintTargets = canMintTestTokens ? getContractAddresses(chainId) : undefined
  const mintNftAddr = mintTargets?.mockERC721
  const mintErc20Addr = mintTargets?.mockERC20
  const canShowMintNftBtn =
    canMintTestTokens && !!address && !!mintNftAddr && mintNftAddr !== zeroAddress
  const canShowMintErc20Btn =
    canMintTestTokens && !!address && !!mintErc20Addr && mintErc20Addr !== zeroAddress

  const handleMintTestNft = async () => {
    if (!address || !canMintTestTokens || !mintNftAddr || mintNftAddr === zeroAddress) {
      if (!mintNftAddr || mintNftAddr === zeroAddress) {
        toast.error(
          onSepolia
            ? 'Sepolia demo NFT is missing from deployments/sepolia.txt (MockERC721).'
            : 'Mock ERC-721 address is missing. With Anvil running, run make setup-local in contracts/',
        )
      }
      return
    }

    setMinting('nft')
    try {
      const { request } = await simulateContract(config, {
        address: mintNftAddr,
        abi: erc721Abi,
        functionName: 'mint',
        args: [address],
        chainId,
        account: address,
      })
      await writeContractAsync(request)
      toast.success('Test member token minted successfully!')
    } catch (e: unknown) {
      toast.error(
        onLocalRpc ? formatLocalTestMintToast(e) : formatWalletSendError(e, 'Mint failed'),
      )
    } finally {
      setMinting('none')
    }
  }

  const handleMintTestErc20 = async () => {
    if (!address || !canMintTestTokens || !mintErc20Addr || mintErc20Addr === zeroAddress) {
      if (!mintErc20Addr || mintErc20Addr === zeroAddress) {
        toast.error(
          onSepolia
            ? 'Sepolia demo ERC-20 is missing from deployments/sepolia.txt (MockERC20).'
            : 'Mock ERC-20 address is missing. With Anvil running, run make setup-local in contracts/',
        )
      }
      return
    }

    setMinting('erc20')
    try {
      const { request } = await simulateContract(config, {
        address: mintErc20Addr,
        abi: erc20Abi,
        functionName: 'mint',
        args: [address, TEST_ERC20_MINT_AMOUNT],
        chainId,
        account: address,
      })
      await writeContractAsync(request)
      toast.success('Test ERC-20 tokens minted to your wallet!')
    } catch (e: unknown) {
      toast.error(
        onLocalRpc ? formatLocalTestMintToast(e) : formatWalletSendError(e, 'Mint failed'),
      )
    } finally {
      setMinting('none')
    }
  }

  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="sticky top-0 z-50 border-b border-slate-800/90 bg-[#0b0f17]/85 backdrop-blur-xl supports-[backdrop-filter]:bg-[#0b0f17]/75">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            {/* Logo */}
            <Link to="/" className="flex items-center gap-3 group">
              <img src="https://cdn.loreum.org/logos/white.svg" alt="Chamber Logo" className="w-10 h-10 object-contain transition-all" />
            </Link>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center gap-1">
              {navItems.map((item) => {
                const isActive = isNavActive(item.path, location.pathname)
                const Icon = item.icon
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`relative px-4 py-2 rounded-xl flex items-center gap-2 transition-all text-sm font-medium ${
                      isActive
                        ? 'text-accent-400'
                        : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{item.label}</span>
                    {isActive && (
                      <motion.div
                        layoutId="nav-indicator"
                        className="absolute inset-0 border border-accent-500/30 rounded-xl bg-accent-500/5"
                        transition={{ type: 'spring', bounce: 0.2, duration: 0.6 }}
                      />
                    )}
                  </Link>
                )
              })}
            </nav>

            {/* Right side actions */}
            <div className="flex items-center gap-2">
              <div className="hidden md:flex items-center gap-2">
                {canShowMintErc20Btn && (
                  <button
                    type="button"
                    onClick={handleMintTestErc20}
                    disabled={minting !== 'none'}
                    className="text-xs px-3 py-1.5 bg-accent-500/10 text-accent-400 rounded-lg border border-accent-500/20 hover:bg-accent-500/20 transition-colors whitespace-nowrap disabled:opacity-50"
                  >
                    {minting === 'erc20' ? 'Minting...' : 'Mint Test ERC20'}
                  </button>
                )}
                {canShowMintNftBtn && (
                  <button
                    type="button"
                    onClick={handleMintTestNft}
                    disabled={minting !== 'none'}
                    className="text-xs px-3 py-1.5 bg-accent-500/10 text-accent-400 rounded-lg border border-accent-500/20 hover:bg-accent-500/20 transition-colors whitespace-nowrap disabled:opacity-50"
                  >
                    {minting === 'nft' ? 'Minting...' : 'Mint Test NFT'}
                  </button>
                )}
              </div>
              <ConnectButton accountStatus="address" chainStatus="icon" showBalance={false} />
              <button
                type="button"
                onClick={() => setMobileMenuOpen((o) => !o)}
                className="md:hidden p-2 rounded-lg text-slate-400 hover:text-slate-100 hover:bg-slate-800/60 transition-all"
                aria-label="Toggle menu"
              >
                {mobileMenuOpen ? <FiX className="w-5 h-5" /> : <FiMenu className="w-5 h-5" />}
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Mobile Menu Drawer */}
      <AnimatePresence>
        {mobileMenuOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-40 bg-black/60 md:hidden"
              onClick={() => setMobileMenuOpen(false)}
            />
            {/* Drawer */}
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', bounce: 0, duration: 0.28 }}
              className="fixed right-0 top-0 bottom-0 z-50 w-72 bg-[#0d1320] border-l border-slate-800 flex flex-col md:hidden"
            >
              <div className="flex items-center justify-between p-4 border-b border-slate-800">
                <img src="https://cdn.loreum.org/logos/white.svg" alt="" className="w-8 h-8 object-contain" />
                <button
                  onClick={() => setMobileMenuOpen(false)}
                  className="p-2 rounded-lg text-slate-400 hover:text-slate-100 hover:bg-slate-800 transition-all"
                >
                  <FiX className="w-5 h-5" />
                </button>
              </div>

              <nav className="flex-1 p-4 space-y-1">
                {navItems.map((item) => {
                  const isActive = isNavActive(item.path, location.pathname)
                  const Icon = item.icon
                  return (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setMobileMenuOpen(false)}
                      className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                        isActive
                          ? 'bg-accent-500/10 text-accent-400 border border-accent-500/25'
                          : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/60'
                      }`}
                    >
                      <Icon className="w-4 h-4" />
                      {item.label}
                    </Link>
                  )
                })}

                {canShowMintErc20Btn && (
                  <button
                    type="button"
                    onClick={() => {
                      void handleMintTestErc20()
                      setMobileMenuOpen(false)
                    }}
                    disabled={minting !== 'none'}
                    className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-accent-400 hover:bg-accent-500/10 transition-all disabled:opacity-50"
                  >
                    <FiPlus className="w-4 h-4" />
                    {minting === 'erc20' ? 'Minting...' : 'Mint Test ERC20'}
                  </button>
                )}
                {canShowMintNftBtn && (
                  <button
                    type="button"
                    onClick={() => {
                      void handleMintTestNft()
                      setMobileMenuOpen(false)
                    }}
                    disabled={minting !== 'none'}
                    className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-accent-400 hover:bg-accent-500/10 transition-all disabled:opacity-50"
                  >
                    <FiPlus className="w-4 h-4" />
                    {minting === 'nft' ? 'Minting...' : 'Mint Test NFT'}
                  </button>
                )}
              </nav>

              <div className="p-4 border-t border-slate-800 text-xs text-slate-600">
                Chamber · Decentralized Governance
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Outlet />
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/90 bg-[#080b11]/90 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3 text-slate-500 text-sm">
              <img src="https://cdn.loreum.org/logos/white.svg" alt="Chamber Logo" className="w-6 h-6 object-contain opacity-80" />
              <span className="font-medium">Chamber</span>
              <span className="text-slate-700">|</span>
              <span>Decentralized Governance</span>
            </div>
            <div className="flex items-center gap-6 text-slate-500 text-sm">
              <a
                href="https://github.com/loreum-org/chamber"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 hover:text-accent-400 transition-colors"
              >
                <FiGithub className="w-4 h-4" />
                GitHub
              </a>
              <Link to="/docs" className="flex items-center gap-2 hover:text-accent-400 transition-colors">
                <FiBook className="w-4 h-4" />
                Docs
              </Link>
            </div>
          </div>
          <p className="mt-4 max-w-4xl text-xs leading-relaxed text-slate-600">
            Chamber is non-custodial governance software. It is not legal, tax, investment, broker, dealer, exchange, or custodial advice.
            Regulatory treatment depends on facts, jurisdiction, and final agency rules.
          </p>
        </div>
      </footer>
    </div>
  )
}
