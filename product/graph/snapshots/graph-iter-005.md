# Loreum Chamber — discovery graph

> **CORPUS HEALTH: DEVELOPING.** Twenty sources: competitive research (17),
> product review tickets (1), positioning memos (2). Iteration 5: Bermuda
> Safe-native privacy / private multisig (Koeppelmann posts + bermudabay.xyz).
> Still **zero user interviews**. Mechanical 20-source / 3-type bar would read
> as rich; health stays developing because the corpus is still interview-less.

Generated 2026-09-11. Sources: 20. Types: research, ticket, memo.
Nodes: 118 · Edges: 74 · Assumptions: 15.

## Competitors (19)

| Competitor | Iter | Notes |
|---|---|---|
| Gnosis Safe | seed | Incumbent custody ($100B+ cited iter 4); Bermuda now **supports** this node |
| Tally | 1–3 | Governor UI; $25B+ delegated (iter 4) |
| OpenZeppelin Governor | 3 | Token DAO baseline |
| Commonwealth | 3 | Forum + Snapshot + onchain UI |
| Parcel | 3 | Safe payroll/ops layer; Bermuda **competes-with** on payroll |
| Aragon, Snapshot | 1 | Full-stack / offchain signaling (18k+ DAOs) |
| Colony, Hats, Karpatkey | 1–2 | Dynamic authority / reputation |
| Llama, Moloch/Baal | 2 | Policy / ragequit |
| Nouns, Agent Bravo, ERC-8004 | seed–2 | NFT / agent patterns |
| Boardroom, Karma | 4 | Governor analytics segment |
| Zodiac Reality (SafeSnap) | 4 | Snapshot→Safe execution bridge |
| **Bermuda** | **5** | Safe-native privacy pool / private multisig (quoted; competitor-adjacent) |

## Iteration 5 headline

**Safe stack gained a quoted privacy layer.** Martin Köppelmann (Gnosis
co-founder; Bermuda advisor — speaker identity, not a Chamber decision)
calls Bermuda “the first privacy solution that works fully with Safe,” with
privacy-pool funds “truly controlled by a Safe.” Bermuda’s site: drop-in
privacy/compliance on existing EVM, “Works with Safe multisig,” and
“Treasuries & DAOs” / payroll in the built-for list.

Chamber implications are **Assumptions only** (privacy-on-Safe displaces
Chamber; private payroll closes the Parcel-shaped ops gap; Safe-native
privacy reduces Chamber differentiation). A `contradicts` edge holds the
tension between Bermuda-as-Safe-layer and Chamber’s sourced need for
**rules that update onchain** as power shifts — not a resolved pick.

## 2026 competitive landscape (four segments)

| Segment | Leaders | Chamber contrast |
|---|---|---|
| Treasury custody | Safe | Native vault + queue |
| Offchain signaling | Snapshot (18k+ DAOs) | Native execution, no signaling |
| Governor contracts + UI | OZ Governor + Tally/Boardroom | NFT board ≠ token delegation |
| Full-stack creation | Aragon, Colony | Narrower treasury focus |
| Dynamic signers | Hats Signer Gate | Monolithic vs Safe+module |
| Coordination UX | Commonwealth | Queue-focused app |
| Treasury ops | Parcel, Llama | No payroll/policy layer |
| **Private Safe / compliant privacy** | **Bermuda (iter 5)** | **Not a Chamber feature; Assumption if this displaces** |

## Segment map

| Segment | Typical stack | Chamber fit |
|---|---|---|
| Token protocol DAO | OZ Governor + Tally + Safe | Low |
| Nouns Builder / NFT community | Safe + Hats + JokeRace/Snapshot | Medium (adjacent, different arch) |
| Founder multisig → rules | Safe modules OR greenfield Chamber | High |
| Treasuries & DAOs wanting privacy (Bermuda-named) | Safe + Bermuda (quoted marketing) | Unvalidated — Assumption |

## Bermuda / Safe-privacy nodes (iter 5)

Quoted only. Distinct source claims kept distinct (`supports` / `contradicts`
instead of merge).

| Type | Label | Provenance sources |
|---|---|---|
| Person | Martin Köppelmann | 1 (advisor quote) |
| Competitor | Bermuda | 2 (Koeppelmann + site) |
| Feature | Safe-controlled privacy pool | 1 |
| Feature | Private multisig (txs, payroll, DeFi) | 1 (two quotes, same file) |
| Feature | Drop-in layer; shielded accounts; stealth addresses; policy engine; atomic settlement; smart-account native; compliant privacy | 1 (site) |
| Segment | Treasuries & DAOs; wallets/institutions/EVM apps | 1 (site) |
| Pain | Every onchain transfer is public | 1 (site) |
| Need | Compliant privacy on existing rails | 1 (site) |
| Insight | First Safe-native privacy; pool tied to Safe recovery; drop-in not new custody; names treasury+payroll | 1–2 |
| Assumption | Privacy-on-Safe displaces Chamber; closes ops gap; reduces Safe-stack differentiation | 0 |

## Assumptions (15)

See `knowledge/assumption-audit/2026-07-01-iter-4.md` for the prior 12, and
`knowledge/assumption-audit/2026-09-11-bermuda-safe-privacy.md` for **new**
iter-5 items ranked by decision-at-risk.

New in iter 5 (zero provenance; risk on each node):

- Privacy-on-Safe displaces Chamber for DAO treasuries that want privacy
- Bermuda private payroll/treasury ops close Chamber's Safe-ops gap vs Parcel
- Safe-native privacy reduces Chamber's differentiation versus the Safe stack

Prior load-bearing (unchanged; still uninterviewed):

- Teams needing dynamic signers will choose Chamber over Hats Signer Gate + Safe
- Nouns Builder DAOs will choose Chamber over Safe+Hats
- Treasury teams prefer market-driven NFT boards over fixed signers
- Chamber target segment will not default to OZ Governor + Tally
- Target buyers reject Snapshot execution gap enough to prefer Chamber's native queue
