import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { fallback, http } from 'wagmi'
import { mainnet, sepolia, base, arbitrum, Chain } from 'wagmi/chains'
import localDeployments from '@/contracts/deployments.json'
import { alchemySupportsChain, getAlchemyApiKeyFromEnv, getAlchemyV2RpcUrl } from '@/lib/alchemy'
import { ZERO_ADDRESS, isNonZeroAddress } from '@/lib/address'
import { sepoliaDeploymentAddresses } from '@/lib/sepoliaDeployments'
import { getNetworkName as networkNameFromId, pickPreferredSupportedChainId } from '@/lib/supportedChain'

export { pickPreferredSupportedChainId } from '@/lib/supportedChain'

export { isNonZeroAddress, ZERO_ADDRESS }

const productionApp = import.meta.env.PROD

function envAddress(raw: string | undefined): string {
  return raw?.trim() ?? ''
}

function isConfiguredAddress(raw: string): boolean {
  return raw !== '' && raw.toLowerCase() !== ZERO_ADDRESS
}

/** Mainnet is offered when `VITE_MAINNET_FACTORY` or `VITE_MAINNET_REGISTRY` is set. */
const mainnetFactoryRaw = envAddress(import.meta.env.VITE_MAINNET_FACTORY)
const mainnetRegistryRaw = envAddress(import.meta.env.VITE_MAINNET_REGISTRY)
export const isMainnetConfigured =
  isConfiguredAddress(mainnetFactoryRaw) || isConfiguredAddress(mainnetRegistryRaw)

// Use the chain ID from deployments.json so that localhost accurately matches Anvil forks (dev only)
export const LOCAL_CHAIN_ID = localDeployments.chainId || 31337

const alchemyApiKey = getAlchemyApiKeyFromEnv()

/** Public RPC fallbacks when `VITE_ALCHEMY_API_KEY` is unset or rate-limited (CSP allowlisted). */
const PUBLIC_RPC: Record<number, string> = {
  [mainnet.id]: 'https://eth.llamarpc.com',
  [sepolia.id]: 'https://sepolia.drpc.org',
  [base.id]: 'https://mainnet.base.org',
  [arbitrum.id]: 'https://arb1.arbitrum.io/rpc',
}

function chainTransport(chainId: number, publicUrl: string) {
  if (alchemyApiKey && alchemySupportsChain(chainId)) {
    const alchemyUrl = getAlchemyV2RpcUrl(chainId, alchemyApiKey)
    if (alchemyUrl) {
      // Alchemy returns plain-text 429 bodies when quota is exceeded; fall back to public RPC.
      return fallback([http(alchemyUrl), http(publicUrl)])
    }
  }
  return http(publicUrl)
}

// Define localhost chain explicitly with correct chain ID (not offered in production builds)
const localhost: Chain = {
  id: LOCAL_CHAIN_ID,
  name: LOCAL_CHAIN_ID === 11155111 ? 'Local Sepolia Fork' : 'Localhost',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
  },
}

// Get WalletConnect project ID from environment variable
// For local development, you can use a placeholder or get a free project ID from cloud.walletconnect.com
const walletConnectProjectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || ''

if (!walletConnectProjectId) {
  if (import.meta.env.PROD) {
    throw new Error(
      'VITE_WALLETCONNECT_PROJECT_ID is required in production. ' +
      'Get a free project ID at https://cloud.walletconnect.com'
    )
  } else {
    console.warn(
      '⚠️ WalletConnect Project ID not configured. Wallet connections may not work properly.\n' +
      'Get a free project ID at https://cloud.walletconnect.com and add it to your .env file:\n' +
      'VITE_WALLETCONNECT_PROJECT_ID=your_project_id'
    )
  }
}

if (import.meta.env.DEV && alchemyApiKey) {
  console.info('[wagmi] Alchemy RPC enabled for Ethereum, Sepolia, Base, Arbitrum, and local RPC')
}

/** Production: Sepolia, plus Mainnet when factory or registry env is set. Dev adds Base, Arbitrum, local. */
export const config = productionApp
  ? isMainnetConfigured
    ? getDefaultConfig({
        appName: 'Chamber',
        projectId: walletConnectProjectId,
        chains: [mainnet, sepolia],
        ssr: false,
        transports: {
          [mainnet.id]: chainTransport(mainnet.id, PUBLIC_RPC[mainnet.id]),
          [sepolia.id]: chainTransport(sepolia.id, PUBLIC_RPC[sepolia.id]),
        },
      })
    : getDefaultConfig({
        appName: 'Chamber',
        projectId: walletConnectProjectId,
        chains: [sepolia],
        ssr: false,
        transports: {
          [sepolia.id]: chainTransport(sepolia.id, PUBLIC_RPC[sepolia.id]),
        },
      })
  : isMainnetConfigured
    ? getDefaultConfig({
        appName: 'Chamber',
        projectId: walletConnectProjectId,
        chains: [mainnet, sepolia, base, arbitrum, localhost],
        ssr: false,
        transports: {
          [mainnet.id]: chainTransport(mainnet.id, PUBLIC_RPC[mainnet.id]),
          [sepolia.id]: chainTransport(sepolia.id, PUBLIC_RPC[sepolia.id]),
          [base.id]: chainTransport(base.id, PUBLIC_RPC[base.id]),
          [arbitrum.id]: chainTransport(arbitrum.id, PUBLIC_RPC[arbitrum.id]),
          [localhost.id]: http(localhost.rpcUrls.default.http[0]),
        },
      })
    : getDefaultConfig({
        appName: 'Chamber',
        projectId: walletConnectProjectId,
        chains: [sepolia, base, arbitrum, localhost],
        ssr: false,
        transports: {
          [sepolia.id]: chainTransport(sepolia.id, PUBLIC_RPC[sepolia.id]),
          [base.id]: chainTransport(base.id, PUBLIC_RPC[base.id]),
          [arbitrum.id]: chainTransport(arbitrum.id, PUBLIC_RPC[arbitrum.id]),
          [localhost.id]: http(localhost.rpcUrls.default.http[0]),
        },
      })

// Sepolia Factory path — 26 Aug 2026 (`contracts/deployments/sepolia.txt`).
// Env still wins when set (`VITE_SEPOLIA_FACTORY`, `VITE_SEPOLIA_CHAMBER_IMPL`).
export const SEPOLIA_FACTORY = '0x43aA92c8A26392f21F63cdA88B6BaB5031C40550' as `0x${string}`
export const SEPOLIA_CHAMBER_IMPLEMENTATION =
  '0xd441f1FDad2d3a447d2621DE4DE8b5738e02d39c' as `0x${string}`

// Contract addresses - localhost uses auto-generated deployments.json from `make deploy-anvil-all`
// Sepolia reads committed `contracts/deployments/sepolia.txt`; env vars override.
function addressFromEnv(...candidates: (string | undefined)[]): `0x${string}` {
  for (const raw of candidates) {
    const value = envAddress(raw)
    if (isConfiguredAddress(value)) return value as `0x${string}`
  }
  return ZERO_ADDRESS
}

export const CONTRACT_ADDRESSES = {
  // Sepolia testnet — committed defaults from sepolia.txt, env overrides
  sepolia: {
    registry: addressFromEnv(import.meta.env.VITE_SEPOLIA_REGISTRY, sepoliaDeploymentAddresses.registry),
    factory: addressFromEnv(
      import.meta.env.VITE_SEPOLIA_FACTORY,
      sepoliaDeploymentAddresses.factory,
      SEPOLIA_FACTORY,
    ),
    chamberImplementation: addressFromEnv(
      import.meta.env.VITE_SEPOLIA_CHAMBER_IMPL,
      sepoliaDeploymentAddresses.chamberImplementation,
      SEPOLIA_CHAMBER_IMPLEMENTATION,
    ),
    mockERC20: addressFromEnv(import.meta.env.VITE_SEPOLIA_MOCK_ERC20, sepoliaDeploymentAddresses.mockERC20),
    mockERC721: addressFromEnv(import.meta.env.VITE_SEPOLIA_MOCK_ERC721, sepoliaDeploymentAddresses.mockERC721),
  },
  mainnet: {
    registry: addressFromEnv(import.meta.env.VITE_MAINNET_REGISTRY),
    factory: addressFromEnv(import.meta.env.VITE_MAINNET_FACTORY),
    chamberImplementation: addressFromEnv(import.meta.env.VITE_MAINNET_CHAMBER_IMPL),
    mockERC20: ZERO_ADDRESS as `0x${string}`,
    mockERC721: ZERO_ADDRESS as `0x${string}`,
  },
  base: {
    registry: addressFromEnv(import.meta.env.VITE_BASE_REGISTRY),
    factory: addressFromEnv(import.meta.env.VITE_BASE_FACTORY),
    chamberImplementation: addressFromEnv(import.meta.env.VITE_BASE_CHAMBER_IMPL),
    mockERC20: ZERO_ADDRESS as `0x${string}`,
    mockERC721: ZERO_ADDRESS as `0x${string}`,
  },
  arbitrum: {
    registry: addressFromEnv(import.meta.env.VITE_ARBITRUM_REGISTRY),
    factory: addressFromEnv(import.meta.env.VITE_ARBITRUM_FACTORY),
    chamberImplementation: addressFromEnv(import.meta.env.VITE_ARBITRUM_CHAMBER_IMPL),
    mockERC20: ZERO_ADDRESS as `0x${string}`,
    mockERC721: ZERO_ADDRESS as `0x${string}`,
  },
  // Localhost - auto-populated from deployments.json via `make deploy-anvil-all`
  localhost: {
    registry: addressFromEnv(localDeployments.registry, import.meta.env.VITE_LOCALHOST_REGISTRY),
    factory: addressFromEnv(
      (localDeployments as { factory?: string }).factory,
      import.meta.env.VITE_LOCALHOST_FACTORY,
    ),
    chamberImplementation: addressFromEnv(localDeployments.chamberImplementation),
    mockERC20: addressFromEnv(localDeployments.mockERC20),
    mockERC721: addressFromEnv(localDeployments.mockERC721),
  },
} as const

// Export localhost deployment info for convenience
export const localhostDeployment = {
  ...localDeployments,
  registry: CONTRACT_ADDRESSES.localhost.registry,
  factory: CONTRACT_ADDRESSES.localhost.factory,
  chamberImplementation: CONTRACT_ADDRESSES.localhost.chamberImplementation,
  mockERC20: CONTRACT_ADDRESSES.localhost.mockERC20,
  mockERC721: CONTRACT_ADDRESSES.localhost.mockERC721,
}

export function getContractAddresses(chainId: number) {
  // If the active chain matches the local deployments chain, prioritize local addresses
  // This allows overriding Sepolia testnet with local Sepolia fork addresses
  if (chainId === localDeployments.chainId) {
    return CONTRACT_ADDRESSES.localhost
  }

  switch (chainId) {
    case 1:
      return CONTRACT_ADDRESSES.mainnet
    case 11155111:
      return CONTRACT_ADDRESSES.sepolia
    case 8453:
      return CONTRACT_ADDRESSES.base
    case 42161:
      return CONTRACT_ADDRESSES.arbitrum
    case 31337:
      return CONTRACT_ADDRESSES.localhost
    default:
      return null
  }
}

// Helper to check if we have valid addresses configured (factory or registry)
export function hasValidAddresses(chainId: number): boolean {
  const addresses = getContractAddresses(chainId)
  if (!addresses) return false
  return isNonZeroAddress(addresses.factory) || isNonZeroAddress(addresses.registry)
}

/** Display name for wallet/config banners. Matches Dashboard copy. */
export function getNetworkName(chainId: number): string {
  return networkNameFromId(chainId, config.chains.find((chain) => chain.id === chainId)?.name)
}

/** RainbowKit/wagmi chains that already have a Factory or Registry address. */
export function getConfiguredChainIds(): number[] {
  const seen = new Set<number>()
  const ids: number[] = []
  for (const chain of config.chains) {
    if (seen.has(chain.id) || !hasValidAddresses(chain.id)) continue
    seen.add(chain.id)
    ids.push(chain.id)
  }
  return ids
}

/**
 * Prefer Sepolia when it has a Factory or Registry, otherwise the first wagmi
 * chain that does. Does not invent addresses — only reads configured maps.
 */
export function getPreferredSupportedChainId(): number | undefined {
  return pickPreferredSupportedChainId(getConfiguredChainIds())
}
