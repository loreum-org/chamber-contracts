# Design notes (advanced)

> **Audience:** integrators, auditors, and developers. New users should read **[What is a Chamber?](../introduction/overview.md)** and **[Governance](./governance.md)** first.

This page records **implementation choices** in `contracts/src/` that explain edge cases and gas tradeoffs.

## One contract per Chamber

Governance and vault logic share **one proxy address** (`TransparentUpgradeableProxy` → `Chamber` implementation). Users interact with a single `Chamber` for deposits, delegation, and the queue.

## Namespaced storage (ERC‑7201)

`Board`, `Wallet`, Chamber delegation fields, and `Registry` use **fixed storage slots** so upgrades are less likely to collide layouts accidentally.

## Board leaderboard

- Delegations accumulate per **membership NFT tokenId** in a **sorted linked list** (by weight, descending).  
- **`MAX_SEATS`** on Chamber: **20**; **`MAX_NODES`** on Board: **50** (more NFTs can exist on the list than active seats).  
- Links are **`uint128`** — token IDs above `2^128-1` cannot be inserted.  
- **`circuitBreaker`** on delegate/undelegate uses **transient storage** (EIP‑1153) to block reentrancy while reordering the list.

## Wallet: hash-only calldata

- Stored per proposal: `target`, `value`, `executed`, `confirmations`, **`bytes32 dataHash`**.  
- Execute paths require matching calldata; **`SubmitTransaction`** events carry full `bytes data` for offchain archives.

## Self-target calls

Calls where `target == Chamber` are limited to **`upgradeImplementation`** selector — arbitrary self-calls are rejected.

## Quorum formula

`getQuorum() = 1 + (getReachableDirectorCount() * 51) / 100` — integer math in Solidity. Empty/inert slots do not inflate the denominator (PMN-M01). One- and two-director boards require all reachable directors.

That count is **token-weighted** (distinct director `tokenId`s). One address holding `quorum` top-seat membership NFTs can satisfy quorum alone — a single-actor treasury. Confirmations are not capped per owner.

## Seat update timelock

`executeSeatsUpdate` requires **7 days** and enough supporters who are **still directors** at execution time.

## Delegation vs transfers

`_update` enforces that share transfers cannot strand delegated weight (see **[Vault](./vaults.md)**).

## NFT intake

- `onERC721Received` accepts **any** ERC-721 collection. This is intentional treasury custody, not a membership gate. Receiving an NFT does not mint shares or affect delegation.
- Directors transfer received ERC-721s out via the wallet (`executeTransaction` targeting the collection).
- Chamber does **not** implement `IERC1155Receiver`. ERC-1155 `safeTransferFrom` / `safeBatchTransferFrom` to the Chamber revert.
- `test_Chamber_ReceiveERC721` sends a **non-membership** collection to the Chamber to lock this intent.

## Further reading

- **[API reference](../reference/api-reference.md)**  
- **[Sequence diagrams](../reference/sequence-diagrams.md)**  
- **[Security review](../security/security-review.md)**  
