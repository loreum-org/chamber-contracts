#!/usr/bin/env node
/**
 * Run Playwright Sepolia wallet smoke, or exit 0 when the throwaway key is unset
 * so default CI / `npm test` stay green.
 *
 * If app/.env exists, KEY=VALUE lines are loaded into process.env before the
 * key check. Already-set environment variables are not overridden.
 */
import { spawn } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const APP_ENV_KEYS = new Set([
  'E2E_SEPOLIA_PRIVATE_KEY',
  'SEPOLIA_PRIVATE_KEY',
  'PLAYWRIGHT_BASE_URL',
  'PLAYWRIGHT_SEPOLIA_CHAMBER',
])

/**
 * Parse KEY=VALUE lines (comments/blanks ignored). Does not override env.
 * @param {string} envPath
 * @param {NodeJS.ProcessEnv} [env]
 */
function loadAppEnvFile(envPath, env = process.env) {
  if (!existsSync(envPath)) return
  let text
  try {
    text = readFileSync(envPath, 'utf8')
  } catch {
    return
  }
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const assignment = line.startsWith('export ') ? line.slice(7).trimStart() : line
    const eq = assignment.indexOf('=')
    if (eq <= 0) continue
    const key = assignment.slice(0, eq).trim()
    if (!APP_ENV_KEYS.has(key)) continue
    if (env[key] !== undefined) continue
    let value = assignment.slice(eq + 1).trim()
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1)
    }
    env[key] = value
  }
}

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
loadAppEnvFile(path.join(appDir, '.env'))
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
