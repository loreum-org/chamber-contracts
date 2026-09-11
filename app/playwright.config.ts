import { defineConfig } from '@playwright/test'

const baseURL = process.env.PLAYWRIGHT_BASE_URL?.trim() || 'https://app.loreum.org'
const hasSepoliaKey = Boolean(
  (process.env.E2E_SEPOLIA_PRIVATE_KEY || process.env.SEPOLIA_PRIVATE_KEY || '').trim(),
)

/**
 * Wallet smoke uses Dappwright’s Chromium + MetaMask extension, not Playwright’s
 * default browser. Config here is timeouts, base URL, and a single worker.
 */
export default defineConfig({
  testDir: './e2e',
  testIgnore: hasSepoliaKey ? [] : /sepolia\.smoke\.spec\.ts/,
  passWithNoTests: true,
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 180_000,
  expect: { timeout: 30_000 },
  forbidOnly: !!process.env.CI,
  reporter: 'list',
  use: {
    baseURL,
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
})
