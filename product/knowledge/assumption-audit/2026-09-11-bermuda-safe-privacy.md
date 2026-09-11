# Assumption audit — Bermuda Safe-native privacy (2026-09-11)

## Health context

Corpus **developing**: 20 sources (+2 this addition). Types remain research,
ticket, memo — still **zero buyer interviews**. Assumptions: **15** (+3 new).
This writeup ranks **new** zero-provenance and single-source claims from the
Bermuda / Koeppelmann addition by **decision-at-risk** for Chamber (positioning
vs Safe; treasury ops; privacy). It does **not** resolve them or invent product
decisions. Prior assumptions stay as ranked in
`2026-07-01-iter-4.md` (listed again below so none are skipped).

## Assumptions (zero provenance)

### High (new)

1. **Privacy-on-Safe displaces Chamber for DAO treasuries that want privacy.**
   - Decision at risk: whether Chamber’s public “why not multisig” story still
     holds once Safe can hold a **privacy pool** with the same recovery path.
   - Voiced as graphify Assumption from Koeppelmann’s Safe-control quote — no
     buyer evidence that privacy is the job Chamber was winning (or losing).

2. **Safe-native privacy reduces Chamber’s differentiation versus the Safe stack.**
   - Decision at risk: positioning vs Safe as custody incumbent — if “modern
     Safe” is read as private + compliant + modular, Chamber still has to prove
     the board/queue wedge; this file does not decide that.
   - Voiced internally at graphify from Bermuda “Works with Safe multisig”
     plus existing Safe-incumbent corpus.

### Medium (new)

3. **Bermuda private payroll / treasury ops close Chamber’s Safe-ops gap vs Parcel.**
   - Decision at risk: treasury-ops prioritization — Chamber already lacks a
     payroll/policy layer (Parcel research). A Safe-native **private** payroll
     path may further weaken ops-JTBD pull. Not a build/buy decision.
   - Voiced internally from Bermuda “payroll” + “Treasuries & DAOs” copy.

### Prior assumptions (unchanged rank from iter 4 — not re-resolved)

High: dynamic signers prefer Chamber over Hats+Safe; Nouns Builder chooses
Chamber over Safe+Hats; NFT boards over fixed signers; segment will not default
to OZ Governor+Tally; buyers reject Snapshot execution gap.

Medium: build coordination UX vs partner; win without modules; native queue
security advantage; agents as directors; ragequit needed; ERC-8004 drives choice.

Also still present in the graph (iter 1–3, not re-ranked here): delegation
leaderboard is intuitive.

## Single-source claims (one provenance entry) — new this addition

### High

- **Bermuda is the first privacy solution that works fully with Safe.**
  - Decision at risk: competitive map of Safe-adjacent privacy — if the “first”
    claim is marketing-only, the landscape may already include other
    Safe-compatible privacy tools.
  - Source: `2026-09-11-koeppelmann-bermuda-safe-privacy.md` (Köppelmann).
  - Triangulate: independent privacy-protocol inventory vs Safe accounts, or
    Bermuda docs/audit — not a Chamber interview.

- **Privacy-pool funds are truly controlled by the Safe (access/recover Safe ⇒ access funds).**
  - Decision at risk: how strongly Chamber treats Bermuda as *Safe-native*
    (same custody trust) vs a bolted-on pool with a different recovery story.
  - Source: same Köppelmann post.
  - Triangulate: Bermuda docs or a Safe-recovery walkthrough from a user.

### Medium

- **Bermuda private-multisig beta covers private transactions, payroll, and other DeFi on EVM.**
  - Decision at risk: treasury-ops adjacency (payroll already a Parcel theme).
  - Source: @bermudabayzk announcement in the same capture file.
  - Triangulate: live beta surface or docs.bermudabay.xyz use-case list.

- **Drop-in layer: no contract changes, no new chain; works with Safe / passkeys / EOA.**
  - Decision at risk: whether Bermuda is a *stack extender* (supports Safe) or
    a substitute custody product (it is not quoted as the latter).
  - Source: `2026-09-11-bermuda-bay-product-surface.md`.
  - Triangulate: integration docs / SDK behavior on a Safe.

- **Named audience includes Treasuries & DAOs, Payroll, and “Institutional rails, private by default.”**
  - Decision at risk: whether Chamber’s DAO-treasury ICP overlaps Bermuda’s
    marketed ICP enough to treat Bermuda as competitor-adjacent (already how
    the graph codes it).
  - Source: bermudabay.xyz capture.
  - Triangulate: Bermuda sales/docs language for DAOs vs wallets/issuers.

### Low

- Shielded accounts, stealth addresses, policy engine, atomic settlement
  (four site cards). Decision at risk is low for Chamber unless privacy or
  settlement becomes a Chamber claim — the corpus does not make that claim.
- Köppelmann is advising Bermuda (speaker fact). Low for product; relevant
  only as Safe-ecosystem signal.

## Triage recommendation

Next validation cycle should treat **privacy-on-Safe displacement** and
**Safe-stack differentiation** as the Highs — they sit on Chamber’s existing
positioning vs Safe, not on a new Chamber feature. Do not resolve them into a
roadmap. A second source that is *not* Bermuda marketing (buyer: would a
treasury pick private Safe over Chamber’s queue/board?) would triangulate;
that interview is still missing. Payroll/ops overlap is Medium and already
rhymes with the Parcel gap.

the team will plan against whatever it does not question. these are the things to question first.
