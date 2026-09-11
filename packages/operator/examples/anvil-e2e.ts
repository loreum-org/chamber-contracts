/**
 * One-shot Anvil walkthrough of the operator surface.
 *
 * Prerequisites: `anvil` and `forge` on PATH (Foundry).
 * From `packages/operator`: `npm run example:anvil`
 *
 * Spawns a fresh Anvil, deploys Registry/Factory/mocks, creates a 3-seat
 * chamber, then exercises board/quorum/delegate/undelegate/submit/confirm/
 * revoke/cancel/execute and the four app-mapped failure strings.
 */
import { spawn, type ChildProcess } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  type Address,
  type Hex,
  createPublicClient,
  createWalletClient,
  decodeEventLog,
  encodeFunctionData,
  http,
  parseEther,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { chamberAbi, factoryAbi, mockERC20Abi, mockERC721Abi } from '../src/abi.ts'
import { createOperator } from '../src/client.ts'
import { CHAMBER_ERROR_MESSAGES, formatChamberError } from '../src/errors.ts'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..')
const CONTRACTS = join(ROOT, 'contracts')
const RPC = process.env.CHAMBER_RPC ?? 'http://127.0.0.1:8545'
const ANVIL_KEY0 = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const
const ANVIL_KEY1 = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d' as const
const ANVIL_KEY2 = '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a' as const

type Deployments = {
  factory: Address
  mockERC20: Address
  mockERC721: Address
}

function log(step: string, extra?: unknown): void {
  if (extra === undefined) {
    console.log(`\n==> ${step}`)
    return
  }
  console.log(`\n==> ${step}`)
  console.log(typeof extra === 'string' ? extra : JSON.stringify(extra, (_k, v) => (typeof v === 'bigint' ? v.toString() : v), 2))
}

async function waitForRpc(url: string, timeoutMs = 20_000): Promise<void> {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    try {
      const client = createPublicClient({ transport: http(url) })
      await client.getBlockNumber()
      return
    } catch {
      await new Promise((r) => setTimeout(r, 200))
    }
  }
  throw new Error(`RPC ${url} did not become ready`)
}

async function rpcReady(url: string): Promise<boolean> {
  try {
    const client = createPublicClient({ transport: http(url) })
    await client.getBlockNumber()
    return true
  } catch {
    return false
  }
}

async function startAnvil(): Promise<ChildProcess | undefined> {
  if (await rpcReady(RPC)) {
    log('Using existing Anvil', RPC)
    return undefined
  }
  log('Starting Anvil')
  const child = spawn(
    'anvil',
    ['--chain-id', '31337', '-m', 'test test test test test test test test test test test junk'],
    { stdio: ['ignore', 'pipe', 'pipe'] },
  )
  child.stderr?.on('data', (buf: Buffer) => {
    const text = buf.toString()
    if (text.toLowerCase().includes('error')) process.stderr.write(text)
  })
  await waitForRpc(RPC)
  return child
}

function run(cmd: string, args: string[], cwd: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { cwd, stdio: 'inherit' })
    child.on('exit', (code) => {
      if (code === 0) resolve()
      else reject(new Error(`${cmd} ${args.join(' ')} exited ${code}`))
    })
  })
}

async function readDeployments(): Promise<Deployments> {
  const raw = JSON.parse(await readFile(join(CONTRACTS, 'deployments.json'), 'utf8')) as {
    factory?: string
    mockERC20?: string
    mockERC721?: string
  }
  if (!raw.factory || !raw.mockERC20 || !raw.mockERC721) {
    throw new Error('contracts/deployments.json missing factory/mockERC20/mockERC721 — run make setup-local')
  }
  return {
    factory: raw.factory as Address,
    mockERC20: raw.mockERC20 as Address,
    mockERC721: raw.mockERC721 as Address,
  }
}

async function rpc(method: string, params: unknown[] = []): Promise<unknown> {
  const res = await fetch(RPC, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
  })
  const json = (await res.json()) as { result?: unknown; error?: { message?: string } }
  if (json.error?.message) throw new Error(`${method}: ${json.error.message}`)
  return json.result
}

async function mine(blocks = 1): Promise<void> {
  await rpc('anvil_mine', [`0x${blocks.toString(16)}`])
}

async function increaseTime(seconds: number): Promise<void> {
  await rpc('evm_increaseTime', [seconds])
  await mine(1)
}

async function expectMessage(label: string, expected: string, fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn()
    throw new Error(`${label}: expected failure "${expected}" but call succeeded`)
  } catch (error) {
    const message = formatChamberError(error)
    if (message !== expected) {
      throw new Error(`${label}: expected "${expected}", got "${message}"`)
    }
    log(`${label} → ${message}`)
  }
}

async function main(): Promise<void> {
  const spawned = await startAnvil()
  try {
    log('Deploy Registry, Factory, mocks')
    await run(
      'forge',
      [
        'script',
        'script/DeployAllAnvil.s.sol:DeployAllAnvil',
        '--rpc-url',
        RPC,
        '--private-key',
        ANVIL_KEY0,
        '--broadcast',
        '--slow',
      ],
      CONTRACTS,
    )

    const deployments = await readDeployments()
    const publicClient = createPublicClient({ transport: http(RPC) })
    const admin = privateKeyToAccount(ANVIL_KEY0)
    const directorB = privateKeyToAccount(ANVIL_KEY1)
    const outsider = privateKeyToAccount(ANVIL_KEY2)
    const wallet = createWalletClient({ account: admin, transport: http(RPC) })

    const createHash = await wallet.writeContract({
      address: deployments.factory,
      abi: factoryAbi,
      functionName: 'createChamber',
      args: [deployments.mockERC20, deployments.mockERC721, 3n, 'Operator Demo', 'OPDEMO'],
      account: admin,
      chain: null,
    })
    const createReceipt = await publicClient.waitForTransactionReceipt({ hash: createHash })
    let chamber: Address | undefined
    for (const logItem of createReceipt.logs) {
      try {
        const decoded = decodeEventLog({
          abi: factoryAbi,
          data: logItem.data,
          topics: logItem.topics,
        })
        if (decoded.eventName === 'ChamberCreated') {
          chamber = (decoded.args as { chamber: Address }).chamber
        }
      } catch {
        // skip
      }
    }
    if (!chamber) throw new Error('ChamberCreated not found')
    log('Chamber', chamber)

    await wallet.writeContract({
      address: deployments.mockERC721,
      abi: mockERC721Abi,
      functionName: 'mintWithTokenId',
      args: [admin.address, 1n],
      account: admin,
      chain: null,
    })
    await wallet.writeContract({
      address: deployments.mockERC721,
      abi: mockERC721Abi,
      functionName: 'mintWithTokenId',
      args: [directorB.address, 2n],
      account: admin,
      chain: null,
    })

    const deposit = parseEther('1000')
    for (const to of [admin.address, directorB.address] as const) {
      await wallet.writeContract({
        address: deployments.mockERC20,
        abi: mockERC20Abi,
        functionName: 'mint',
        args: [to, deposit],
        account: admin,
        chain: null,
      })
    }

    const opA = await createOperator({
      rpcUrl: RPC,
      chamber,
      signer: { type: 'privateKey', privateKey: ANVIL_KEY0 },
    })
    const opB = await createOperator({
      rpcUrl: RPC,
      chamber,
      signer: { type: 'privateKey', privateKey: ANVIL_KEY1 },
    })
    const opOutsider = await createOperator({
      rpcUrl: RPC,
      chamber,
      signer: { type: 'privateKey', privateKey: ANVIL_KEY2 },
    })

    const asset = await publicClient.readContract({
      address: chamber,
      abi: chamberAbi,
      functionName: 'asset',
    })
    for (const [key, who] of [
      [ANVIL_KEY0, admin.address],
      [ANVIL_KEY1, directorB.address],
    ] as const) {
      const account = privateKeyToAccount(key)
      const w = createWalletClient({ account, transport: http(RPC) })
      await w.writeContract({
        address: asset,
        abi: mockERC20Abi,
        functionName: 'approve',
        args: [chamber, deposit],
        account,
        chain: null,
      })
      await w.writeContract({
        address: chamber,
        abi: chamberAbi,
        functionName: 'deposit',
        args: [deposit, who],
        account,
        chain: null,
      })
    }

    log('delegate (both directors)')
    await opA.delegate(1n, deposit)
    await opB.delegate(2n, deposit)

    log('board immediately after delegate (seating pending)')
    const pendingBoard = await opA.getBoard()
    log('board', pendingBoard)
    log('quorum', { quorum: (await opA.getQuorum()).toString() })

    const pending = pendingBoard.members.find((m) => !m.seatingMature)
    if (!pending) {
      throw new Error('expected at least one director to still be inside the seating delay')
    }
    const pendingOp = pending.tokenId === 2n ? opB : opA
    await expectMessage('seating delay on submit', CHAMBER_ERROR_MESSAGES.DirectorNotSeated, () =>
      pendingOp.submitTransaction({
        tokenId: pending.tokenId,
        target: outsider.address,
        value: 0n,
        data: '0x',
      }),
    )

    log('mine until seating is mature (SEATING_DELAY = 1)')
    for (let i = 0; i < 4; i++) {
      const board = await opA.getBoard()
      if (board.members.every((m) => m.seatingMature)) break
      await mine(1)
    }
    const readyBoard = await opA.getBoard()
    if (!readyBoard.members.every((m) => m.seatingMature)) {
      throw new Error('expected seating to be mature after mining')
    }
    log('board after seating', readyBoard)

    const queued = await opA.submitTransaction({
      tokenId: 1n,
      target: outsider.address,
      value: 0n,
      data: '0x',
    })
    log('submitTransaction (revoke/cancel path)', { nonce: queued.nonce.toString(), hash: queued.hash })

    const firstConfirm = await opB.confirm(2n, queued.nonce)
    log('confirm', { hash: firstConfirm.hash })
    const afterConfirm = await opA.getTransaction(queued.nonce)
    if (afterConfirm.confirmations < 1) {
      throw new Error('expected at least one confirmation before revoke')
    }

    const revoked = await opB.revokeConfirmation(2n, queued.nonce)
    log('revokeConfirmation', { hash: revoked.hash })
    const afterRevoke = await opA.getTransaction(queued.nonce)
    if (afterRevoke.confirmations !== afterConfirm.confirmations - 1) {
      throw new Error(
        `expected confirmations to drop after revoke (${afterConfirm.confirmations} → ${afterRevoke.confirmations})`,
      )
    }

    const cancelA = await opA.cancelTransaction(1n, queued.nonce)
    log('cancelTransaction (vote 1)', { hash: cancelA.hash })
    const cancelB = await opB.cancelTransaction(2n, queued.nonce)
    log('cancelTransaction (vote 2 / quorum)', { hash: cancelB.hash })
    const afterCancel = await opA.getTransaction(queued.nonce)
    if (!afterCancel.cancelled) {
      throw new Error('expected getCancelled / tx.cancelled after quorum cancel votes')
    }
    log('tx after cancel', afterCancel)

    const submitted = await opA.submitTransaction({
      tokenId: 1n,
      target: outsider.address,
      value: 0n,
      data: '0x',
    })
    log('submitTransaction', { nonce: submitted.nonce.toString(), hash: submitted.hash })

    await expectMessage('not-a-director on confirm', CHAMBER_ERROR_MESSAGES.NotDirector, () =>
      opOutsider.confirm(1n, submitted.nonce),
    )

    const confirmed = await opB.confirm(2n, submitted.nonce)
    log('confirm', { hash: confirmed.hash })

    const executed = await opA.execute(1n, submitted.nonce, '0x')
    log('execute', { hash: executed.hash })

    const now = await publicClient.getBlock().then((b) => b.timestamp)
    const expiring = await opA.submitTransaction({
      tokenId: 1n,
      target: outsider.address,
      value: 0n,
      data: '0x',
      deadline: now + 2n,
    })
    log('submit with short deadline', { nonce: expiring.nonce.toString(), deadline: (now + 2n).toString() })
    await increaseTime(5)
    await expectMessage('expired nonce on confirm', CHAMBER_ERROR_MESSAGES.TransactionExpired, () =>
      opB.confirm(2n, expiring.nonce),
    )

    const undelegateAmount = parseEther('1')
    const undelegated = await opA.undelegate(1n, undelegateAmount)
    log('undelegate', { hash: undelegated.hash, amount: undelegateAmount.toString() })

    const pauseData = encodeFunctionData({ abi: chamberAbi, functionName: 'pause' })
    const pauseSubmit = await opA.submitTransaction({
      tokenId: 1n,
      target: chamber,
      value: 0n,
      data: pauseData as Hex,
    })
    await opB.confirm(2n, pauseSubmit.nonce)
    await opA.execute(1n, pauseSubmit.nonce, pauseData)
    log('executed pause()')

    const afterPause = await opA.getBoard()
    if (!afterPause.paused) throw new Error('expected chamber to be paused')

    const pausedTx = await opA.submitTransaction({
      tokenId: 1n,
      target: outsider.address,
      value: 0n,
      data: '0x',
    })
    await opB.confirm(2n, pausedTx.nonce)
    await expectMessage('pause on execute', CHAMBER_ERROR_MESSAGES.EnforcedPause, () =>
      opA.execute(1n, pausedTx.nonce, '0x'),
    )

    log('done — board, quorum, delegate, undelegate, submit, confirm, revoke, cancel, execute, and the four app error strings')
  } finally {
    if (spawned) {
      spawned.kill('SIGTERM')
    }
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : error)
  process.exitCode = 1
})
