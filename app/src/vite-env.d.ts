/// <reference types="vite/client" />

declare module '*.txt?raw' {
  const content: string
  export default content
}

interface ImportMetaEnv {
  readonly VITE_INDEXER_URL?: string
  readonly VITE_INDEXER_CHAIN_ID?: string
  readonly VITE_SEPOLIA_FACTORY_START_BLOCK?: string
  readonly VITE_SEPOLIA_REGISTRY_START_BLOCK?: string
  readonly VITE_MAINNET_FACTORY?: string
  readonly VITE_MAINNET_CHAMBER_IMPL?: string
  readonly VITE_MAINNET_REGISTRY?: string
  readonly VITE_MAINNET_FACTORY_START_BLOCK?: string
  readonly VITE_MAINNET_REGISTRY_START_BLOCK?: string
  readonly VITE_BASE_FACTORY_START_BLOCK?: string
  readonly VITE_BASE_REGISTRY_START_BLOCK?: string
  readonly VITE_ARBITRUM_FACTORY_START_BLOCK?: string
  readonly VITE_ARBITRUM_REGISTRY_START_BLOCK?: string
}
