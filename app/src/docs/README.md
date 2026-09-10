# Loreum Chamber docs

These pages explain **what a Chamber is**, **how it works**, and **why you might use one instead of a normal multisig treasury** (for example Gnosis Safe). They are written for newcomers — you do not need to be a Solidity developer to follow the introduction and protocol sections.

Open the docs in the app at **`/docs`**. Start here:

## Recommended reading order (new users)

1. **[What is a Chamber?](./introduction/overview.md)** — the idea in one sitting  
2. **[Why not just a multisig?](./introduction/why-not-multisig.md)** — Chamber vs a classic treasury wallet  
3. **[Founder exit via Chamber](./introduction/founder-exit.md)** — gradual operational handoff while retaining token stake  
4. **[Chambers and Sub-Chambers](./introduction/chamber-and-sub-chambers.md)** — what Create deploys; nested chambers as a contemplated pattern  
5. **[Getting started](./introduction/getting-started.md)** — connect a wallet and use the app  

Then, as you need detail:

| Topic | Page |
|--------|------|
| How voting and seats work | **[Governance](./protocol/governance.md)** |
| How the treasury (vault) works | **[Vault](./protocol/vaults.md)** |
| How spending proposals work | **[Treasury actions](./protocol/multisig.md)** |
| Where each screen lives | **[App routes](./guides/app-routes.md)** |

## For builders and auditors

| Topic | Page |
|--------|------|
| Design goals | **[Vision](./protocol/vision.md)** |
| Contracts and Factory | **[Architecture](./protocol/architecture.md)** |
| Limits and implementation notes | **[Design notes](./protocol/design-notes.md)** |
| Who may act for a director NFT | **[Director authorization](./protocol/director-authorization.md)** |
| Deploy with Foundry | **[Deployment](./guides/deployment.md)** |
| Function list | **[API reference](./reference/api-reference.md)** |
| Flow diagrams | **[Sequence diagrams](./reference/sequence-diagrams.md)** |
| Security review methodology | **[Security review](./security/security-review.md)** |

## Full protocol paper

The long-form **[Chamber Protocol whitepaper](https://loreum.org/whitepaper)** on [loreum.org](https://loreum.org) goes deeper on design intent and formal framing. The in-app docs focus on **everyday use** and **plain-language mechanics**.
