#!/usr/bin/env node
/**
 * Run Playwright Sepolia wallet smoke, or exit 0 when the throwaway key is unset
 * so default CI / `npm test` stay green.
 */
import { spawn } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const key = (process.env.E2E_SEPOLIA_PRIVATE_KEY || process.env.SEPOLIA_PRIVATE_KEY || '').trim()

if (!key) {
  console.log(
    'test:e2e:sepolia skipped: E2E_SEPOLIA_PRIVATE_KEY / SEPOLIA_PRIVATE_KEY unset.\n' +
      'Set a throwaway Sepolia private key (wallet needs Sepolia ETH) to run the smoke.',
  )
  process.exit(0)
}

const keyHex = key.startsWith('0x') || key.startsWith('0X') ? key.slice(2) : key
if (!/^[0-9a-fA-F]{64}$/.test(keyHex)) {
  console.error('E2E_SEPOLIA_PRIVATE_KEY / SEPOLIA_PRIVATE_KEY must be a 32-byte hex private key')
  process.exit(1)
}

const playwrightBin = path.join(appDir, 'node_modules', '.bin', 'playwright')

function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(playwrightBin, args, {
      cwd: appDir,
      stdio: 'inherit',
      env: process.env,
    })
    child.on('error', reject)
    child.on('exit', (code, signal) => {
      if (signal) {
        reject(new Error(`playwright ${args.join(' ')} terminated by ${signal}`))
        return
      }
      resolve(code ?? 1)
    })
  })
}

const installCode = await run(['install', 'chromium'])
if (installCode !== 0) process.exit(installCode)

const testCode = await run(['test'])
process.exit(testCode)
