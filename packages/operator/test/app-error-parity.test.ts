import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import { CHAMBER_ERROR_MESSAGES } from '../src/errors.ts'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..')

async function readApp(rel: string): Promise<string> {
  return readFile(join(ROOT, rel), 'utf8')
}

test('operator error copy stays aligned with the React app', async () => {
  const delegation = await readApp('app/src/components/DelegationManager.tsx')
  const treasury = await readApp('app/src/components/TreasuryOverview.tsx')
  const queue = await readApp('app/src/pages/TransactionQueue.tsx')

  assert.match(delegation, /'NotDirector': 'You are not a director'/)
  assert.match(delegation, /'DirectorNotSeated': 'Your seat is not mature yet'/)
  assert.match(delegation, /'EnforcedPause': 'This chamber is paused'/)
  assert.match(treasury, /'EnforcedPause': 'This chamber is paused'/)
  assert.match(queue, /This transaction has expired/)
  assert.match(queue, /Director seating is not mature yet/)

  assert.equal(CHAMBER_ERROR_MESSAGES.NotDirector, 'You are not a director')
  assert.equal(CHAMBER_ERROR_MESSAGES.DirectorNotSeated, 'Your seat is not mature yet')
  assert.equal(CHAMBER_ERROR_MESSAGES.EnforcedPause, 'This chamber is paused')
  assert.equal(CHAMBER_ERROR_MESSAGES.TransactionExpired, 'This transaction has expired')
})

test('TreasuryOverview disconnected empty-state matches Delegation ConnectButton pattern', async () => {
  const treasury = await readApp('app/src/components/TreasuryOverview.tsx')
  const delegation = await readApp('app/src/components/DelegationManager.tsx')

  assert.match(delegation, /if \(!isConnected\)/)
  assert.match(delegation, /ConnectButton/)
  assert.match(treasury, /!isConnected/)
  assert.match(treasury, /ConnectButton/)
  assert.match(treasury, /Connect to deposit assets and withdraw shares/)
  assert.doesNotMatch(treasury, /'Connect Wallet'/)
  assert.match(treasury, /This chamber is paused\. Deposits and withdrawals are halted/)
})
