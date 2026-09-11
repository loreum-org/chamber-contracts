/**
 * Offline: committed mainnet.txt must not invent Factory/Chamber or copy Sepolia.
 * TBD stays unparseable as an address (same rules as `parseMainnetDeploymentAddresses`).
 *
 * Run: npm run test:mainnet-addresses
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { getAddress, isAddress } from 'viem'

const ZERO = '0x0000000000000000000000000000000000000000'
const SEPOLIA_FACTORY = '0x43aA92c8A26392f21F63cdA88B6BaB5031C40550'
const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const txt = readFileSync(join(root, 'contracts/deployments/mainnet.txt'), 'utf8')

const LINE_PARSERS = [
  { key: 'registry', re: /^Registry \(proxy\)\s+(0x[a-fA-F0-9]{40})\s*$/i },
  { key: 'factory', re: /^Factory\s+(0x[a-fA-F0-9]{40})\s*$/i },
  { key: 'chamberImplementation', re: /^Chamber implementation\s+(0x[a-fA-F0-9]{40})\s*$/i },
] as const

const parsed = { registry: ZERO, factory: ZERO, chamberImplementation: ZERO }
for (const line of txt.split(/\r?\n/)) {
  const trimmed = line.trim()
  for (const { key, re } of LINE_PARSERS) {
    const match = trimmed.match(re)
    if (!match?.[1] || !isAddress(match[1])) continue
    parsed[key] = getAddress(match[1])
  }
}

assert.equal(parsed.factory, ZERO, 'Factory must stay unset while TBD')
assert.equal(parsed.chamberImplementation, ZERO, 'Chamber impl must stay unset while TBD')
assert.equal(parsed.registry, ZERO, 'Registry must stay unset while TBD')
assert.match(txt, /Factory\s+TBD/)
assert.match(txt, /Chamber implementation\s+TBD/)
assert.ok(txt.includes(SEPOLIA_FACTORY), 'must warn against copying Sepolia Factory')
assert.ok(!/^Factory\s+0x43aA92c8A26392f21F63cdA88B6BaB5031C40550/m.test(txt))

console.log('mainnet.txt TBD: getContractAddresses(1) has no fabricated Factory/Chamber')
