# Halmos coverage of `contracts/src` (2026-09-08)

This note is the honest close-out for symbolic verification of Chamber
`contracts/src` before a mainnet deploy. It is **not** a claim that the
protocol is “fully verified.”

**Runner:** Halmos 0.3.3 (`contracts/fv-requirements.txt`) via `make ci-halmos`.  
**Filter:** `--match-test '^symbolic'` and
`--match-contract '^(BoardSymTest|WalletSymTest|ChamberSymTest|VaultSymTest|RegistrySymTest|FactorySymTest)$'`.  
**Loop bound:** Halmos default `--loop 2` (enough for one- and two-node board
walks and two-seat quorum).  
**Proxy limitation:** Halmos cannot execute OpenZeppelin
`TransparentUpgradeableProxy` construction (`vm.deployCode(string)`). Chamber /
Registry / Vault symbolic tests therefore initialize the **implementation**
through `test/symbolic/HalmosDeploy.sol`. That is not the production Factory
path.

## What “complete” means here

Complete, for this gate, means:

1. Every **public/external state-changing** function in `contracts/src` is
   inventoried and tagged `covered` / `partial` / `missing`.
2. The **load-bearing invariants** listed in the deploy checklist are checked
   by a Halmos test that CI actually runs (or the gap is named below).
3. Tests that Halmos cannot close — proxy CREATE, unbounded list walks,
   nonlinear ERC-4626 conversion, batch loops — are documented rather than
   stubbed into a false pass.
4. `make ci-halmos` stays in the same workflow (`.github/workflows/halmos.yaml`)
   with the default solver timeout (60s/assertion) and `--loop 2`.

“Complete” does **not** mean: every path of every function, `MAX_NODES = 50`
list shapes, multi-depositor vault math, or the live proxy + `ProxyAdmin`
handoff.

## Inventory

State-changing `public` / `external` functions only. Views, constructors of
abstract parents, and library `external` helpers (reachable only from Chamber /
mocks) are omitted unless they are the implementation of a Chamber entrypoint.

Legend: **covered** = CI Halmos asserts the invariant on a bounded symbolic
input; **partial** = some paths or a related mock/implementation-only setup;
**missing** = no Halmos assertion in CI.

### `Chamber.sol` (production entrypoint)

| Function | Coverage | Notes |
|---|---|---|
| `initialize` | covered | `ChamberSym` stores asset / NFT / seats; rejects 0 and >20 seats |
| `delegate` | covered | holder ≤ balance; node amount matches; uniqueness via `BoardSym` |
| `undelegate` | covered | holder + node conservation |
| `setDirectorOperator` | covered | only registered key; EOA implicit operator rejected |
| `updateSeats` | partial | proposal + quorum snapshot on `MockBoard.setSeats` (`BoardSym`); Chamber `isDirector` gate is the wallet/director tests |
| `executeSeatsUpdate` | missing | supporter walk is `O(seats × supporters)`; default `--loop 2` cannot close a real quorum execute. Unit: `Board.t.sol` / H-03 |
| `cancelSeatUpdate` | missing | same; unit coverage exists |
| `submitTransaction` (4-arg) | covered | director + seating + auto-confirm; session key |
| `submitTransaction` (deadline) | partial | deadline / expiry on `MockWallet` (`WalletSym`); Chamber overload not separately hashed |
| `submitTransactionWithMetadata` (both) | partial | same `WalletLib` submit path as 4-arg submit |
| `confirmTransaction` | covered | stranger rejected; second director reaches quorum |
| `executeTransaction` | covered | under-quorum and cancelled nonces fail; matching calldata on `WalletSym` |
| `revokeConfirmation` | partial | count conservation on `MockWallet`; Chamber owner/session revoke not symbolically walked |
| `cancelTransaction` | covered | one vote does not cancel; quorum 2 does; execute blocked |
| `submitBatchTransactions` | missing | unbounded `targets.length`; keep out of CI |
| `confirmBatchTransactions` | missing | same |
| `executeBatchTransactions` | missing | same |
| `receive` / `fallback` | missing | ETH credit only; no invariant beyond `balance += msg.value` |
| `onERC721Received` | missing | custody hook; no share mint (documented in natspec) |
| `acceptAdmin` | missing | no-op |
| `pause` / `unpause` | partial | outsider rejected; self-`prank` pause zeroes ERC-4626 `max*` (`VaultSym`). Quorum self-call via wallet not closed (proxy/`execute` composition) |
| `upgradeImplementation` | partial | outsider rejected. Real `ProxyAdmin.upgradeAndCall` needs a proxy Halmos cannot deploy |
| `deposit` / `mint` | covered | empty-vault share multiplier; pause blocks deposit |
| `withdraw` / `redeem` | covered | single-depositor full redeem conservation (offset cancels) |
| `transfer` / `transferFrom` | partial | transfer cannot strand delegation; `transferFrom` + allowance is OZ + same `_update` |
| `approve` | missing | stock OZ ERC-20 |

### `Board.sol` / `BoardLib.sol`

Exercised through `MockBoard` (same ERC-7201 slot + `BoardLib`).

| Behavior | Coverage | Notes |
|---|---|---|
| insert / ranking sort | covered | two distinct ids, descending amounts, unique top set |
| `delegate` same id | covered | size stays 1 |
| `delegate` / `undelegate` amounts | covered | |
| `getQuorum` | covered | `1 + (seats * 51) / 100` for seats in `1..=20` |
| seating delay | covered | new top node immature until `SEATING_DELAY`; extra delegate does not reset |
| seat-update quorum snapshot | covered | first proposal stores live quorum |
| reentrancy on delegate | covered | shared OZ lock |
| `executeSeatsUpdate` / `cancelSeatUpdate` | missing | see Chamber row |
| eviction at `MAX_NODES` (50) | missing | cannot unroll 50; unit/fuzz only |

### `Wallet.sol` / `WalletLib.sol`

Exercised through `MockWallet` (no director modifier) plus Chamber wallet tests.

| Behavior | Coverage | Notes |
|---|---|---|
| submit stores `keccak256(data)` | covered | |
| submit auto-confirm + default 30-day deadline | covered | |
| confirm / revoke count | covered | |
| execute rejects wrong calldata | covered | |
| cancel blocks execute | covered | |
| expired deadline blocks execute | covered | |
| Chamber director / seating / session auth | covered | `ChamberSym` |
| stored self-call calldata (L-04) | missing | needs `target == address(this)` + selector allowlist; not closed here |
| deadline `0` as “unset / not expired” (M-06) | missing | `forceTransactionDeadline` unit test only |

### `Factory.sol`

| Function | Coverage | Notes |
|---|---|---|
| `constructor` | covered | stores intended impl + Ownable admin; zero addresses revert |
| `setImplementation` | covered | owner-only; same-address no-op; zero reverts |
| `createChamber` (invalid input) | covered | zero tokens / seats 0 or >20 revert; impl and owner unchanged |
| `createChamber` (success) | missing | deploys `TransparentUpgradeableProxy` → `vm.deployCode`. **Not Halmos-closable.** Unit: `Factory.t.sol` (impl slot, ProxyAdmin owner = chamber, `initialize` config) |

### `Registry.sol` (deprecated create path)

| Function | Coverage | Notes |
|---|---|---|
| `initialize` | covered | impl + `proxyAdmin` + `DEFAULT_ADMIN_ROLE` / `ADMIN_ROLE` |
| `setChamberImplementation` | covered | admin-only; same-address no-op |
| `createChamber` (invalid input) | covered | does not increment count / change impl |
| `createChamber` (success + index) | missing | same proxy CREATE gap as Factory. Historical asset / parent-child index is unit-tested only |
| `grantRole` / `revokeRole` / `renounceRole` | missing | stock OZ AccessControl |

### Out of symbolic scope (by design)

- `interfaces/*`, `types/*` (no state).
- Production `TransparentUpgradeableProxy` / `ProxyAdmin` (Halmos).
- App / operator / landing packages.

## Load-bearing invariants (checklist)

| Invariant | Where it is checked | Bound / gap |
|---|---|---|
| Board ranking uniqueness | `BoardSym.symbolicSortedOrderAfterTwoInserts`, `symbolicDelegateSameIdDoesNotDuplicateNode` | Two nodes or one id. No 3–50 node shapes |
| Quorum formula | `BoardSym.symbolicQuorumFormula`; Chamber setUp asserts seats=2 → quorum=2 | Closed for `seats ∈ [1,20]` |
| Seating delay | `BoardSym.symbolicSeatingDelay*`; `ChamberSym.symbolicImmatureDirectorCannotSubmit` | `SEATING_DELAY = 1` |
| Operator cleared on transfer | `ChamberSym.symbolicOperatorClearedOnTransfer`, `symbolicSessionKeyCanSubmitUntilTransfer` | Logical clear (`owner` mismatch), not storage `delete` |
| Wallet queue auth (submit / confirm / execute / cancel) | `ChamberSym.symbolicWalletQueueRequiresDirector`, `symbolicWalletCancelRequiresQuorum`; lifecycle on `WalletSym` | Two seats, concrete token ids 1 and 2, symbolic stranger / session key |
| Vault share accounting | `VaultSym` empty-vault multiplier + single-depositor redeem conservation | No multi-depositor / donation / nonlinear `convertTo*` |
| Factory only creates with intended admin / impl | `FactorySym` constructor + `setImplementation` + invalid `createChamber` does not mutate | **Success-path CREATE is a documented gap**; unit tests own the proxy handoff |

## Loops, solvers, and timeouts Halmos cannot close

- **`--loop 2`:** `BoardLib.getTop` / `topTokenIds` / `refreshSeating` /
  `_isInTopSeats` / `_countCurrentDirectorFlags` are closed only for ≤2 live
  nodes or seats. A 3-seat board or a 3-node list is an incomplete unroll, not
  a proof.
- **`MAX_NODES = 50` eviction** and **seat-update supporter ∩ top-seat**
  (`executeSeatsUpdate`) are nested loops. Raising `--loop` enough to close
  them would blow CI time. Left to Foundry unit / fuzz.
- **Batch wallet functions** iterate caller-supplied arrays
  (`--default-array-lengths 0,1,2` would still miss realistic sizes).
- **ERC-4626 `convertToShares` / `convertToAssets`** with a live, symbolic
  `totalSupply` and `totalAssets` is nonlinear (`mulDiv`). Vault tests stay on
  the empty-vault identity `shares = assets * 10**3` and the single-depositor
  redeem that algebraically cancels the offset. Multi-depositor rounding,
  donation, and fee-on-transfer are unit/fuzz (`Finding6`, `Vault.t.sol`).
- **`TransparentUpgradeableProxy`:** any test that `new`s a production proxy
  (Factory / Registry `createChamber` success, `DeployChamber`,
  `DeployRegistry`) fails in `setUp` or the call with
  `Unsupported cheat code: deployCode(string)`. Do not re-add those setups to
  `HALMOS_INCLUDE`.
- **`upgradeImplementation`:** requires ERC-1967 admin + `ProxyAdmin.owner() == chamber`.
  Cannot be constructed under Halmos. Outsider rejection is checked; the
  upgrade itself is not.
- **Solver timeouts:** assertion timeout stays at 60s. If a new test times
  out, shrink bitwidths (`createUint(16|48|64|96)`) or drop it from CI rather
  than claiming a pass.

## How to run

```bash
cd contracts
pip install -r fv-requirements.txt   # Halmos 0.3.3
make ci-halmos
```

Existing Foundry unit / fuzz / findings tests remain the safety net for
everything tagged **missing** or **partial**.
