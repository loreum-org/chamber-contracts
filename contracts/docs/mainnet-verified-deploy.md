# Ethereum mainnet verified deploy package (M1)

Human-run package for deploying **Factory + Chamber implementation + BoardLib + WalletLib**, then `createChamber` for live LORE. This is **not** a broadcast. The rehearsal still cannot broadcast. Safe `transferOwnership` is **human-only**.

**Deploy remains blocked** on [PMN-H01 (#208)](https://github.com/loreum-org/chamber/issues/208) until that finding is formally accepted or fixed. Mediums [#209](https://github.com/loreum-org/chamber/issues/209)–[#212](https://github.com/loreum-org/chamber/issues/212) are open. PRs [#213](https://github.com/loreum-org/chamber/pull/213) (Chamber 1.1.7 eviction fix) and [#206](https://github.com/loreum-org/chamber/pull/206) (Halmos harness, not a full proof) are open and unmerged. **Do not claim deploy is unblocked.**

Fork rehearsal (mechanics only): [`mainnet-lore-handoff-rehearsal.md`](./mainnet-lore-handoff-rehearsal.md).

## What this package is

| Piece | Path | Broadcast? |
| --- | --- | --- |
| Print commands | `make print-mainnet-factory-deploy` | No (refuses `--broadcast`) |
| Factory + libs + impl | `script/DeployMainnetFactory.s.sol` | Gated: `MAINNET_DEPLOY_UNBLOCKED=1` |
| `createChamber` | `script/CreateMainnetLoreChamber.s.sol` | Same gate; needs `FACTORY` |
| Verify | `make verify-mainnet-factory` | No (Etherscan only) |
| Receipt extract | `script/extract-mainnet-broadcast.sh` | No (prints labels) |
| Address template | `deployments/mainnet.txt` | TBD until a chain-id-1 receipt |

`DeployFactory.s.sol` remains the generic script (any chain). Use **DeployMainnetFactory** on Ethereum so libs are logged and Sepolia is refused.

## Required env (do not commit)

| Variable | Role |
| --- | --- |
| `MAINNET_RPC_URL` | Preferred Ethereum RPC (`foundry.toml` `[rpc_endpoints].mainnet`). Fallback: `ETH_RPC_URL` |
| `ETHERSCAN_API_KEY` | `foundry.toml` `[etherscan].mainnet` |
| `--account` / keystore | Deployer (Foundry). Do not commit keys |
| `ADMIN` | Optional. Default: team Safe `0x5d45A213B2B6259F0b3c116a8907B56AB5E22095` |
| `FACTORY` | Required for create. From the Factory **broadcast receipt**, never Sepolia |
| `MAINNET_DEPLOY_UNBLOCKED` | Must be `1` to pass `--broadcast`. Set only after #208 is accepted or fixed |

Do not commit RPC URLs or keys. Sepolia Factory `0x43aA92c8A26392f21F63cdA88B6BaB5031C40550` is **reference only**. Do not copy it onto chain id 1.

## Constructor / create args

### Factory

```
constructor(address implementation_, address admin)
```

- `implementation_`: Chamber implementation from the same deploy (over EIP-170; linked to BoardLib + WalletLib)
- `admin`: team Safe `0x5d45A213B2B6259F0b3c116a8907B56AB5E22095` (matches Sepolia Factory owner)

Chamber implementation, BoardLib, and WalletLib have empty constructors.

### createChamber (after Factory exists)

Same args as `script/Chamber.s.sol` when `block.chainid == 1` and the fork rehearsal:

| Arg | Value |
| --- | --- |
| `erc20Token` | LORE `0x7756D245527F5f8925A537be509BF54feb2FdC99` |
| `erc721Token` | membership `0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15` |
| `seats` | `5` (quorum `1 + (5 * 51) / 100` = 3) |
| `name` | `Chamber LORE` |
| `symbol` | `cLORE` |

`Factory.createChamber` uses `new TransparentUpgradeableProxy` (**CREATE**, no salt). The Chamber proxy address is the Factory’s next nonce. **Do not pre-commit it.** Record it from the create receipt, then (human) Safe-sign `LORE.transferOwnership(chamber)`.

The Ownable target is the **Chamber proxy**. Wallet execution uses `address(this)` as `msg.sender`.

## Exact order

From `contracts/`:

```bash
export MAINNET_RPC_URL=...          # do not commit
export ETHERSCAN_API_KEY=...        # do not commit
```

### 0. Rehearsal (no broadcast)

```bash
make rehearse-mainnet-lore-handoff
# or
make rehearse-mainnet-lore-handoff-script
```

`script/RehearseMainnetLoreHandoff.s.sol` reverts if you pass `--broadcast` / `--resume`.

### 1. Dry-run Factory package on a fork

```bash
make print-mainnet-factory-deploy
forge script script/DeployMainnetFactory.s.sol:DeployMainnetFactory \
  --fork-url "$MAINNET_RPC_URL" -vvv
```

Dry-run addresses are **not** live. Do not paste them into `deployments/mainnet.txt`.

### 2. Broadcast Factory (human, after #208)

```bash
export MAINNET_DEPLOY_UNBLOCKED=1
export ADMIN=0x5d45A213B2B6259F0b3c116a8907B56AB5E22095
forge script script/DeployMainnetFactory.s.sol:DeployMainnetFactory \
  --rpc-url "$MAINNET_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --chain-id 1 \
  -vvv
```

```bash
bash script/extract-mainnet-broadcast.sh \
  broadcast/DeployMainnetFactory.s.sol/1/run-latest.json
```

Paste **Factory**, **Chamber implementation**, **BoardLib**, **WalletLib** into `deployments/mainnet.txt` (and the app copy `app/contracts/deployments/mainnet.txt`). Leave **Chamber (proxy)** as TBD until step 4.

### 3. Verify (libs → Chamber impl → Factory)

```bash
make verify-mainnet-factory
# Print commands only (no API key needed):
PRINT_ONLY=1 make verify-mainnet-factory
```

The script refuses TBD and refuses the Sepolia Factory address. Factory constructor args are `abi.encode(implementation, admin)`. Chamber verify passes `--libraries` for BoardLib + WalletLib (same pairing as `make verify-sepolia-factory`).

Optional `--verify` on the forge script can run at broadcast time; still re-run this target so Etherscan links the libs.

### 4. Broadcast createChamber (human, after Factory is verified)

```bash
export MAINNET_DEPLOY_UNBLOCKED=1
export FACTORY=0x<factory-from-step-2-receipt>
forge script script/CreateMainnetLoreChamber.s.sol:CreateMainnetLoreChamber \
  --rpc-url "$MAINNET_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --chain-id 1 \
  -vvv
```

Paste **Chamber (proxy)** from that receipt. On Etherscan, mark the proxy as a TransparentUpgradeableProxy pointing at the verified implementation.

### 5. App

`getContractAddresses(1)` reads `VITE_MAINNET_*` then `deployments/mainnet.txt`. TBD / empty → zero address. The app already treats that as unset (`isMainnetConfigured` / `hasValidAddresses`). Chain id 1 never falls back to Sepolia.

Set `VITE_MAINNET_FACTORY` (and impl) only after verify. Do not invent addresses.

### 6. Safe `transferOwnership` (human-only)

Do **not** run this from a script. From the team Safe (`0x5d45A213B2B6259F0b3c116a8907B56AB5E22095`), call `LORE.transferOwnership(chamber)` on the **Chamber proxy** from step 4. The fork rehearsal impersonates this call; production is a real Safe tx.

## App wiring

- `app/src/lib/mainnetDeployments.ts` parses `app/contracts/deployments/mainnet.txt`
- `getContractAddresses(1)` → `CONTRACT_ADDRESSES.mainnet` (env, then file, else zero)
- Keep both `mainnet.txt` copies in sync when pasting

## What this package does not do

- Does not broadcast from Make / print / verify / extract
- Does not execute Safe or `transferOwnership`
- Does not fix or accept #208–#212
- Does not merge #213 / #206
- Does not copy Sepolia addresses onto chain id 1
- Does not pre-compute the Chamber proxy (CREATE, no salt)
