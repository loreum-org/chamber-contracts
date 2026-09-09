# Pre-mainnet adversarial review — Chamber `contracts/src`

**Date**: 2026-09-08  
**Reviewer**: Cursor Cloud Agent  
**Repo / commit reviewed**: `loreum-org/chamber` `ce7845e` (`main` at review start), plus the localized `1.1.7` hot-path fix in this PR  
**Version**: `Chamber.VERSION` was `"1.1.6"` on `main`; this PR sets `"1.1.7"`  
**Scope**: Production Solidity under `contracts/src/` — `Board.sol`, `Chamber.sol`, `Factory.sol`, `Registry.sol`, `Wallet.sol`, `libraries/BoardLib.sol`, `libraries/WalletLib.sol`, plus types and interfaces as needed. Tests, mocks, app, CCA, and landing are out of scope.

This is a defensive review of code we maintain. It does **not** include exploit proofs of concept, payloads, calldata recipes, or step-by-step attack procedures. It does not invent Ethereum mainnet addresses. Addresses quoted below already appear in the repository README.

---

## Threat model (short)

Chamber is one transparent proxy that joins three surfaces:

1. **ERC-4626 vault** — anyone holding the configured ERC-20 can deposit and receive shares. Share transfers and burns cannot drop a holder below `totalHolderDelegations`.
2. **Delegation-weighted board** — share holders delegate to membership ERC-721 `tokenId`s. The top `seats` (1–20) of a sorted list (cap 50 nodes) are directors.
3. **Director wallet** — submit / confirm / execute / cancel / revoke. Execute and cancel recount flags on *current* top-seat `tokenId`s. Execute requires `max(submitQuorum, liveQuorum)`. Self-calls are limited to `upgradeImplementation`, `pause`, and `unpause`.

**Actors**

| Actor | Trust |
| --- | --- |
| Share depositor | Trusts the sitting board with the vault asset and any other tokens/ETH the proxy holds. Can exit the vault only while not paused and not delegation-locked. |
| Membership NFT owner / session key | One vote per seated `tokenId` (accepted I-03). A session key on a *contract-owned* NFT is a full seat equivalent until cleared or the NFT moves. |
| Factory owner | Chooses the Chamber implementation used for *future* `Factory.createChamber` deploys only. Cannot upgrade existing chambers. |
| Registry `ADMIN_ROLE` | Same for the deprecated `Registry.createChamber` path. Existing Registry proxies must not be in-place-upgraded onto this implementation without a role migration. |
| Board quorum | Can spend ETH and arbitrary tokens (including the vault underlying), pause/unpause, and replace the Chamber implementation. |

**In-scope threats**

- Same-transaction or short-horizon board capture (share flash weight, NFT control change, seating-delay bypass).
- Quorum / seat asymmetry: stale flags, underfilled boards, inert or burned membership tokens.
- Session-key vs owner confusion; NFT transfer not clearing the right state.
- Vault share accounting (donation, fee-on-transfer, delegation lock).
- Wallet queue races (submit / confirm / execute / cancel / expiry).
- Factory misconfiguration; upgrade/admin path; Registry leftover create path.
- Unbounded loops or indexes that turn griefing into undelegate/withdraw lock.

**Out of scope / accepted product facts**

- Token-weighted quorum (one owner of `quorum` top-seat NFTs is a single-actor treasury). See [I-03](./i-03-token-weighted-quorum.md).
- The board *is* the treasury operator. Solvency of the ERC-4626 against a live quorum is a social/product guarantee, not an on-chain depositor covenant.
- Membership collection and vault asset are chosen at create time; Factory does not allowlist them.

---

## Findings table

| ID | Severity | File | Invariant broken | Recommended fix |
| --- | --- | --- | --- | --- |
| PMN-H01 | **high** | `Chamber.sol` (`_isDirector`, `_isSeatingMature`); `BoardLib.sol` (`refreshSeating`) | A controller who newly acquires an *already-seated* `tokenId` must not exercise that seat in the same transaction (H-02’s flash-resistance goal). Today `seatedAt` and confirm/cancel flags are bound to `tokenId` only. Session keys go stale on transfer; seating and votes do not. | Snapshot `ownerOf` (or a transfer generation) when a seat becomes mature. On owner change, treat the token as newly seated (write `seatedAt = block.number + SEATING_DELAY`) and drop or ignore flags recorded under the previous owner. Do not rely on a 1-block tokenId delay alone if the membership NFT is transferable. |
| PMN-H02 | **high** → **low** in this PR | `Chamber.sol` (`_syncTrackedDelegations`); `BoardLib.sol` (`insert` / `evictedTokenIds`) | `delegate` / `undelegate` (and therefore withdraw, because of the delegation lock) must stay callable as the eviction index grows. On `1.1.6`, every sync walked the entire `evictedTokenIds` set. | **This PR:** skip board/eviction walks when the holder set already sums to `totalHolderDelegations`. Residual: the eviction index can still grow in storage (PMN-L06). Cap or prune `evictedTokenIds` if long-lived chambers will churn many unique tails. |
| PMN-M01 | **medium** | `BoardLib.sol` (`getQuorum`); `Chamber.sol` (`_countCurrentDirectorFlags`, `_isInTopSeats`); `Factory.sol` / `Registry.sol` (`createChamber`) | Wallet and seat-change liveness require that *reachable, authorized* directors can meet quorum. Quorum is `1 + (seats * 51) / 100` against the *configured* seat count, including empty seats and inert `tokenId`s (burned, uncallable contract, chamber-held). | Count only `tokenId`s whose `ownerOf` succeeds and that can still authorize a caller. Reject or warn at create when `seats` exceeds a documented bound vs collection supply. Add a recovery path that can lower `seats` when filled authorized seats are below quorum (for example a long delay + remaining-director threshold). |
| PMN-M02 | **medium** | `Chamber.sol` (`_countCurrentDirectorFlags`, `revokeConfirmation`); `WalletLib.sol` | Flags and rank must not outlive a `tokenId` that no current controller can operate. Burned or inert tokens stay in the top set if weight remains; prior confirm/cancel bits still count; `revokeConfirmation` cannot run if `ownerOf` reverts. | Skip flags for tokenIds that fail `ownerOf` or fail `_isTokenAuthorized` for every realistic caller. On burn/inert, drop rank (or auto-undelegate) rather than leaving a zombie seat. Allow a public cleanup that clears flags when `ownerOf` reverts. |
| PMN-M03 | **medium** | `Factory.sol`; `Registry.sol` | New mainnet chambers must come from one reviewed implementation pointer, with an admin that cannot silently retarget creates. `Registry.createChamber` is still live and has its own implementation slot. Factory `setImplementation` is single-`Ownable` and does not check that the new address has code. | Ship Factory as the only create path. Disable or document-never-call Registry create on Ethereum. Put Factory owner on a timelock/Safe. Require `extcodesize` (and, if practical, a version/interface probe) in `setImplementation`. |
| PMN-M04 | **medium** | `Chamber.sol` (`setDirectorOperator`, `_isLiveSessionKey`) | A session key is a full director for that `tokenId` (submit / confirm / execute / seats / revoke) with no expiry, no selector allowlist, and no rotation delay. Compromised operator equals compromised seat until the *current contract owner* clears it. | Add expiry and an optional selector/target scope. Consider a delay before a newly set key can execute (align with seating). Keep the “owner contract must register the key; never ERC-1271” rule. |
| PMN-L01 | **low** | `BoardLib.sol` (`setSeats`, `authorizeSeatUpdateCancel`) | Any current director should be able to replace a no-op seat proposal without waiting 14 days. Only the proposer can cancel before `SEAT_UPDATE_EXPIRY`. | Allow a current-board threshold to cancel before expiry, or reject proposals where `proposedSeats == seats`. |
| PMN-L02 | **low** | `BoardLib.sol` (`insert`) | Any existing membership `tokenId` should be seatable. `tokenId > type(uint128).max` reverts (`TokenIdTooLarge`). | Document the packed-link limit in Factory/create UX (not in this PR). Or store links as `uint256` if a target collection uses 256-bit ids. |
| PMN-L03 | **low** | `WalletTypes.sol`; `WalletLib.sol` (`confirmTransaction`) | Confirm must not revert solely because a `uint8` counter saturated. Execute already recounts live flags, but `confirmations += 1` can revert after 255 unique `tokenId`s have confirmed one nonce. | Use `uint256`, or stop incrementing the stored counter and treat it as informational. |
| PMN-L04 | **low** | `IWallet.sol` (`getCancelConfirmations`); `Chamber.sol` (`cancelTransaction`) | Getters used for UX/automation must match execute/cancel math. The getter is the raw `uint8` counter; cancel uses live top-seat flags. | Expose a live cancel count (mirror `_countCurrentDirectorFlags`) or document the getter as historical. |
| PMN-L05 | **low** | `Wallet.sol` (`getCurrentNonce`) | An empty queue should not report the same nonce as the first real transaction (`0`). | Return a sentinel or document that `getNextTransactionId` is the supported API. |
| PMN-L06 | **low** | `BoardLib.sol` (`evictedTokenIds`) | After PMN-H02’s hot-path skip, the eviction set is still an unbounded storage index (M-03 upgrade backfill / slow `getDelegations` path). | Cap the set, drop oldest entries, or stop writing it on fresh deploys that already have per-holder sets. |
| PMN-L07 | **low** | `Chamber.sol` (`_decimalsOffset`) | Offset `3` is the OZ default mitigation, not a guarantee, especially for low-decimal assets. | Keep the standard-ERC-20-only create rule. Consider a higher offset or a factory dead-share seed if a 6-decimal asset is in scope. |
| PMN-L08 | **low** | `Chamber.sol` (`submitBatchTransactions`) | Batch submit has no length cap (directors pay gas; no full-array walk on execute). | Cap batch size if queue bloat becomes an indexer/ops problem. |
| PMN-L09 | **low** | `Factory.sol` (`setImplementation`) | Implementation pointer should be a contract. Zero is rejected; EOAs are not. | `extcodesize` check (overlaps PMN-M03). |
| PMN-L10 | **low** | `Chamber.sol` (`cancelTransaction` vs `_requiredConfirmations`) | Cancel uses live quorum only; execute uses `max(submit, live)`. After a seat *decrease*, cancel is easier than execute. | Accept as conservative for spends, or snapshot a cancel threshold too. |
| PMN-I01 | **info** | `Chamber.sol`; `IChamber.sol` | Accepted I-03: confirmations are per `tokenId`, not per address. | Keep user-facing copy aligned with [I-03](./i-03-token-weighted-quorum.md). |
| PMN-I02 | **info** | `Chamber.sol` (wallet + ERC-4626) | The board can move the vault underlying through a normal wallet call. Depositors are not protected from a live quorum. | State this in deploy/runbooks. Do not market the vault as an ungoverened ERC-4626. |
| PMN-I03 | **info** | `Chamber.sol` (`pause`, `executeBatchTransactions`) | Pause blocks vault exit and non-unpause executes. The same quorum can unpause and spend in one batch. Pause is not a depositor exit window. | If an exit window is required, add a timelock between unpause and other executes. |
| PMN-I04 | **info** | `BoardTypes.sol` (`SEATING_DELAY = 1`) | One block is enough to stop *share-weight* same-transaction seating (H-02 as implemented). It is the minimum anti-flash-loan delay, not a social review period. | Keep 1 block if the only goal is same-tx share flash resistance; do not treat it as NFT-transfer resistance (PMN-H01). |
| PMN-I05 | **info** | `Chamber.sol` (`onERC721Received`) | Any ERC-721 is accepted; ERC-1155 `safeTransferFrom` reverts. Receipt does not mint shares or seats. | Already documented on the function. |
| PMN-I06 | **info** | `IRegistry.sol`; `Registry.sol` | Registry is a deprecated index. Parent/child links are permissionless metadata from the old create path. Factory does not write them. | Point operators at Factory + `ChamberCreated` logs. |

---

## Review of prior items (2026-08-26 `docs/security-review-src.md`)

Those findings were re-read against current `1.1.6` source. This table is disposition, not a second exploit write-up.

| Prior ID | Disposition on current source |
| --- | --- |
| H-01 stale execute confirmations | **Cleared.** Execute/cancel use `_countCurrentDirectorFlags`. Revoke is owner/session-key gated, not seat-gated. Residual: flags still follow the `tokenId` across owner change (PMN-H01 / PMN-M02). |
| H-02 no seating delay | **Partially cleared.** New top-set `tokenId`s wait `SEATING_DELAY` (1 block). Incumbents with `seatedAt == 0` stay live (upgrade-safe). Residual is PMN-H01. |
| H-03 seat-update slot wedged | **Cleared** as specified: after 14 days any current director may clear. Residual 14-day dummy-proposal freeze is PMN-L01. |
| M-01 ERC-1271 director auth | **Cleared.** Chamber never consults ERC-1271. Session key path is explicit. |
| M-02 reentrancy holes | **Cleared.** Vault, delegate/undelegate, seats, and wallet mutators share `ReentrancyGuardTransientUpgradeable`. `upgradeImplementation` correctly omits a nested guard. |
| M-03 evicted delegation discovery | **Cleared** for the read API (per-holder set + union). The fix introduced the hot-path walk addressed by PMN-H02. |
| M-04 seat decrease revives old txs | **Cleared.** `_requiredConfirmations` is `max(submitQuorum, liveQuorum)`. |
| M-05 Registry AccessControl layout | **Mitigated** for new Registry proxies (`AccessControlUpgradeable`, ERC-7201). In-place upgrade of a slot-0 Registry remains unsafe (documented on `Registry`). |
| M-06 no tx expiry | **Cleared.** Default 30-day deadline; stored `0` is unset/not expired. |
| M-07 unconstrained vault asset | **Partially cleared.** `_deposit` requires observed delta `== assets` (fee-on-transfer reverts). Rebasing/elastic assets remain unsupported. |
| L-01 unbounded Registry getters | **Mitigated.** Pagination + `MAX_PAGE_SIZE`. Factory has no world list. |
| L-02 no pause | **Cleared.** Quorum self-call `pause` / `unpause`. See PMN-I03. |
| L-03 custom circuit breaker | **Cleared.** OZ transient guard only. |
| L-04 hash-only calldata | **Cleared** for self-calls (bytes stored). Hash-only remains for external targets (accepted Safe-style liveness/ops). |
| L-05 types vs storage | **Cleared.** `BoardTypes` / `WalletTypes` match on-chain layouts. |
| I-03 token-weighted quorum | **Accepted.** Still true. |

Historical criticals from 2026-02-06 (permissionless upgrade, double delegation, ERC-4626 withdraw bypass of delegation locks, `MAX_NODES` hard fill) are **not present**.

---

## Function-by-function notes (compressed)

### Chamber

- `initialize`: zero-address, `seats` in `1..=20`, `_disableInitializers` on the implementation. No ERC-20/721 interface probe (create-time trust).
- `delegate` / `undelegate`: existence via `ownerOf`; share-balance vs `totalHolderDelegations`; evicted nodes skip `_undelegate`. After this PR, `_syncTrackedDelegations` is a no-op when the holder set is complete.
- `setDirectorOperator`: current *contract* owner only; transfer stale-binds the key. Operator cannot replace itself. No expiry/scope (PMN-M04).
- Wallet wrappers: `isDirector` = authorized + top seats + seating mature. Submit validates self-call selectors and ETH balance at submit time only. Execute re-checks live flags, expiry, cancel, and pause (unpause-only while paused). Batch execute uses the same rules per nonce.
- `revokeConfirmation`: authorized owner/session key; not seat-gated (intentional for outgoing seats).
- ERC-4626: `nonReentrant` + `whenNotPaused` on deposit/withdraw; `_decimalsOffset == 3`; `_update` enforces the delegation lock on transfer and burn.
- `upgradeImplementation`: `msg.sender == address(this)` and Chamber owns `ProxyAdmin`. OZ 5.1.0 `ProxyAdmin` is `Ownable` (not two-step); Factory `transferOwnership` completes in the create transaction.
- `acceptAdmin`: intentional no-op.
- `fallback` / `receive`: ETH intake only. Allowed self-call selectors are real functions, so fallback cannot swallow a privileged self-call.

### BoardLib

- Sorted doubly-linked list, `MAX_NODES = 50`, evict tail when the new amount is strictly greater.
- Quorum formula `1 + (seats * 51) / 100` (integer). 1- and 2-seat chambers require all seats.
- Seat updates: snapshot quorum, 7-day execute timelock, supporters re-checked against the current top set, 14-day cancel expiry.
- `refreshSeating`: new top-set tokenIds get `block.number + 1`; incumbents already in `prevTop` are not re-stamped. `isSeatingMature` treats `seatedAt == 0` as mature (post-upgrade incumbents).

### WalletLib

- Submit stores hash always; full bytes only when `target == self`. Auto-confirms the submitter. Deadline `0` becomes `now + 30 days`.
- Execute: CEI (`executed = true` before `call`, cleared on failure); payload verified against `dataHash`.
- Cancel votes are sticky per `tokenId` until Chamber’s live recount.

### Factory / Registry

- Same proxy construction: `TransparentUpgradeableProxy` + `ProxyAdmin` ownership to the chamber.
- Factory: no enumerable directory; `ChamberCreated` includes `creator`. Owner retargets future deploys only.
- Registry: deprecated create + paginated indexes; parent/child when `erc20Token` is already a registered chamber. Dual implementation pointer (PMN-M03).

---

## What this review could not prove

- Formal invariants of the linked list under every insert/swap/evict interleaving (fuzz/unit coverage exists; Halmos symbolic tests were not re-run here).
- Whether any *specific* Ethereum membership collection is soulbound, paused, or listed on an NFT flash-loan venue. The README lists a mainnet membership token address; this review does not assert its transfer or market properties.
- Economic cost to assemble `quorum` seated NFTs or enough share weight to stay in the top set after a 1-block delay.
- That Factory/Registry admin keys will be a timelock or Safe at Ethereum deploy time (Sepolia “Team Multisig” is recorded in the README; Ethereum Factory is not deployed in-repo).
- Off-chain retention of hash-only wallet calldata (L-04 residual is operational).
- Behavior of every non-standard ERC-20/721 (`ownerOf` with side effects, rebasing, missing returns). Create-time asset choice remains a deployer responsibility.
- Storage compatibility of a future Chamber implementation beyond the current ERC-7201 namespaces.
- Slither was not run. Foundry (excluding symbolic): Chamber/Board/Wallet/Factory unit tests, vault tests, and `test/findings/*` used in this PR — **320 passed** on the `1.1.7` tree (`test/{unit/Chamber*.sol,unit/Vault.t.sol,unit/Wallet.t.sol,unit/Board.t.sol,unit/Factory.t.sol,findings/*.sol}`).
- Teamshared memory tools were unavailable (`teamshared` namespace exposed zero tools). GitHub issues filed: [#208](https://github.com/loreum-org/chamber/issues/208) (H01), [#209](https://github.com/loreum-org/chamber/issues/209) (M01), [#210](https://github.com/loreum-org/chamber/issues/210) (M02), [#211](https://github.com/loreum-org/chamber/issues/211) (M03), [#212](https://github.com/loreum-org/chamber/issues/212) (M04). Assignee `xhad` could not be set (integration lacks `replaceActorsForAssignable`); each issue body asks for that assign.

---

## Mainnet deploy blocked until

These items remain **high** or are **medium** with a realistic Ethereum liveness/integrity impact if left as “fix later”:

1. **PMN-H01 (high) — still open** ([#208](https://github.com/loreum-org/chamber/issues/208)). Either implement owner-change seating + flag binding, or record an explicit product acceptance: membership NFTs used on Ethereum must not be flash-loanable / freely transferable into a same-transaction control path, and transferring a seated NFT is transferring a live signer (including inherited confirm/cancel flags). A 1-block `tokenId` delay is not that acceptance by itself.
2. **PMN-H02 (high) — remediated in this PR for the hot path.** Do not deploy `1.1.6` if the eviction index can grow. Deploy `1.1.7` (or later) that skips complete-set sync walks. Residual storage growth (PMN-L06) is not a deploy blocker.
3. **PMN-M01 (medium) — still open** ([#209](https://github.com/loreum-org/chamber/issues/209)) for chambers that can be underfilled or inert-seated. Do not create an Ethereum chamber whose `seats` (and therefore quorum) can exceed the number of membership tokens that will actually be held by callable directors. Prefer a seat count where a minority cannot freeze the wallet by making their own seats inert while keeping rank. Document a recovery plan before pause is used in anger (pause plus unreachable quorum is a permanent vault lock).
4. **PMN-M02 (medium) — still open** ([#210](https://github.com/loreum-org/chamber/issues/210)). Same cluster as M01/H01: burned or uncallable seated tokens must not keep spend flags or occupy seats indefinitely.
5. **PMN-M03 (medium) — operational blocker** ([#211](https://github.com/loreum-org/chamber/issues/211)). Ethereum create must use Factory only, with a reviewed implementation and a non-EOA owner policy. Do not leave Registry `createChamber` as an accidental second implementation pointer.

**Not blockers** (do not hold the deploy by themselves): PMN-M04 ([#212](https://github.com/loreum-org/chamber/issues/212), session-key hygiene; document and operate), PMN-L01–L10, PMN-I01–I06, accepted I-03.

**Do not merge this review as a substitute for the H01/M01/M02/M03 work.** This PR is the report plus the H02 hot-path fix only.

---

## Localized fix in this PR

`_syncTrackedDelegations` now returns immediately when the per-holder enumerable set already accounts for `totalHolderDelegations`. Fresh `delegate` / `undelegate` traffic never walks `evictedTokenIds`. Post-upgrade holders with leftover mapping amounts still backfill once (M-03 tests remain green). Tests: `contracts/test/findings/Finding_PMN_H02_EvictedSetHotPath.t.sol`.
