# Contract API reference

> **Audience:** developers integrating with or auditing contracts. New users should start with **[What is a Chamber?](../introduction/overview.md)** and **[Governance](../protocol/governance.md)**.

Generated from interfaces in `contracts/src/` (`Factory` / `IFactory`, leftover `Registry`, `Chamber` / `IChamber`, plus **`IWallet`**, **`IBoard`**, **`IERC4626`**). Prefer NatSpec in-repo for exact wording.

## `Factory`

Thin, non-proxy deployer (`contracts/src/Factory.sol`). Constructor pins the **Chamber implementation** and **owner**. Create today uses this path. There is no **`createAgent()`**. The Factory does **not** store a world list or parent/child tables.

### Write

| Function | Notes |
|---------|--------|
| **`createChamber(address erc20Token, address erc721Token, uint256 seats, string name, string symbol) → address payable chamber`** | Deploys **Chamber `TransparentUpgradeableProxy`**, runs **`Chamber.initialize`**, transfers **ProxyAdmin ownership to `chamber`**. Reverts on zero addresses, `implementation == 0`, or invalid **seats** (must be **1–20**). `erc20Token` must be a **standard ERC-20** (no factory allowlist; fee-on-transfer / rebasing unsupported). |
| **`setImplementation(address newImplementation)`** | **Owner only**; updates pointer for **future** `createChamber` only. Same-address updates are a no-op. |

### Read

| Function | Returns |
|---------|---------|
| **`implementation()`** | Chamber logic for the next proxy. |

### Events / errors

- **`ChamberCreated(chamber, asset, nft, seats, name, symbol, creator)`**
- **`ChamberImplementationUpdated(previous, newImplementation)`**
- **`ZeroAddress()`**, **`InvalidSeats()`**

---

## `Registry` (leftover)

Historical factory + enumerable index. Not the live Create path when Factory is configured. Upgradeable registry behind a **`TransparentUpgradeableProxy`** (`contracts/test/utils/DeployRegistry.sol`). `Registry.initialize` pins the **Chamber implementation** and grants **`DEFAULT_ADMIN_ROLE`** and **`ADMIN_ROLE`** to `admin`. Parent/child getters describe leftover Registry wiring, not Factory Create.

### Write

| Function | Notes |
|---------|--------|
| **`initialize(address _implementation, address admin)`** | One-time; stores implementation address and `admin`; reverts `ZeroAddress`. |
| **`setChamberImplementation(address newImplementation)`** | **`ADMIN_ROLE` only**; updates pointer for **future** `createChamber` only. |
| **`createChamber(address erc20Token, address erc721Token, uint256 seats, string name, string symbol) → address payable chamber`** | Deploys **Chamber `TransparentUpgradeableProxy`**, runs **`Chamber.initialize`**, registers listing, transfers **ProxyAdmin ownership to `chamber`**. Reverts on zero addresses, `implementation == 0`, or invalid **seats** (must be **1–20**). If `isChamber(erc20Token)`, sets **parent** / **child** links. `erc20Token` must be a **standard ERC-20** (no factory allowlist; fee-on-transfer / rebasing unsupported). |

### Read

| Function | Returns |
|---------|---------|
| **`implementation()`** | Pinned Chamber logic for new proxies. |
| **`proxyAdmin()`** | **`admin` argument from `initialize`** (namesake is historical; **not** `Chamber.getProxyAdmin()`). |
| **`ADMIN_ROLE`**, **`DEFAULT_ADMIN_ROLE`** | OpenZeppelin access control. |
| **`getAllChambers()`, `getChamberCount()`** | Global index. |
| **`getChambers(uint256 limit, uint256 skip)`** | Pagination over `chambers`. |
| **`isChamber(address)`** | Registry membership flag. |
| **`getAssets()`** | Distinct underlying ERC‑20s observed. |
| **`getChambersByAsset(address asset)`** | Chambers using that asset. |
| **`getParentChamber(address chamber)`** | Sub-chamber → parent, or `address(0)`. |
| **`getChildChambers(address chamber)`** | Parent → children. |

### Events / errors

- **`ChamberCreated(chamber, seats, name, symbol, erc20Token, erc721Token)`**  
- **`ChamberImplementationUpdated(previous, newImplementation)`**  
- **`ZeroAddress()`**, **`InvalidSeats()`**

---

## `Chamber` (`IChamber`)

Single proxy instance per organization. **`VERSION`** is a public **`bytes32`** constant (semantic version string inlined at compile time).

### Initialization

**`initialize(address erc20Token, address erc721Token, uint256 seats, string name, string symbol)`**  
`initializer`: sets ERC‑4626 asset, ERC‑20 metadata, reentrancy guard, membership NFT, **`_setSeats(0, seats)`** initial seat count. Constraints: non-zero tokens; **`1 ≤ seats ≤ 20`**.

### ERC‑4626 / ERC‑20 (high level)

Standard **`deposit` / `mint` / `withdraw` / `redeem`** with OpenZeppelin ERC‑4626 behavior. Vault assets must be **standard ERC‑20**; `deposit`/`mint` revert **`AssetAmountMismatch`** if the observed `balanceOf` delta is not the requested amount (fee-on-transfer). Transfers and withdrawals enforce **non-underflow vs `totalHolderDelegations`** (**`ExceedsDelegatedAmount`**). ERC‑20 **`transfer`/`transferFrom`** disallow zero amount and zero **to** (**`ZeroAmount`**, **`TransferToZeroAddress`**).

Public ETH / NFT receive: **`receive`**, **`fallback`**, **`onERC721Received`**.

`onERC721Received` accepts **any** ERC-721 collection (treasury custody; not a membership whitelist). Receipt does not mint shares. There is **no** `onERC1155Received` — ERC-1155 `safeTransferFrom` to Chamber reverts. Directors transfer received ERC-721s out via the wallet queue.

### Delegation

| Function | Role |
|---------|------|
| **`delegate(uint256 tokenId, uint256 amount)`** | Updates `holderDelegation` and board; requires share balance; NFT must exist (**`InvalidTokenId`** on `ownerOf` failure). |
| **`undelegate(uint256 tokenId, uint256 amount)`** | Reduces holder maps; updates board if node still present. |
| **`getDelegations(address holder) → (uint256[] tokenIds, uint256[] amounts)`** | Scans board list for this holder’s positive weights. |
| **`getHolderDelegation(address holder, uint256 tokenId)`** | Single cell. |
| **`getTotalHolderDelegations(address holder)`** | Aggregate. |

### Board

| Function | Role |
|---------|------|
| **`getMember(tokenId)`** | Node tuple (`tokenId`, `amount`, `next`, `prev`). |
| **`getTop(uint256 count)`** | Token IDs + amounts, descending. |
| **`getSize()`** | Linked-list node count. |
| **`getQuorum()`** | `1 + (seats * 51) / 100` distinct director `tokenId`s (token-weighted, not 1-address-1-vote). One- and two-seat chambers require all seats. |
| **`getSeats()`** | Seat count. |
| **`getDirectors()`** | **`ownerOf`** for each top **`getSeats()`** token ID; `address(0)` on failure. |
| **`setDirectorOperator(tokenId, operator)`** | Contract NFT owner registers or clears the session key. No ERC-1271. |
| **`getDirectorOperator(tokenId)`** | Live session key, or zero if unset / stale / EOA-owned. |
| **`isTokenAuthorized(tokenId, account)`** | Owner or live session key (does not check seats). |
| **`updateSeats(uint256 tokenId, uint256 numOfSeats)`** | Director-only seat proposal / support. |
| **`executeSeatsUpdate(uint256 tokenId)`** | Director-only; **7-day** timelock + supporter validation. |
| **`getSeatUpdate()`** | `(proposedSeats, timestamp, requiredQuorum, supporters)`. |

### Wallet multisig

All director-gated with **`isDirector(tokenId)`** and **`nonReentrant`** where marked on `Chamber`. Directorship and confirmations are **per membership token**, so one address holding **`quorum`** top-seat NFTs is a **single-actor treasury**.

| Function | Role |
|---------|------|
| **`submitTransaction(tokenId, target, value, data)`** | Validates target/value (see below); stores **`keccak256(data)`**; also stores full bytes for self-calls (`upgradeImplementation`); auto-confirms submitter. |
| **`submitTransactionWithMetadata(..., string metadataURI)`** | Same + optional durable URI / hash string. |
| **`confirmTransaction(tokenId, transactionId)`** | Increments confirmations if not cancelled / executed / duplicate. |
| **`revokeConfirmation(tokenId, transactionId)`** | Removes this director’s confirmation when allowed. |
| **`executeTransaction(tokenId, transactionId, bytes calldata data)`** | Requires quorum; verifies hash; empty `data` uses stored self-call bytes. |
| **`cancelTransaction(tokenId, transactionId)`** | Cancels after quorum cancel votes. |
| **`submitBatchTransactions(tokenId, targets[], values[], data[])`** | Same constraints per row; **`Σ values ≤ address(this).balance`** check for ETH. |
| **`confirmBatchTransactions(tokenId, transactionIds[])`** | Batched confirms. |
| **`executeBatchTransactions(tokenId, transactionIds[], bytes[] calldata data)`** | Parallel arrays; per-tx hash check. |

Transaction validation (single and batch): **`target != address(0)`**. If **`target == address(this)`**, calldata selector must be **`upgradeImplementation(address,bytes)`**. **`value`** cannot exceed native balance.

Read helpers: **`getTransactionCount`**, **`getNextTransactionId`**, **`getTransaction(nonce)`** → **`(..., dataHash)`**, **`getTransactionMetadata`**, **`getTransactionCalldata`**, **`getConfirmation`**, **`getCancelled`**, **`getCancelConfirmation`**, **`getCancelConfirmations`**.

### Proxy upgrades

| Function | Role |
|---------|------|
| **`getProxyAdmin() → address`** | Reads ERC‑1967 admin slot (OZ **ProxyAdmin** contract). |
| **`upgradeImplementation(address newImplementation, bytes calldata data)`** | Requires **`msg.sender == address(this)`** (e.g. via **`executeTransaction`**); **`ProxyAdmin.owner() == address(this)`**; invokes **`upgradeAndCall`**. |
| **`acceptAdmin()`** | No-op; Factory (or leftover Registry) transfers ProxyAdmin ownership directly. |

---

## Events (high-signal)

From **`IChamber`** / **`IBoard`** / **`IWallet`** / **`IFactory`** / leftover **`IRegistry`** (non-exhaustive):

- **Delegation / board:** `DelegationUpdated`, `Delegate`, `Undelegate`, `SetSeats`, `SeatUpdateCancelled`, `ExecuteSetSeats`  
- **Wallet:** `SubmitTransaction`, `ProposalMetadataSet`, `ConfirmTransaction`, `RevokeConfirmation`, `ExecuteTransaction`, `CancelTransaction`, `TransactionCancelled`  
- **Chamber-level wallet wraps:** `TransactionSubmitted`, `TransactionConfirmed`, `TransactionExecuted`, `TransactionCancelVoted`  
- **Treasury receive:** `Received`, `ReceivedERC721`  
- **Factory / leftover Registry:** `ChamberCreated`, `ChamberImplementationUpdated`  

---

## Representative errors

| Area | Examples |
|------|-----------|
| Factory / leftover Registry | `ZeroAddress`, `InvalidSeats` |
| Chamber / IChamber | `InsufficientChamberBalance`, `ExceedsDelegatedAmount`, `AssetAmountMismatch`, `NotDirector`, `NotEnoughConfirmations`, `InvalidTransaction`, `NotAuthorized`, seat / token errors |
| Board | `CircuitBreakerActive`, `TokenIdTooLarge`, `MaxNodesReached`, seat proposal / timelock errors |
| Wallet / IWallet | `TransactionDoesNotExist`, `TransactionAlreadyExecuted`, `TransactionAlreadyConfirmed`, `TransactionNotConfirmed`, `TransactionAlreadyCancelled`, `DataHashMismatch`, `TransactionFailed`, `InvalidTarget` |

See interface files for full enumerations.

---

## Minimal integration checklist

1. Discover **`Factory`** address for your chain.  
2. Enumerate chambers via **`ChamberCreated`** logs, indexer, or leftover Registry **`getChambers`**.  
3. For a Chamber: read **`asset()`**, **`nft()`**, **`getSeats()`, `getQuorum()`, `getTop`/`getDirectors`**.  
4. For wallets / indexers: subscribe to **`SubmitTransaction`** to persist **`bytes data`** alongside **`nonce`**.  
5. For execution UI: reconstruct calldata matching stored hash before calling **`executeTransaction`**.  
