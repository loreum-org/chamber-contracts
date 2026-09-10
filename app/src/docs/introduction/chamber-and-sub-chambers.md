# Chambers and Sub-Chambers

Create deploys **one Chamber**: a Factory-built ERC‑4626 vault, a liquid-delegated ranked board of membership NFTs, and a quorum wallet. That object is **standalone**. It is not a child of another Chamber, and it does not open a parent↔child tree.

**Sub-Chambers** — nested treasuries with Registry parent↔child wiring — are a **contemplated pattern**, not what Create deploys today. The leftover Registry can still record those links for older deployments. They are not the live architecture.

## What you get from Create

A new Chamber is one proxy address that combines:

- **Vault** — the shared ERC‑4626 pot (deposit the configured token, receive shares).
- **Board** — a ranked leaderboard of membership NFT token IDs; the top seats are directors.
- **Quorum wallet** — directors submit, confirm, and execute outbound actions.

Think of it as the **city council** for your protocol or DAO — cross-cutting decisions and the flagship treasury live on this one object.

## Nested chambers (contemplated)

Large communities sometimes want **more than one wallet**. A contemplated pattern would split responsibility across several Chamber deployments while keeping the same rules **visible onchain**:

| Example mandate | Why a separate Chamber |
|-----------------|------------------------|
| **Treasury** | Grants, payroll, stablecoin policy |
| **Operations** | Vendor payments, infrastructure |
| **R&D** | Experiments, smaller budgets |

Each deployment would still follow **deposit → delegate → directors → quorum → execute**. That structure is **not** what Create wires today. You can deploy more than one Chamber if you want separate pots, but the app does not treat them as parent and child.

## Why people talk about splitting

With a single multisig, every committee shares **one signer list** and **one approval flow**. That encourages either:

- **Too many signers** on one Safe (slow, cluttered), or
- **Hidden committees** that “just use the founder keys” off the record.

Multiple Chambers would make **structure explicit**: different vaults, different seats, different queues — without pretending one informal council represents everyone. Until that nested pattern ships, the live product is **one Factory-deployed Chamber per Create**.

## Registry leftover (not the factory)

An earlier model used the **Registry** as a factory (`createChamber()`, `getAllChambers()`) and recorded **parent ↔ child** when a new Chamber used another Chamber’s share token as its asset.

Create today calls **Factory** `createChamber()`. The Factory does **not** index a world list, does **not** write parent/child tables, and does **not** expose `createAgent()` — that API was never shipped.

You do not need that leftover wiring to use the app. Builders: **[Architecture](../protocol/architecture.md)**.

## Directors can be people, contract wallets, or agents

A **director** is whoever is authorized for a **membership NFT token ID** in a **top seat**:

- **Individual** — an EOA holds the NFT and calls as `msg.sender`.
- **Contract wallet** — a Safe or similar holds the NFT and calls as itself; it may register a **session key** so an operator can act for that token.
- **Agent** — same submit / confirm / execute gates as everyone else. Live auth is the NFT owner as `msg.sender`, or a session key the contract owner registered. Chamber never uses EIP‑1271.

See **[Director authorization](../protocol/director-authorization.md)**. The point is **one rulebook** for every seat type, not a special admin lane.

## Read next

- **[Why not just a multisig?](./why-not-multisig.md)**
- **[Getting started](./getting-started.md)**
- **[Governance](../protocol/governance.md)**
- **[Vision](../protocol/vision.md)** — why the design uses three primitives (vault, board, queue)
