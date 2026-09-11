/**
 * Offline checks for chamber-route wrong-network vs “Not a Chamber”.
 * Run: npx tsx --tsconfig tsconfig.json scripts/verify-chamber-route-gate.ts
 */
import assert from 'node:assert/strict'
import { classifyChamberRoute } from '../src/lib/chamberRoute.ts'

function testUnconfiguredIsWrongNetwork() {
  const decision = classifyChamberRoute({
    hasAddress: true,
    currentChainId: 1,
    configValid: false,
    supportedChainIds: [11_155_111],
    isChamber: false,
    foundOnOtherChainId: null,
  })
  assert.equal(decision.status, 'wrong-network')
  if (decision.status !== 'wrong-network') return
  assert.equal(decision.reason, 'unconfigured')
  assert.equal(decision.targetChainId, 11_155_111)
}

function testChamberOnOtherConfiguredChain() {
  const decision = classifyChamberRoute({
    hasAddress: true,
    currentChainId: 1,
    configValid: true,
    supportedChainIds: [1, 11_155_111],
    isChamber: false,
    foundOnOtherChainId: 11_155_111,
  })
  assert.equal(decision.status, 'wrong-network')
  if (decision.status !== 'wrong-network') return
  assert.equal(decision.reason, 'chamber-on-other-chain')
  assert.equal(decision.targetChainId, 11_155_111)
}

function testGenuineNotAChamber() {
  const decision = classifyChamberRoute({
    hasAddress: true,
    currentChainId: 11_155_111,
    configValid: true,
    supportedChainIds: [11_155_111],
    isChamber: false,
    foundOnOtherChainId: null,
  })
  assert.equal(decision.status, 'not-chamber')
}

function testReadyAndLoading() {
  assert.equal(
    classifyChamberRoute({
      hasAddress: true,
      currentChainId: 11_155_111,
      configValid: true,
      supportedChainIds: [11_155_111],
      isChamber: true,
      foundOnOtherChainId: null,
    }).status,
    'ready',
  )
  assert.equal(
    classifyChamberRoute({
      hasAddress: true,
      currentChainId: 11_155_111,
      configValid: true,
      supportedChainIds: [11_155_111],
      isChamber: undefined,
      foundOnOtherChainId: undefined,
    }).status,
    'loading',
  )
  assert.equal(
    classifyChamberRoute({
      hasAddress: true,
      currentChainId: 1,
      configValid: true,
      supportedChainIds: [1, 11_155_111],
      isChamber: false,
      foundOnOtherChainId: undefined,
    }).status,
    'loading',
  )
}

function testPrefersSepoliaWhenSeveralConfigured() {
  const decision = classifyChamberRoute({
    hasAddress: true,
    currentChainId: 8453,
    configValid: false,
    supportedChainIds: [11_155_111, 31337],
    isChamber: undefined,
    foundOnOtherChainId: undefined,
  })
  assert.equal(decision.status, 'wrong-network')
  if (decision.status !== 'wrong-network') return
  assert.equal(decision.targetChainId, 11_155_111)
}

function testInvalidAddress() {
  assert.equal(
    classifyChamberRoute({
      hasAddress: false,
      currentChainId: 11_155_111,
      configValid: true,
      supportedChainIds: [11_155_111],
      isChamber: undefined,
      foundOnOtherChainId: undefined,
    }).status,
    'invalid-address',
  )
}

testUnconfiguredIsWrongNetwork()
testChamberOnOtherConfiguredChain()
testGenuineNotAChamber()
testReadyAndLoading()
testPrefersSepoliaWhenSeveralConfigured()
testInvalidAddress()
console.log('verify-chamber-route-gate: ok')
