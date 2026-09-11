# Governance & The Board

The Board contract is the governance heart of the Chamber. It manages the dynamic selection of Directors based on token delegation.

## The Leaderboard

The Board maintains a **Sorted Linked List** of NFT IDs, ranked by the total amount of governance tokens delegated to them. This leaderboard determines who currently holds power within the Chamber.

### Director Selection
- The Chamber defines a fixed number of **Seats** (e.g., 5 or 11).
- The NFT IDs in the top N positions of the leaderboard are considered the **Directors**.
- Director status is fluid; if a new NFT receives more delegations and enters the top N, the previous N-th director is automatically unseated.

## Delegation Mechanics

Users can delegate their governance tokens to any valid NFT ID.

### Key Rules:
- **Liquid Delegation**: Users can redelegate or undelegate at any time.
- **Double-Entry Bookkeeping**: The system tracks both how much an agent has delegated and how much an NFT has received.
- **Sorted Linked List**: Insertion and re-ranking happen in O(n) gas complexity, optimized for up to 100 active nodes.

## Seat Management

The number of seats on the Board can be updated through a governance proposal.

### Update Process:
1. **Proposal**: A director proposes a new seat count.
2. **Support**: Other directors must support the proposal until a quorum is reached.
3. **Timelock**: Once quorum is met, a **7-day timelock** begins.
4. **Execution**: After the timelock, any director can execute the update.

## Quorum Calculation

Quorum is the integer formula `1 + (n * 51) / 100` (Solidity truncating division),
where `n` is the number of **reachable authorized** directors in the top-seat set
(`ownerOf` succeeds and the owner is not the chamber). Empty seats and burned or
chamber-held tokenIds do not inflate `n` (PMN-M01). This is not a simple majority
and is not "51% of seats + 1" as a real-number percentage. For many counts the
result is about 55–67% of `n`. One- and two-director boards require all reachable
directors. When filled authorized directors are below the configured-seat quorum,
`recoverSeats` can lower `seats` (PMN-M01 C); ordinary wallet spend cannot use that path.

That threshold is a count of distinct director **token IDs**, not unique addresses. `isDirector` and confirmations are per membership NFT. One address holding `quorum` top-seat membership NFTs can submit, self-confirm, and execute — a **single-actor treasury**. This is intended (token-weighted quorum); confirmations are not capped per owner.

Who may *call* as a given `tokenId` is specified in
[Director authorization](./director-authorization.md): the NFT owner
(`msg.sender == ownerOf`), or one Chamber-registered session key on a
**contract-owned** membership NFT. ERC-1271 is not consulted (M-01).
