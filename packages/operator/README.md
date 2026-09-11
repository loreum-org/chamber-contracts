# `@loreum/chamber-operator`

Typed operator surface for Chamber. Agents cannot click `TransactionQueue`; this package calls the same functions the React app already uses, through `contracts/generated-abis.ts`.

Implements [loreum-org/chamber#146](https://github.com/loreum-org/chamber/issues/146) and [loreum-org/chamber#180](https://github.com/loreum-org/chamber/issues/180).

## What it does

Given RPC + a signer + a chamber address:

| Action | Chamber function |
| --- | --- |
| Read board + quorum | `getTop`, `getSeats`, `getQuorum`, `getDirectors`, `getSeatedAt`, `paused` |
| Delegate | `delegate` |
| Undelegate | `undelegate` |
| Submit | `submitTransaction` |
| Confirm | `confirmTransaction` |
| Revoke confirmation | `revokeConfirmation` |
| Cancel queued tx | `cancelTransaction` |
| Execute | `executeTransaction` |

Signer is a private key, a viem `Account`, or a prebuilt `WalletClient` (including a 4337 smart-account client whose `writeContract` submits a user operation). This package does not ship a bundler or paymaster.

Failures decode to the same copy the app already shows:

| Revert | App copy |
| --- | --- |
| `DirectorNotSeated` | Your seat is not mature yet |
| `EnforcedPause` | This chamber is paused |
| `TransactionExpired` | This transaction has expired |
| `NotDirector` | You are not a director |

## Library

```ts
import { createOperator } from '@loreum/chamber-operator'

const op = await createOperator({
  rpcUrl: process.env.RPC_URL!,
  chamber: '0x…',
  signer: { type: 'privateKey', privateKey: process.env.PRIVATE_KEY as `0x${string}` },
})

const board = await op.getBoard()
await op.delegate(1n, 10n ** 18n)
const { nonce } = await op.submitTransaction({
  tokenId: 1n,
  target: '0x…',
  value: 0n,
  data: '0x',
})
await op.confirm(2n, nonce)
await op.revokeConfirmation(2n, nonce)
await op.cancelTransaction(1n, nonce)
await op.undelegate(1n, 10n ** 18n)

const next = await op.submitTransaction({
  tokenId: 1n,
  target: '0x…',
  value: 0n,
  data: '0x',
})
await op.confirm(2n, next.nonce)
await op.execute(1n, next.nonce, '0x')
```

4337 signer:

```ts
const op = await createOperator({
  rpcUrl,
  chamber,
  signer: { type: 'walletClient', walletClient: smartAccountClient },
})
```

## CLI

```bash
cd packages/operator && npm install

export CHAMBER_RPC=http://127.0.0.1:8545
export CHAMBER=0x…
export PRIVATE_KEY=0x…

npx chamber-operator board --rpc "$CHAMBER_RPC" --chamber "$CHAMBER"
npx chamber-operator quorum --rpc "$CHAMBER_RPC" --chamber "$CHAMBER"
npx chamber-operator delegate --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 1 --amount 1ether
npx chamber-operator undelegate --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 1 --amount 1ether
npx chamber-operator submit --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 1 --target 0x… --value 0 --data 0x
npx chamber-operator confirm --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 2 --nonce 0
npx chamber-operator revoke --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 2 --nonce 0
npx chamber-operator cancel --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 1 --nonce 0
npx chamber-operator execute --rpc "$CHAMBER_RPC" --chamber "$CHAMBER" --key "$PRIVATE_KEY" \
  --token-id 1 --nonce 0 --data 0x
```

## Anvil end-to-end

Requires Foundry (`anvil`, `forge`). From `packages/operator`:

```bash
npm install
npm run example:anvil
```

That script starts Anvil if needed, runs `DeployAllAnvil`, creates a 3-seat chamber, then:

1. Delegates from two directors and shows a pending board
2. `submit` before the seating delay → `Your seat is not mature yet`
3. Mines one block (`SEATING_DELAY = 1`)
4. `submit` → `confirm` → `revokeConfirmation` → `cancelTransaction` (quorum of cancel votes)
5. `submit` → `confirm` → `execute`
6. A third key `confirm` → `You are not a director`
7. A short-deadline nonce after `evm_increaseTime` → `This transaction has expired`
8. `undelegate` a partial amount from a membership tokenId
9. Board `pause()` then `execute` → `This chamber is paused`

## Out of scope

Sensor Hub, Agent Hub, a new subgraph, and a production agent runtime. No new Solidity.
