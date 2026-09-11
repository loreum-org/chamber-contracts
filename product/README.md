# product/ — Loreum Chamber product planning (mogkit workspace)

A [mogkit](https://github.com/Waddling-Penguin/mogkit) PM workspace for planning
**Loreum Chamber**. mogkit playbooks (stored in teamshared under the `mogkit`
tag) turn raw research into an evidence graph and interrogate it — surfacing
what's supported, what's assumed, and what to validate next.

Fetch a playbook: `memory_skill_get(name="graphify")` via the teamshared MCP.

## Layout

```
product/
├── sources/      raw research (one file per artifact); graphify reads these
├── engine/
│   └── graph-schema.json   the contract graphify output must satisfy
├── graph/
│   ├── graph.json          the evidence graph (schema-valid, provenance on every node/edge)
│   └── graph.md            human-readable summary + health banner
├── knowledge/
│   └── assumption-audit.md load-bearing bets ranked by decision-at-risk
└── README.md
```

## Current state

The graph was last rebuilt from **twenty sources** (17 research, 1 ticket,
2 memo). Iteration 5 (2026-09-11) added Bermuda Safe-native privacy (Koeppelmann
posts + bermudabay.xyz). Corpus health is **developing** — still
**zero user interviews**. See:

- `knowledge/assumption-audit/2026-09-11-bermuda-safe-privacy.md` — new Bermuda assumptions
- `knowledge/research-loop/iter-005.md` — research loop journal (iter 5)
- `knowledge/competitive-landscape-2026-synthesis.md` — four-segment landscape (iter 4)
- `knowledge/assumption-audit/2026-07-01-iter-4.md` — prior ranked assumptions

Legacy product docs remain at `docs/product/` for backward compatibility; new
mogkit work should land in `product/sources/`.

## How to move it forward

1. **Add real research.** Drop interview transcripts, support tickets, or director
   feedback into `sources/` (with `type:` frontmatter). Re-run `graphify`.
2. **Discovery wedge:** `graphify` → `assumption-audit` → `discovery-query` →
   `interview-guide` → `synthesis-map` → `prd-interrogate`.
3. **Standalone skills** that fit Chamber right now:
   - `metrics-tree` — define measurable outcomes for treasury activation.
   - `narrative-review` — pressure-test positioning vs Safe/Tally.
   - `spec-stress-test` — red-team proposal execution / calldata flows.
   - `tradeoff-frame` — fixed signers vs market-driven board honestly.

Run a skill: `memory_skill_get(name="assumption-audit")` then follow its procedure.
