import { test as base, expect, type Page } from '@playwright/test'
import { bootstrap, getWallet, MetaMaskWallet, type Dappwright } from '@tenkeylabs/dappwright'
import type { BrowserContext } from 'playwright-core'
import { normalizePrivateKey, sepoliaPrivateKey } from './env'

/** Public Hardhat/Anvil mnemonic — used only to finish MetaMask onboarding. */
const BOOTSTRAP_SEED = 'test test test test test test test test test test test junk'

type WorkerFixtures = {
  walletContext: BrowserContext
}

type TestFixtures = {
  wallet: Dappwright
}

async function ensureSepolia(wallet: Dappwright): Promise<void> {
  try {
    await wallet.switchNetwork('Sepolia')
    return
  } catch {
    // Built-in testnet missing or picker flake — add Sepolia explicitly.
  }
  await wallet.addNetwork({
    networkName: 'Sepolia',
    rpc: 'https://rpc.sepolia.org',
    chainId: 11155111,
    symbol: 'ETH',
  })
}

export const test = base.extend<TestFixtures, WorkerFixtures>({
  walletContext: [
    async ({}, use) => {
      const raw = sepoliaPrivateKey()
      if (!raw) {
        throw new Error(
          'E2E_SEPOLIA_PRIVATE_KEY or SEPOLIA_PRIVATE_KEY is required for this fixture. Use npm run test:e2e:sepolia to skip cleanly when unset.',
        )
      }
      const privateKey = normalizePrivateKey(raw)

      const [wallet, , context] = await bootstrap('', {
        wallet: 'metamask',
        version: MetaMaskWallet.recommendedVersion,
        seed: BOOTSTRAP_SEED,
      })

      await wallet.importPK(privateKey)
      await ensureSepolia(wallet)

      await use(context)
      await context.close()
    },
    { scope: 'worker' },
  ],
  context: async ({ walletContext }, use) => {
    await use(walletContext)
  },
  wallet: async ({ walletContext }, use) => {
    const wallet = await getWallet('metamask', walletContext)
    await use(wallet)
  },
})

export { expect }

export async function connectRainbowKitMetaMask(page: Page, wallet: Dappwright): Promise<void> {
  const connect = page.getByTestId('rk-connect-button').or(page.getByRole('button', { name: /connect wallet/i }))
  await expect(connect.first()).toBeVisible()
  await connect.first().click()

  const metamaskOption = page
    .getByTestId('rk-wallet-option-metaMask')
    .or(page.getByTestId('rk-wallet-option-io.metamask'))
    .or(page.getByRole('button', { name: /^metamask$/i }))
    .or(page.getByText('MetaMask', { exact: true }))

  await expect(metamaskOption.first()).toBeVisible()
  await metamaskOption.first().click()

  await wallet.approve()

  const switchOrWrong = page
    .getByTestId('rk-wrong-network-button')
    .or(page.getByRole('button', { name: /wrong network|switch network/i }))
  if (await switchOrWrong.first().isVisible({ timeout: 4_000 }).catch(() => false)) {
    await switchOrWrong.first().click()
    await wallet.confirmNetworkSwitch().catch(() => undefined)
  }
}
