import { type Address, type Hex, isAddress, isHex, parseEther } from 'viem'
import { createOperator } from './client.ts'
import { ChamberOperatorError } from './errors.ts'

const USAGE = `chamber-operator — typed Chamber board / queue actions (same ABI as the app)

Usage:
  chamber-operator <command> [options]

Commands:
  board                 Read board seats, quorum, pause, and seating
  quorum                Read live quorum
  tx --nonce <n>        Read one queued nonce
  delegate              Delegate vault shares to a membership tokenId
  undelegate            Undelegate vault shares from a membership tokenId
  submit                submitTransaction (director)
  confirm               confirmTransaction (director)
  revoke                revokeConfirmation (director)
  cancel                cancelTransaction (director)
  execute               executeTransaction (director)

Required (or env):
  --rpc <url>           RPC_URL / CHAMBER_RPC
  --chamber <addr>      CHAMBER
  --key <hex>           PRIVATE_KEY / CHAMBER_KEY   (writes only)

Writes:
  --token-id <n>
  --amount <wei|ether>  delegate / undelegate amount (1ether or raw wei)
  --target <addr>       submit target
  --value <wei|ether>   submit ETH value (default 0)
  --data <hex>          submit / execute calldata (default 0x)
  --deadline <unix>     optional submit deadline
  --nonce <n>           confirm / revoke / cancel / execute / tx

A 4337 smart-account client is supported from the library API
(createOperator({ signer: { type: 'walletClient', walletClient } })),
not from this CLI.

Exit status is non-zero on revert. Seating delay, pause, expired nonce,
and not-a-director use the same copy as the React app.
`

type Flags = Record<string, string | boolean>

function parseArgs(argv: string[]): { command: string; flags: Flags } {
  const [command, ...rest] = argv
  if (!command || command === '-h' || command === '--help') {
    return { command: 'help', flags: {} }
  }
  const flags: Flags = {}
  for (let i = 0; i < rest.length; i++) {
    const token = rest[i]
    if (!token.startsWith('--')) {
      throw new ChamberOperatorError(`Unexpected argument: ${token}`)
    }
    const key = token.slice(2)
    const next = rest[i + 1]
    if (next === undefined || next.startsWith('--')) {
      flags[key] = true
      continue
    }
    flags[key] = next
    i++
  }
  return { command, flags }
}

function flag(flags: Flags, name: string, envNames: string[] = []): string | undefined {
  const raw = flags[name]
  if (typeof raw === 'string' && raw.length > 0) return raw
  for (const envName of envNames) {
    const value = process.env[envName]
    if (value) return value
  }
  return undefined
}

function requireFlag(flags: Flags, name: string, envNames: string[] = []): string {
  const value = flag(flags, name, envNames)
  if (!value) {
    throw new ChamberOperatorError(
      `Missing --${name}${envNames.length ? ` (or ${envNames.join('/')})` : ''}`,
    )
  }
  return value
}

function requireAddress(value: string, label: string): Address {
  if (!isAddress(value)) throw new ChamberOperatorError(`Invalid ${label}: ${value}`)
  return value
}

function parseAmount(raw: string): bigint {
  const trimmed = raw.trim()
  if (/^\d+$/.test(trimmed)) return BigInt(trimmed)
  if (trimmed.endsWith('ether')) return parseEther(trimmed.slice(0, -5))
  if (trimmed.endsWith('wei')) return BigInt(trimmed.slice(0, -3))
  try {
    return parseEther(trimmed)
  } catch {
    throw new ChamberOperatorError(`Invalid amount: ${raw}`)
  }
}

function parseUint(raw: string, label: string): bigint {
  if (!/^\d+$/.test(raw.trim())) {
    throw new ChamberOperatorError(`Invalid ${label}: ${raw}`)
  }
  return BigInt(raw.trim())
}

function jsonReplacer(_key: string, value: unknown): unknown {
  return typeof value === 'bigint' ? value.toString() : value
}

function printJson(value: unknown): void {
  process.stdout.write(`${JSON.stringify(value, jsonReplacer, 2)}\n`)
}

async function main(): Promise<void> {
  const { command, flags } = parseArgs(process.argv.slice(2))
  if (command === 'help') {
    process.stdout.write(USAGE)
    return
  }

  const rpcUrl = requireFlag(flags, 'rpc', ['CHAMBER_RPC', 'RPC_URL'])
  const chamber = requireAddress(requireFlag(flags, 'chamber', ['CHAMBER']), 'chamber')
  const key = flag(flags, 'key', ['CHAMBER_KEY', 'PRIVATE_KEY'])

  const operator = await createOperator({
    rpcUrl,
    chamber,
    signer: key
      ? { type: 'privateKey', privateKey: (key.startsWith('0x') ? key : `0x${key}`) as Hex }
      : undefined,
  })

  switch (command) {
    case 'board': {
      printJson(await operator.getBoard())
      return
    }
    case 'quorum': {
      printJson({ quorum: await operator.getQuorum() })
      return
    }
    case 'tx': {
      const nonce = parseUint(requireFlag(flags, 'nonce'), 'nonce')
      printJson(await operator.getTransaction(nonce))
      return
    }
    case 'delegate': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const amount = parseAmount(requireFlag(flags, 'amount'))
      printJson(await operator.delegate(tokenId, amount))
      return
    }
    case 'undelegate': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const amount = parseAmount(requireFlag(flags, 'amount'))
      printJson(await operator.undelegate(tokenId, amount))
      return
    }
    case 'submit': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const target = requireAddress(requireFlag(flags, 'target'), 'target')
      const valueRaw = flag(flags, 'value')
      const data = flag(flags, 'data') ?? '0x'
      if (!isHex(data)) throw new ChamberOperatorError(`Invalid --data: ${data}`)
      const deadlineRaw = flag(flags, 'deadline')
      printJson(
        await operator.submitTransaction({
          tokenId,
          target,
          value: valueRaw ? parseAmount(valueRaw) : 0n,
          data,
          deadline: deadlineRaw ? parseUint(deadlineRaw, 'deadline') : undefined,
        }),
      )
      return
    }
    case 'confirm': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const nonce = parseUint(requireFlag(flags, 'nonce'), 'nonce')
      printJson(await operator.confirm(tokenId, nonce))
      return
    }
    case 'revoke': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const nonce = parseUint(requireFlag(flags, 'nonce'), 'nonce')
      printJson(await operator.revokeConfirmation(tokenId, nonce))
      return
    }
    case 'cancel': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const nonce = parseUint(requireFlag(flags, 'nonce'), 'nonce')
      printJson(await operator.cancelTransaction(tokenId, nonce))
      return
    }
    case 'execute': {
      const tokenId = parseUint(requireFlag(flags, 'token-id'), 'token-id')
      const nonce = parseUint(requireFlag(flags, 'nonce'), 'nonce')
      const data = flag(flags, 'data') ?? '0x'
      if (!isHex(data)) throw new ChamberOperatorError(`Invalid --data: ${data}`)
      printJson(await operator.execute(tokenId, nonce, data))
      return
    }
    default:
      throw new ChamberOperatorError(`Unknown command: ${command}\n\n${USAGE}`)
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error)
  process.stderr.write(`${message}\n`)
  process.exitCode = 1
})
