/**
 * Offline checks for Dashboard mainnet-unsupported banner (#233).
 * Run: npx tsx --tsconfig tsconfig.json scripts/verify-mainnet-unsupported-banner.ts
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  getNetworkName,
  pickPreferredSupportedChainId,
  readSimulatedChainId,
  SEPOLIA_CHAIN_ID,
  showMainnetUnsupportedBanner,
  switchToSupportedChainLabel,
} from '../src/lib/supportedChain.ts'

function testBannerVisibility() {
  assert.equal(showMainnetUnsupportedBanner(1, false), true)
  assert.equal(showMainnetUnsupportedBanner(1, true), false)
  assert.equal(showMainnetUnsupportedBanner(SEPOLIA_CHAIN_ID, false), false)
  assert.equal(showMainnetUnsupportedBanner(31337, false), false)
}

function testPrefersSepoliaThenFirstConfigured() {
  assert.equal(pickPreferredSupportedChainId([SEPOLIA_CHAIN_ID, 31337]), SEPOLIA_CHAIN_ID)
  assert.equal(pickPreferredSupportedChainId([31337, SEPOLIA_CHAIN_ID]), SEPOLIA_CHAIN_ID)
  assert.equal(pickPreferredSupportedChainId([8453, 42161]), 8453)
  assert.equal(pickPreferredSupportedChainId([]), undefined)
  // Never invent mainnet as a switch target when it is not in the configured list.
  assert.notEqual(pickPreferredSupportedChainId([SEPOLIA_CHAIN_ID]), 1)
}

function testDevSimulateChainId() {
  assert.equal(readSimulatedChainId('?simulateChainId=1', true), 1)
  assert.equal(readSimulatedChainId('simulateChainId=1', true), 1)
  assert.equal(readSimulatedChainId('?simulateChainId=1', false), undefined)
  assert.equal(readSimulatedChainId('?foo=1', true), undefined)
  assert.equal(showMainnetUnsupportedBanner(readSimulatedChainId('?simulateChainId=1', true) ?? 11155111, false), true)
}

function testSwitchLabel() {
  assert.equal(switchToSupportedChainLabel(SEPOLIA_CHAIN_ID), 'Switch to Sepolia')
  assert.equal(switchToSupportedChainLabel(8453), 'Switch to Base')
  assert.equal(switchToSupportedChainLabel(undefined), 'Switch network')
  assert.equal(getNetworkName(1), 'Mainnet')
}

function testNoInventedMainnetEnv() {
  assert.equal(process.env.VITE_MAINNET_FACTORY ?? '', '')
  assert.equal(process.env.VITE_MAINNET_REGISTRY ?? '', '')
  const here = dirname(fileURLToPath(import.meta.url))
  const sepoliaTxt = readFileSync(join(here, '../../contracts/deployments/sepolia.txt'), 'utf8')
  assert.match(sepoliaTxt, /^\s*Factory\s+0x[a-fA-F0-9]{40}/m)
}

function testDashboardWiresExistingHelpers() {
  const here = dirname(fileURLToPath(import.meta.url))
  const source = readFileSync(join(here, '../src/pages/Dashboard.tsx'), 'utf8')
  assert.match(source, /useSwitchChain/)
  assert.match(source, /useChainModal/)
  assert.match(source, /useConnectModal/)
  assert.match(source, /getPreferredSupportedChainId/)
  assert.match(source, /switchToSupportedChainLabel/)
  assert.match(source, /showMainnetUnsupportedBanner/)
  assert.match(source, /readSimulatedChainId/)
  assert.match(source, /btn btn-primary/)
  assert.doesNotMatch(source, /VITE_MAINNET_FACTORY=0x[0-9a-fA-F]{40}/)
  assert.doesNotMatch(
    source,
    /This deployment does not include[\s\S]*0x[0-9a-fA-F]{40}/,
  )
}

testBannerVisibility()
testPrefersSepoliaThenFirstConfigured()
testDevSimulateChainId()
testSwitchLabel()
testNoInventedMainnetEnv()
testDashboardWiresExistingHelpers()
console.log('verify-mainnet-unsupported-banner: ok')
