# How governance works

Chamber governance answers: **who leads**, **how much agreement is needed**, and **how leadership can change** — without editing a multisig signer list by hand.

## Roles in one sentence

- **Share holders** — deposit into the vault; **delegate** weight toward NFT token IDs.  
- **Directors** — control NFT token IDs in the **top seats**; use the **transaction queue**.  
- **Everyone else** — can read the board and proposals; cannot spend without director quorum.

## Delegation (picking leaders)

1. You hold **Chamber shares** (from depositing).  
2. You call **delegate** to assign some of your shares to a **membership NFT token ID** (for example “token 42”).  
3. All delegations to the same ID **add up** on the **Board** leaderboard.  
4. The **top N token IDs** (N = **seats**) are the current **directors**.

Rules that matter day to day:

- You cannot delegate **more than your share balance**.  
- You cannot transfer shares away if that would strand delegated weight — **undelegate first**.  
- Invalid or burned NFTs cannot receive new delegation.

## Who counts as a director?

At any moment:

1. Read how many **seats** the Chamber has (for example 5).  
2. Take the **top 5 token IDs** from the leaderboard.  
3. A wallet is a director for **token ID 42** only if:
   - It **controls** that NFT — the connected address is the NFT **owner**, or a
     **session key** the contract owner registered on Chamber — **and**
   - Token **42** is still in the top seats.

See **[Director authorization](./director-authorization.md)** for the exact
caller list. Chamber does **not** accept ERC-1271 signatures (M-01).

If delegation shifts and token 42 drops out of the top five, that wallet is **no longer a director** — even if it was yesterday. That is different from a Safe where signers stay until someone manually removes them.

## Quorum (how many confirmations to spend)

Spending uses the **transaction queue**. Each proposal needs enough **confirmations** from directors.

Quorum is **not** “half of directors” and is **not** a real-number “51% of seats + 1.” It is computed as:

\[
\text{quorum} = 1 + \lfloor \text{seats} \times 51 / 100 \rfloor
\]

This is the Solidity integer formula `1 + (seats * 51) / 100`. For many seat counts the result is about 55–67% of seats. One- and two-seat chambers require 100% of seats.

Examples:

| Seats | Confirmations needed |
|------:|---------------------:|
| 1 | 1 |
| 2 | 2 |
| 3 | 2 |
| 5 | 3 |
| 7 | 4 |
| 20 | 11 |

Each director **token ID** may confirm **once** per proposal. The **submitter** auto-confirms their own vote when they submit.

Quorum is **token-weighted**, not 1-address-1-vote. `isDirector` and confirmations are per membership NFT. One address that holds `quorum` distinct top-seat membership NFTs can submit, self-confirm, and execute — a **single-actor treasury**. Confirmations are not capped per owner.

## Changing the number of seats

After launch, directors can propose a new **seat count** (still capped at **20**):

1. A director calls **updateSeats** with the new number.  
2. Other directors **support** the same number.  
3. After a **7-day waiting period**, someone **executes** the change if enough supporters are **still directors**.

This stops a quick flash of votes from resizing the board without giving the community time to react.

## Cancelling a bad proposal

Directors can **vote to cancel** a queued transaction. If cancel votes reach **quorum**, the proposal is dead — it cannot be confirmed or executed afterward.

## Nested chambers (contemplated)

A leftover Registry can record **parent / child** links when a Chamber’s vault asset is **another Chamber’s share token**. That is **not** what Factory Create writes. Nested Sub-Chambers remain a contemplated pattern. See **[Chambers and Sub-Chambers](../introduction/chamber-and-sub-chambers.md)**.

## Read next

- **[Treasury actions](./multisig.md)** — submit, confirm, execute  
- **[Vault](./vaults.md)** — shares and deposits  
- **[Why not just a multisig?](../introduction/why-not-multisig.md)**  
