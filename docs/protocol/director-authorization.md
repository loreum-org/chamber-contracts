# Director authorization

This is the caller policy for membership-NFT director actions after M-01
([#116](https://github.com/loreum-org/chamber/issues/116) /
[#143](https://github.com/loreum-org/chamber/issues/143)).
It does **not** reopen the pre-M-01 ERC-1271 `DirectorAuth` helper.

## Callers that may act for a membership NFT

For `tokenId`, Chamber authorizes `msg.sender` if and only if one of the
following holds.

### 1. NFT owner (EOA or contract wallet)

`msg.sender == IERC721.ownerOf(tokenId)`.

The owner acts only as itself. A Safe, ERC-4337 account, or other contract
wallet that **holds** the membership NFT may submit, confirm, execute, or
revoke when that wallet contract is `msg.sender` (for example a Safe
`execTransaction` or a 4337 account `execute` that calls Chamber).

This is the M-01 rule. It is unchanged.

### 2. Session key (the only approved operator path)

All of the following must hold:

- The current NFT owner is a **contract** (`owner.code.length > 0`).
- That owner previously called
  `setDirectorOperator(tokenId, operator, expiry, scope)` while it was
  `ownerOf(tokenId)` and `msg.sender` (the wallet must register the key
  itself).
- The stored session is still bound to the **current** owner. Transferring the
  NFT invalidates the key. Transfer also resets that tokenId's seating clock
  (`SEATING_DELAY`); call `syncSeating(tokenId)` so the new checkpoint is stored
  (a reverting director call does not persist it). Confirm/cancel bits recorded
  under the previous owner are ignored for quorum and execute (PMN-H01 Solution A).
- `msg.sender == operator` and `operator != address(0)`.
- `block.timestamp <= expiry`. `expiry == 0` is rejected at set and is not live
  if leftover in storage (PMN-M04 A). This is not a no-expiry sentinel.
- `scope` allows the Chamber entry point being called, or is the explicit
  unscoped sentinel `type(uint32).max` (`SESSION_SCOPE_UNSCOPED`). Scope `0`
  is rejected at set and grants no actions (PMN-M04 B).
- For `confirm*` / `execute*` (including `executeSeatsUpdate`),
  `block.number >= liveAt`, where `liveAt` is `block.number + SEATING_DELAY`
  at set time (PMN-M04 C). Submit and seat-propose are not delayed.

A live, in-scope session key may exercise the **token-gated** Chamber actions
its `scope` allows for that `tokenId`: director-gated board and wallet
functions, and `revokeConfirmation` (which is owner-authorized, not seat-gated)
when the revoke bit is set or the key is unscoped. Unscoped is an explicit
owner choice, not a silent default.

The owner may still act as itself (no expiry, scope, or post-set delay). The
owner clears the key by calling `setDirectorOperator(tokenId, address(0), 0, 0)`
and may do so immediately, including during the post-set delay. The owner
refreshes expiry or scope by calling `setDirectorOperator` again (that reset
also restarts `liveAt`). Only the current owner may set or clear the key; the
operator cannot replace itself.

## Public session views

These getters are how callers read the session. They match the rules above.

- `getDirectorOperator(tokenId)` — live operator, or zero if unset, stale,
  expired, EOA-owned, or burned. Does **not** apply `scope` or the
  confirm/execute delay.
- `getDirectorOperatorScope(tokenId)` — `scope` of that live session, or
  `0` if there is no live session. `0` is not unscoped; unscoped is
  `SESSION_SCOPE_UNSCOPED`.
- `getDirectorOperatorLiveAt(tokenId)` — first block the live session may
  confirm or execute (`liveAt`), or `0` if there is no live session.
  Confirm/execute require `block.number >= liveAt`.
- `getDirectorSession(tokenId)` — raw stored `(sessionOwner, operator,
  expiry, scope, liveAt)`. These fields may be stale or expired. Use the
  live getters above for the current key.
- `isTokenAuthorized(tokenId, account)` — NFT owner or live (unexpired)
  session key. Does **not** check board seats, seating delay, `scope`, or
  the confirm/execute delay. Burned tokens return false.

## Callers that may not act

- Any address that is neither the current `ownerOf(tokenId)` nor the live
  session key for that token and owner.
- A contract that would accept an ERC-1271 signature of
  `abi.encode(msg.sender)`, a `DirectorAuth` digest, or any other hash.
  Chamber **never** calls `isValidSignature`.
- Safe modules, ERC-4337 validators, or off-chain session keys that are **not**
  registered with `setDirectorOperator`. Those schemes work only when they
  execute *through* the owner wallet so Chamber sees `msg.sender == owner`
  (rule 1).
- A session key registered by a **previous** owner after the NFT is
  transferred.
- A session key on an **EOA-owned** membership NFT. Registration reverts;
  even a leftover mapping is ignored while `owner.code.length == 0`.
- An **expired** session key (`block.timestamp > expiry`, or stored `expiry == 0`).
- A **scoped** session key calling a Chamber entry point its bitmask does not
  allow (unscoped is only `SESSION_SCOPE_UNSCOPED`).
- A newly set key calling confirm or execute before `SEATING_DELAY` (`liveAt`).

## How a Safe / 4337 / agent uses the session key

1. The wallet that owns the membership NFT submits a transaction whose
   `msg.sender` on Chamber is the wallet (Safe `execTransaction`, 4337
   account execution, or a direct contract call).
2. That call is `setDirectorOperator(tokenId, operator, expiry, scope)`, where
   `operator` is the agent EOA, module address, or other session key the
   owners want to allow, `expiry` is a future unix timestamp, and `scope` is
   a Chamber entry-point bitmask or `SESSION_SCOPE_UNSCOPED`.
3. After `SEATING_DELAY`, `operator` may confirm or execute on Chamber
   directly with that `tokenId` (submit may proceed in the set block if
   scoped to allow it).

This is an explicit Chamber allowlist. It is not EIP-1271, not Safe
`isModuleEnabled`, and not EntryPoint validation.

## Why this does not reopen M-01

The removed path hashed
`abi.encodePacked("DirectorAuth", address(this), tokenId, msg.sender)` and
called `IERC1271.isValidSignature(hash, abi.encode(msg.sender))`. Any owner
contract that returned the 1271 magic for arbitrary data authorized **every**
caller.

The session-key mapping never consults the owner’s signature interface. A
promiscuous 1271 contract cannot impersonate a director unless its owner
explicitly registered that caller with `setDirectorOperator`.
