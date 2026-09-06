import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import { decodeFunctionData, encodeErrorResult, encodeFunctionData } from 'viem'
import { chamberAbi } from '../src/abi.ts'
import { ChamberOperator } from '../src/client.ts'
import { formatChamberError } from '../src/errors.ts'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

function abiNames(kind: 'function' | 'event'): string[] {
  return chamberAbi.flatMap((item) =>
    item.type === kind && 'name' in item ? [item.name] : [],
  )
}

test('ChamberOperator exposes undelegate, revokeConfirmation, and cancelTransaction', () => {
  assert.equal(typeof ChamberOperator.prototype.undelegate, 'function')
  assert.equal(typeof ChamberOperator.prototype.revokeConfirmation, 'function')
  assert.equal(typeof ChamberOperator.prototype.cancelTransaction, 'function')
})

test('generated Chamber ABI exposes undelegate / revoke / cancel', () => {
  const functions = abiNames('function')
  const events = abiNames('event')
  assert.ok(functions.includes('undelegate'))
  assert.ok(functions.includes('revokeConfirmation'))
  assert.ok(functions.includes('cancelTransaction'))
  assert.ok(functions.includes('getCancelled'))
  assert.ok(events.includes('RevokeConfirmation') || events.includes('ConfirmationRevoked'))
  assert.ok(events.includes('TransactionCancelled') || events.includes('CancelTransaction'))
})

test('chamberAbi encodes undelegate, revokeConfirmation, and cancelTransaction', () => {
  const undelegateData = encodeFunctionData({
    abi: chamberAbi,
    functionName: 'undelegate',
    args: [1n, 10n ** 18n],
  })
  const undelegateDecoded = decodeFunctionData({ abi: chamberAbi, data: undelegateData })
  assert.equal(undelegateDecoded.functionName, 'undelegate')
  assert.deepEqual([...undelegateDecoded.args], [1n, 10n ** 18n])

  const revokeData = encodeFunctionData({
    abi: chamberAbi,
    functionName: 'revokeConfirmation',
    args: [2n, 7n],
  })
  const revokeDecoded = decodeFunctionData({ abi: chamberAbi, data: revokeData })
  assert.equal(revokeDecoded.functionName, 'revokeConfirmation')
  assert.deepEqual([...revokeDecoded.args], [2n, 7n])

  const cancelData = encodeFunctionData({
    abi: chamberAbi,
    functionName: 'cancelTransaction',
    args: [1n, 7n],
  })
  const cancelDecoded = decodeFunctionData({ abi: chamberAbi, data: cancelData })
  assert.equal(cancelDecoded.functionName, 'cancelTransaction')
  assert.deepEqual([...cancelDecoded.args], [1n, 7n])
})

test('undelegate / revoke / cancel writes decode the same app-mapped errors', () => {
  const insufficient = encodeErrorResult({ abi: chamberAbi, errorName: 'InsufficientDelegatedAmount' })
  assert.equal(
    formatChamberError({
      message: 'The contract function "undelegate" reverted.',
      data: insufficient,
    }),
    "You haven't delegated this much to this member",
  )

  const notDirector = encodeErrorResult({ abi: chamberAbi, errorName: 'NotDirector' })
  assert.equal(
    formatChamberError({
      message: 'The contract function "cancelTransaction" reverted.',
      data: notDirector,
    }),
    'You are not a director',
  )

  const expired = encodeErrorResult({ abi: chamberAbi, errorName: 'TransactionExpired' })
  assert.equal(
    formatChamberError({
      message: 'The contract function "revokeConfirmation" reverted.',
      data: expired,
    }),
    'This transaction has expired',
  )
})

test('CLI documents undelegate / revoke / cancel in the existing style', async () => {
  const cli = await readFile(join(ROOT, 'src/cli.ts'), 'utf8')
  assert.match(cli, /undelegate\s+Undelegate vault shares from a membership tokenId/)
  assert.match(cli, /revoke\s+revokeConfirmation \(director\)/)
  assert.match(cli, /cancel\s+cancelTransaction \(director\)/)
  assert.match(cli, /case 'undelegate':/)
  assert.match(cli, /case 'revoke':/)
  assert.match(cli, /case 'cancel':/)
  assert.match(cli, /operator\.undelegate/)
  assert.match(cli, /operator\.revokeConfirmation/)
  assert.match(cli, /operator\.cancelTransaction/)
})

test('README documents undelegate, revokeConfirmation, and cancelTransaction', async () => {
  const readme = await readFile(join(ROOT, 'README.md'), 'utf8')
  assert.match(readme, /`undelegate`/)
  assert.match(readme, /`revokeConfirmation`/)
  assert.match(readme, /`cancelTransaction`/)
  assert.match(readme, /chamber-operator undelegate/)
  assert.match(readme, /chamber-operator revoke/)
  assert.match(readme, /chamber-operator cancel/)
  assert.match(readme, /op\.undelegate/)
  assert.match(readme, /op\.revokeConfirmation/)
  assert.match(readme, /op\.cancelTransaction/)
})
