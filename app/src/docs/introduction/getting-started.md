# Getting started

This guide walks you through the **Chamber web app** as a new user: deploy a Chamber, add funds, delegate influence, and (if you are a director) move the treasury through the **proposal queue**.

Skim **[What is a Chamber?](./overview.md)** first if the ideas are new.

---

## Before you begin

1. **Install a wallet** (MetaMask, Rainbow, etc.) and connect it using the button in the app header.  
2. **Pick the right network** — the app only shows Chambers deployed on chains your build is configured for (often **Sepolia** for testing).  
3. Keep three words in mind:
   - **Shares** — your weight in the vault (from depositing).  
   - **NFT token IDs** — membership seats people delegate toward.  
   - **Transactions** — proposals to spend or call contracts (directors only).

---

## Step 1 — Create a Chamber

**Go to:** **Deploy** (`/deploy`)

You are launching a new treasury + governance ruleset through the **Factory**. A leftover Registry create path may still exist if Factory is unset — that is not the live default.

| Field | What it means |
|--------|----------------|
| **ERC‑20 address** | The token the vault holds (USDC, your governance token, etc.). |
| **ERC‑721 address** | The **membership NFT** collection; each **token ID** can receive delegation. |
| **Seats** | How many **top-ranked NFTs** count as directors (**1–20**). More seats → more people in leadership, higher quorum for spends. |
| **Name / Symbol** | Labels for the Chamber **share token** (what depositors receive). |

Flow: fill the form → **Review & Deploy** → confirm in your wallet → wait for confirmation.

**Deploy does not seat anyone.** Factory create lists the chamber under **Mine** with an empty board. Submit, confirm, and execute stay locked until a director is seated. The success screen shows **Seat the board** when the board is empty.

---

## Step 2 — Seat the board (required)

Happy path on **Sepolia** or **Anvil**:

1. **Deploy succeeds** — the chamber is live; `getDirectors()` is empty.
2. **Hold a membership NFT** — the creator must own at least one token from the ERC‑721 you pasted.
   - **Anvil / Sepolia mock collection:** use **Mint Test NFT** (header) or **Seat the board → Mint founder NFT**.
   - **Your own collection:** receive or already hold a token. Chamber does not mint third-party NFTs and does not auto-seat strangers.
3. **Deposit shares** — **Staking** tab. Delegation needs Chamber shares.
4. **Delegate** to a token ID you hold — **Delegation** tab (the CTA prefills a token you own when it can).
5. **Wait `SEATING_DELAY`** — **1 block**. Then the creator is a seated director and the queue can run.

Quorum stays `1 + (seats * 51) / 100` (I-02). Seating delay stays 1 block (H-02).

**Go to:** **Dashboard** (`/`) → click your Chamber → **Overview** (`/chamber/:address`)

The header shows vault size, seats, quorum, and your balance. Main areas:

| Tab / link | Purpose |
|------------|---------|
| **Overview** | Summary and next action (empty-board bootstrap, or the proposal queue once seated) |
| **Board** | Leaderboard — who has the most delegated weight |
| **Staking** | Deposit or withdraw underlying tokens |
| **Delegation** | Point your shares at NFT token IDs |
| **Transactions** | Proposal queue (directors) |

If **no one has delegated yet**, Overview explains how to seat the board instead of showing a dead transaction queue.

---

## Step 3 — Add funds (deposit)

**Go to:** **Staking** tab

1. Hold enough of the Chamber’s **underlying ERC‑20** in your wallet.  
2. **Approve** the Chamber when prompted.  
3. Click **Deposit** — you send underlying in and receive **Chamber shares**.  
4. Your share balance is the **maximum** you can delegate.

To leave later: **Withdraw** (you may need to **undelegate** first if those shares are still delegated — see **[Vault](../protocol/vaults.md)**).

---

## Step 4 — Delegate (choose leaders)

**Go to:** **Delegation** tab

1. Pick **membership NFT token IDs** you want to support (for example token `#7` and `#12`).  
2. Assign **how much of your share balance** goes to each ID.  
3. Open **Board** — the **top N token IDs** by total delegated weight become **director seats**.

Delegation is **liquid**: you can change allocations as your preferences change. The board updates onchain — unlike a static multisig signer list.

---

## Step 5 — Propose and execute spending (directors)

**Go to:** **Transactions** (`/chamber/:address/transactions`)

Only wallets that control an NFT **currently in a top seat** can act as directors.

Typical flow:

1. **Submit** — describe an outbound action (send ETH, call another contract). The app stores a **hash** of the calldata onchain; **save the full calldata** (the app helps via events / copy fields).  
2. **Confirm** — other directors approve until **quorum** is reached (depends on seat count — see **[Governance](../protocol/governance.md)**).  
3. **Execute** — someone supplies the **exact same calldata**; the contract checks the hash, then runs the call.

This is the Chamber equivalent of a multisig transaction — but confirmations are tied to **current director seats**, not a fixed signer CSV.

**Cancel:** directors can vote to **cancel** a proposal before execution if the group changes its mind.

---

## Quick reference

| I want to… | Where in the app |
|-----------|------------------|
| Create a Chamber | **Deploy** |
| Put money in the treasury | **Staking → Deposit** |
| Support leaders | **Delegation** |
| See who leads | **Board** |
| Spend treasury / interact with contracts | **Transactions** |

---

## Read next

- **[Why not just a multisig?](./why-not-multisig.md)**  
- **[App routes](../guides/app-routes.md)** — URL map  
- **[Governance](../protocol/governance.md)** — quorum and seats  
- **[Treasury actions](../protocol/multisig.md)** — proposal details  
