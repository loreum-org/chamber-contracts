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
- That owner previously called `setDirectorOperator(tokenId, operator)` while
  it was `ownerOf(tokenId)` and `msg.sender` (the wallet must register the key
  itself).
- The stored session is still bound to the **current** owner. Transferring the
  NFT invalidates the key.
- `msg.sender == operator` and `operator != address(0)`.

A session key may exercise the same **token-gated** Chamber actions as the
owner for that `tokenId`: director-gated board and wallet functions, and
`revokeConfirmation` (which is owner-authorized, not seat-gated).

Confirm and cancel bits count toward execute only while `ownerOf` succeeds
and the recorded controller still matches (PMN-H01 A, PMN-M02 A). Burned
tokens are skipped. A control change to an owner with no live session key
drops the prior bits. `cleanupInertSeat(tokenId)` drops a burned id from the
top set; later `refreshSeating` does not put it back while it stays inert
(PMN-M02 Solution B).

The owner may still act as itself. The owner clears the key by calling
`setDirectorOperator(tokenId, address(0))`. Only the current owner may set or
clear the key; the operator cannot replace itself.

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

## How a Safe / 4337 / agent uses the session key

1. The wallet that owns the membership NFT submits a transaction whose
   `msg.sender` on Chamber is the wallet (Safe `execTransaction`, 4337
   account execution, or a direct contract call).
2. That call is `setDirectorOperator(tokenId, operator)`, where `operator` is
   the agent EOA, module address, or other session key the owners want to
   allow.
3. `operator` may then call Chamber directly with that `tokenId`.

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
