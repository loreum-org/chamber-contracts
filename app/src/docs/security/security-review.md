# Security review (methodology)

> **Audience:** auditors and developers running structured reviews. Product users should rely on published audit reports and **[What is a Chamber?](../introduction/overview.md)** for trust assumptions.

Chamber’s **trust surface** is the Solidity in **`contracts/src/`** (`Factory`, `Chamber`, `Board`, `Wallet`, leftover `Registry`). This page summarizes how to review it systematically.

## What to protect

- **Vault funds** — ERC‑4626 shares and underlying assets.  
- **Governance integrity** — delegation, seat ranking, quorum, proposal lifecycle.  
- **Upgrade path** — ProxyAdmin + `upgradeImplementation` only through controlled queue rules.

## Review phases

1. **Architecture** — inheritance, storage slots, Factory → Chamber deploy path.  
2. **Per-function analysis** — access control, reentrancy, arithmetic, external calls.  
3. **Cross-contract** — delegation vs transfers, stale confirmations, owner / session-key director auth.  
4. **Tooling** — Slither, Foundry tests/fuzz, manual threat modeling.

## Common question areas

| Topic | Why it matters |
|--------|----------------|
| Delegation vs share transfers | Prevent double-use of voting weight |
| Quorum on execute | Confirmations must match live director policy |
| Token-weighted quorum (I-03) | `isDirector` and confirmations are per `tokenId`. One address holding `quorum` top-seat NFTs is a single-actor treasury — intended, not 1-address-1-vote. |
| Calldata hashing | Execution must not accept mismatched payloads |
| Seat updates | Timelock + still-director supporters |
| Upgrade self-calls | Only sanctioned upgrade selector to Chamber |

## Methodology detail

The full checklist (Slither, Aderyn, Mythril, Halmos, Forge coverage, Solhint, manual review) lives in the repo skill **`docs/skills/security-review-skill.md`** for agents and auditors running deep passes.

## Read next

- **[Design notes](../protocol/design-notes.md)**  
- **[Architecture](../protocol/architecture.md)**  
- **[API reference](../reference/api-reference.md)**  
