# Chamber app — first-run UX review (2026-09-07)

Scope: `app/src` as it exists on `main`. Audience for the redesign: a first-time
director / treasury operator who has never used Chamber. Every claim below cites
the file it came from; nothing here is inferred from screenshots.

Related: [`app/src/docs/introduction/getting-started.md`](../../app/src/docs/introduction/getting-started.md),
[`packages/operator/README.md`](../../packages/operator/README.md).

---

## A. Current journey map

Routes are declared in [`app/src/App.tsx`](../../app/src/App.tsx):

| Route | Page |
| --- | --- |
| `/` | `Dashboard` |
| `/deploy` | `DeployChamber` |
| `/chamber/:address` and `/chamber/:address/:tab` | `ChamberDetail` (tabs: `overview`, `board`, `staking`, `delegation`) |
| `/chamber/:address/transactions` | `TransactionQueue` |
| `/chamber/:address/director/:tokenId` | `DirectorProfile` |
| `/docs`, `/docs/*` | `Docs` |

Primary nav is three items — Chambers, Deploy Chamber, Docs
(`app/src/components/Layout.tsx:16-19`).

The path a new operator actually walks, and where it breaks:

1. **Land on `/` disconnected.** `EmptyChambers` renders "Connect to see your
   chambers" with a *Deploy a Chamber* button (`Dashboard.tsx:394-417`). Above
   that empty state sit four controls the user cannot yet use: a Mine /
   Organizations toggle, an "Open address" form, a Recents strip, and *New
   Chamber* (`Dashboard.tsx:191-253`).
   **H1 — the empty dashboard offers navigation before it offers a first step.**

2. **Connect wallet.** RainbowKit `ConnectButton` in the header
   (`Layout.tsx:177`). Production builds only expose Sepolia unless
   `VITE_MAINNET_FACTORY`/`_REGISTRY` is set (`lib/wagmi.ts:89-109`). On chain 1
   without that env the dashboard shows "This deployment does not include
   Ethereum mainnet" (`Dashboard.tsx:64-75`).
   **H2 — a founder who connects on mainnet reads a build-configuration
   sentence, not "switch to Sepolia" with a button that switches.**

3. **Go to `/deploy`.** The form requires an existing **ERC-20 asset** and an
   existing **ERC-721 membership collection** before the *Review & Deploy*
   button unlocks — `canProceedToReview` needs both contracts to resolve
   on-chain (`DeployChamber.tsx:160-169`). On Sepolia/Anvil both prefill from
   the mock deployments (`DeployChamber.tsx:100-126`).
   **H3 — the single largest first-run cliff. Off the demo chains, a founder
   who has not already deployed a membership NFT collection cannot proceed, and
   the app offers no path to create one.**

4. **Deploy succeeds.** Success screen is honest — "The board is empty until you
   hold a membership NFT and delegate to it" — and embeds `SeatTheBoard`
   (`DeployChamber.tsx:196-260`). But the primary button reads **"Open Chamber"**
   and navigates to `/chamber/:address/delegation`, skipping Overview
   (`DeployChamber.tsx:246-251`).

5. **Seat the board.** `SeatTheBoard` is the best-designed surface in the app: it
   derives a `nextAction` of `mint | receive | deposit | delegate` and shows a
   three-step checklist (`SeatTheBoard.tsx:61-67`, `143-147`). Three problems:
   - Step 3 is hardcoded `done={false}` (`SeatTheBoard.tsx:146`), so the
     checklist never completes even after a successful delegation.
   - When `nextAction === 'delegate'`, the button says "Seat the board" and the
     actually-useful label ("Delegate to seat") renders as inert grey caption
     text beside it (`SeatTheBoard.tsx:163-175`).
   - Every *other* seat-the-board CTA bypasses this component and links straight
     to the Delegation tab, skipping the deposit step: Overview's empty
     directors list (`ChamberDetail.tsx:826-838`), Overview Quick Actions
     (`ChamberDetail.tsx:855-863`), the queue banner (`TransactionQueue.tsx:735-748`),
     and the queue empty state (`TransactionQueue.tsx:948-961`).
   **H4 — there is one good guided flow and four shortcuts around it.**

6. **Deposit (Staking tab).** `TreasuryOverview` handles approve → deposit with
   allowance polling and simulation. It hardcodes 18 decimals:
   `parseUnits(depositAmount, 18)` (`TreasuryOverview.tsx:45, 206`) and
   `formatUnits(..., 18)` throughout.
   **H5 — a chamber whose asset is USDC (6 decimals) will mis-scale deposit
   input by 1e12. The queue's token-transfer path does this correctly by reading
   `decimals()` (`TransactionQueue.tsx:1992-1998`), so the app is internally
   inconsistent.**

7. **Delegate.** `DelegationManager` is strong: it simulates before enabling the
   button, maps custom errors to plain English (`DelegationManager.tsx:175-186`),
   and previews the resulting rank ("Member Id #7 moves from Rank #3 → Rank #1 —
   would fill a board seat", `DelegationManager.tsx:146-167, 409-430`).

8. **Wait one block.** `SEATING_DELAY_BLOCKS = 1n` (`lib/chamberGovernance.ts:14`).
   `useDirectorActionGate` computes `seatingPending`, and the queue shows "You
   hold a live board seat, but director actions unlock at block N"
   (`TransactionQueue.tsx:725-729`).
   **H6 — this is correct but arrives as a banner on a page the user reached by
   clicking a now-disabled button. There is no countdown and no auto-advance.**

9. **First treasury transaction.** `/chamber/:address/transactions`. This is
   where clarity collapses; see B1–B4.

---

## B. Top 10 changes, ranked by impact × ease

### P0

**1. Expired proposals silently disappear from the queue. (S)**

*Problem.* In `TransactionQueue.tsx` the Expired section is nested **inside** the
Pending section's conditional: the block opened at line 878
(`{pendingTransactions.length > 0 && (`) does not close until line 920, and the
Expired block sits at lines 898–918 inside it. So expired proposals only render
when at least one pending proposal also exists. Worse, the empty state at line
945 requires `expiredTransactions.length === 0`. A queue containing **only**
expired proposals therefore renders a completely blank tab — while the Queue tab
badge counts them (`queueCount`, line 670) and the header stat shows a non-zero
Expired figure (line 765).

*Recommendation.* Close the Pending block after its `.map()` and hoist the
Expired block to a sibling. One-line structural fix.

*Why easier.* A director who is told "3 in queue" and shown nothing assumes the
app is broken. This is the cheapest credibility fix available.

**2. Deposits assume 18 decimals. (S)**

*Problem.* `TreasuryOverview.tsx:45` and `:206` call `parseUnits(amount, 18)`
regardless of the vault asset. Balance display, MAX, and the share-price line
all hardcode 18 as well.

*Recommendation.* Read `decimals()` from `chamberInfo.assetToken` the same way
the token-transfer proposal already does (`TransactionQueue.tsx:1992-1998`) and
thread it through parse/format/MAX.

*Why easier.* It stops being possible to deposit 1,000,000× the intended amount
into a USDC chamber. Not cosmetic.

**3. Proposal expiry is fetched, stored, and never shown. (M)**

*Problem.* `getTransactionDeadline` is read for every proposal
(`TransactionQueue.tsx:458-466`), stored on the item (`:598-602, :632`) and typed
(`types/index.ts:15`) — but `TransactionCard` never renders it. A director sees
"Pending · 1 / 3" with no indication the proposal dies in two hours. They find
out when the badge flips to Expired, or via
`toast.error('This transaction has expired')` (`:1217, :1237`). The submit form
has no expiry input either — `useSubmitTransaction` passes no deadline argument
(`hooks/useChamber.ts`).

*Recommendation.* Put "Expires in 3h 12m" (reusing `formatDurationSeconds`, which
already exists at `:1623`) next to the confirmation count on every non-executed
card, turn it amber under some threshold, and surface the deadline in the review
step of the new-proposal form.

*Why easier.* Confirmation is a coordination game across humans in different time
zones. A quorum that expires invisibly is the single most expensive failure in
this product.

**4. Execution requires pasting raw calldata hex. (M)**

*Problem.* When a ready proposal has calldata, `TransactionCard` renders a
`<textarea>` and asks the director to supply hex matching the on-chain
`keccak256` commitment (`:1445-1489`). The resolution chain in
`lib/proposalCalldata.ts` (localStorage → on-chain L-04 store → metadata URI →
`SubmitTransaction` logs) covers most cases, but when it misses the copy is
"Calldata not archived here. Ask the proposer for the hex, or paste from your
records." (`:1474-1477`).

*Recommendation.* Lead with the decoded action ("Transfer 5,000 USDC →
0xabc…def", already available from `proposalMeta.functionName` / the encoded
preview), show a green "calldata verified against on-chain hash" state, and
collapse the raw hex behind an *Advanced* disclosure. Only expand it
automatically when resolution fails.

*Why easier.* Right now the riskiest click in the product is also the one that
looks most like a developer console. Reviewers cannot verify hex; they can
verify "5,000 USDC to this address".

**5. Four CTAs bypass the one good onboarding component. (M)**

*Problem.* See journey step 5 — `SeatTheBoard` computes the correct next action,
but Overview's empty state, Overview Quick Actions, the queue banner, and the
queue empty state all hard-link to `/delegation`, which is the *last* step. A
user with a membership NFT but no shares lands on a Delegate form whose
simulation fails with "You don't have enough shares to delegate this amount"
(`DelegationManager.tsx:176`).

*Recommendation.* Make `SeatTheBoard` the single destination for every
seat-the-board CTA and let it route onward. Fix the hardcoded `done={false}` on
step 3 (`SeatTheBoard.tsx:146`) and use `copy.cta` as the button label instead of
a grey caption (`:163-175`).

*Why easier.* One checklist that always tells you the true next action beats four
links to the same tab.

### P1

**6. Deploy has no path for a founder without a membership NFT collection. (L)**

*Problem.* Both token addresses must resolve to live contracts before the form
unlocks (`DeployChamber.tsx:160-169`). Sepolia/Anvil prefill mocks; every other
chain does not. There is no "I don't have one yet" branch, and the field label
("Member Contract (ERC721)") does not say a collection must already exist.

*Recommendation.* Add a third option to the deploy form: *Use an existing
collection* / *Create a membership collection now* / *Use the demo collection
(testnets)*. The middle branch needs a minimal ERC-721 the Factory or a helper
script can deploy. Until that ships, at minimum add a callout explaining the
prerequisite and linking to
`app/src/docs/introduction/getting-started.md`.

*Why easier.* This is the gate between "I read the landing page" and "I have a
chamber". Everything else in this list is downstream of it.

**7. The queue leads with six numbers instead of one instruction. (S)**

*Problem.* `TransactionQueue.tsx:751-788` renders Pending / Ready / Expired /
Cancelled / Executed / Total in a fixed `grid-cols-6` — no responsive prefix, so
six columns are squeezed on mobile. None of them answer "what do I do".

*Recommendation.* Collapse to three states (Needs your confirmation · Ready to
execute · Everything else) and make the first one a sentence: "2 proposals need
your confirmation." Move Cancelled and Executed under History.

*Why easier.* The header should tell a director whether they can close the tab.

**8. `setDirectorOperator` has no UI at all. (M–L)**

*Problem.* The app reads `getDirectorOperator` (`hooks/useChamber.ts:993`) to
compute `role: 'owner' | 'operator'` and renders a read-only badge
(`DirectorCallerStatus.tsx`). There is no screen to register, view, rotate, or
revoke a session key — grep finds zero `setDirectorOperator` call sites outside
markdown. The mechanism is documented
(`app/src/docs/protocol/director-authorization.md`) and shipped in
`@loreum/chamber-operator`, but the human half of the product cannot participate.

*Recommendation.* Add an **Operators** panel to `DirectorProfile` (it already
knows `tokenId` and `nftOwner`): current operator address, Register / Rotate /
Revoke, and an explicit note of the contract constraint — only a *contract*
owner can register a key (`owner.code.length > 0`), so EOA-owned membership NFTs
must show a disabled state explaining why rather than a failing button.

*Why easier.* Agent delegation currently requires leaving the app for a CLI. See
section E.

**9. The vocabulary drifts within single screens. (S)**

*Problem.* Same concept, different word depending on file:

| Concept | Words currently used |
| --- | --- |
| The product | "Chambers" nav (`Layout.tsx:16`), "Loreum Chambers" (`Dashboard.tsx:149`, `index.html:8`), "Chamber" (`lib/wagmi.ts:92`, docs) |
| Membership NFT | "Member Contract (ERC721)" (`DeployChamber.tsx:383`), "membership NFT" (`SeatTheBoard.tsx:144`), "Member Token" (`Dashboard.tsx:380`), "member token" (`DelegationManager.tsx:349`) |
| A membership token | "Member #7" (`ChamberDetail.tsx:810`, `DirectorCallerStatus.tsx:16`) vs "Member Id #7" (`BoardVisualization.tsx:466`, `DelegationManager.tsx:587`) |
| Deposit/withdraw | Tab is "Staking" (`ChamberDetail.tsx:222`) but the panel says Deposit / Withdraw / "About ERC4626 Vaults" and never says staking (`TreasuryOverview.tsx`) |
| The queue | "Proposals & Queue" (`TransactionQueue.tsx:692`), "Transactions" button (`ChamberDetail.tsx:363`), "Transaction Activity" (`ChamberDetail.tsx:1030`), "View Transaction Queue" (`ChamberDetail.tsx:881`) |
| Quorum | "{n} signatures" (`ChamberDetail.tsx:412`), "{n} quorum" (`ChamberCard.tsx:96`), "{q} of {s} confirmations required" (`TransactionQueue.tsx:695`) |

*Recommendation.* See section D for the proposed lexicon. Pure find-and-replace
plus one tab rename.

*Why easier.* A first-timer cannot tell whether "Member Contract", "Member
Token", and "membership NFT" are three things or one.

**10. Docs are a dead-end tab. (S)**

*Problem.* `/docs` is reachable only from the header nav (`Layout.tsx:18`) and
the footer (`Layout.tsx:307`); a grep for `to="/docs` finds nothing else. Meanwhile
`getting-started.md` already contains exactly the walkthrough the empty states
are trying to compress into two sentences.

*Recommendation.* Deep-link from the moments of confusion: *Seat the board* →
`/docs/introduction/getting-started`; the calldata field → the multisig doc; the
paused banner and the upgrade banner → their protocol docs.

*Why easier.* The content already exists and is good. It is just unreachable at
the moment of need.

### Cheap wins (P2, all S)

- Remove the "Debug Info: Your Address: 0x…" block from the not-a-director state
  (`TransactionQueue.tsx:2283-2288`) — it is user-facing.
- Remove the decorative progress bar under Total Assets that animates to a
  hardcoded `width: '75%'` (`TreasuryOverview.tsx:265-272`); it implies a
  capacity target that does not exist.
- Deploy success: rename "Open Chamber" → "Continue setup" or point it at
  `/chamber/:address` (`DeployChamber.tsx:246-251`).
- Mainnet notice: add a "Switch to Sepolia" button next to the sentence
  (`Dashboard.tsx:64-75`).
- Surface the single-actor caveat the README already states — confirmations are
  per membership NFT, not per address, so one wallet holding `quorum` top seats
  is a single-actor treasury. The Board tab is the right place for it.

---

## C. First-run happy path (screen by screen)

Target: connect → funded chamber → first executed treasury transaction, with no
dead ends and no vocabulary the screen has not already defined.

**Screen 1 — `/` disconnected.** One card, one button: "Create your first
chamber". Connect happens inside that flow. Move Open-by-address, Recents, and
the Mine/Organizations toggle behind a "Find a chamber" link; they are
navigation for returning users, not a first step.

**Screen 2 — `/deploy`, step 1 of 3: What is this chamber for?** Name, symbol,
seats. Show the derived quorum inline in prose — "5 seats · 3 of 5 directors must
confirm every spend" — using the existing `quorumForSeats`
(`DeployChamber.tsx:20-22`). No addresses on this screen.

**Screen 3 — `/deploy`, step 2 of 3: Treasury asset and membership.** Asset
ERC-20 with live verification (already built, `DeployChamber.tsx:345-378`), then
the membership choice from B6: existing collection / create one / demo collection
on testnets. Keep the fee-on-transfer warning.

**Screen 4 — `/deploy`, step 3 of 3: Review.** Existing review panel, plus one
new line: "After deploying you will hold no seat yet. Next: get a membership
token, deposit, delegate, wait one block." Set the expectation before the
transaction, not after.

**Screen 5 — Chamber created → `/chamber/:address` Overview.** `SeatTheBoard`
occupies the page as a live four-step checklist with real state, each step
carrying its own button:
1. Hold a membership token — *Mint* (testnets) / *I already hold one*
2. Deposit assets — *Deposit* → Treasury tab, returns here
3. Delegate to your token — *Delegate* → prefilled with the token you hold
   (the `?tokenId=` prefill already exists, `SeatTheBoard.tsx:69-72`)
4. Seat matures — live "unlocks at block N, ~12s" countdown from
   `directorGate.seatedAt`, auto-advancing to "You are a seated director"

**Screen 6 — Board.** Once seated, the checklist collapses into a one-line
confirmation and the podium takes over. Add the per-NFT quorum caveat here.

**Screen 7 — First proposal.** From Overview, "Send your first payment" opens
the queue's New Proposal tab preset to *Send Token*. Review step shows: decoded
action in plain English, recipient, amount, risk badge, **who else must confirm
(N of M) and by when**.

**Screen 8 — Queue after submit.** Card leads with "Needs 2 more confirmations ·
expires in 23h". A single-director chamber (quorum met by the submitter) should
show *Execute now* immediately rather than making the user notice the badge
flipped to Ready.

**Screen 9 — Execute.** Decoded action, verified-calldata checkmark, Execute.
Raw hex behind *Advanced*.

**Screen 10 — Done.** Executed card links to the explorer and to
`DirectorProfile`, which is already a genuinely good audit surface.

---

## D. Mental model fixes

| Today | Confusion | Use instead |
| --- | --- | --- |
| Chamber / Chambers / Loreum Chambers | Is "Chamber" the product, the contract, or the org? | **Chamber** = one treasury+board instance. Product name **Chamber**, nav item **My Chambers**. Align `index.html:8` and `Dashboard.tsx:149` with `lib/wagmi.ts:92`. |
| Member Contract (ERC721) / Member Token / membership NFT | Three names, one thing | **Membership collection** (the ERC-721) and **membership token** (one NFT) |
| Member #7 / Member Id #7 | Two renderings of one identifier | **Member #7** everywhere |
| Staking (tab) | Nothing is staked; it is vault deposit/withdraw | **Treasury** (or **Deposit & Withdraw**) |
| Delegation | Correct term, but reads as governance jargon | Keep **Delegation**; subtitle "Point your shares at a member to give them a board seat" |
| Quorum: "{n} signatures" | Says signatures, means director confirmations, counted per NFT | **"{q} of {s} directors must confirm"** everywhere |
| Proposals & Queue / Transactions / Transaction Activity / Transaction Queue | Four names, one destination | **Proposals** everywhere; the Overview widget is **Recent proposals** |
| Board seat change vs treasury proposal | Two systems, one queue, different rules (7-day timelock, 14-day cancel, no calldata) | Keep them separate and label the section **Board changes** vs **Treasury proposals** |
| Directors / seats / rank | Mostly clear | Keep. Add one line on Board: "Directors are the top {seats} members by delegated shares. Ranking changes the moment delegation changes." |
| Operator / session key | Only appears as a read-only badge | **Operator (session key)** with a one-line definition wherever it appears |

---

## E. Agent + human dual UX

The contract surface is already shared — `packages/operator` calls the same
functions through the same generated ABIs, and decodes reverts to the same copy
the app shows (`DirectorNotSeated` → "Your seat is not mature yet", and so on;
see `packages/operator/README.md` against
`DelegationManager.tsx:175-186`). That shared error vocabulary is the strongest
existing link between the two halves. Four things would make them feel like one
system:

1. **Register operators from the UI.** Today the app can *observe* a session key
   (`useChamber.ts:993`) but not *create* one, so wiring an agent means leaving
   for a CLI. Ship the Operators panel from B8. Enforce and explain the contract
   rule up front: only a contract owner may register, and transferring the NFT
   invalidates the key
   (`app/src/docs/protocol/director-authorization.md`).

2. **Attribute agent actions in the UI.** `DirectorCallerStatus` distinguishes
   owner from operator for the *connected* wallet only. The queue should show it
   per action too — "Confirmed by Member #3 (operator 0xabc…)" — using the
   `SubmitTransaction` / `ConfirmTransaction` logs `DirectorProfile` already
   queries (`DirectorProfile.tsx:30-34`). A human reviewing a queue should be
   able to tell which confirmations came from an agent.

3. **Make every proposal round-trippable.** The app writes proposal metadata
   on-chain (`createProposalMetadataURI`, `TransactionQueue.tsx:2215`) and
   archives calldata in localStorage (`lib/proposalCalldata.ts`). Agents produce
   neither. Two consequences: agent-submitted proposals show as a bare "Contract
   call" with no title, and human-submitted proposals may be unexecutable by an
   agent that cannot see the browser's localStorage. Give the operator package
   the same `submitTransactionWithMetadata` path and a
   `chamber-operator calldata <nonce>` command that resolves from the on-chain
   store and events, mirroring `resolveProposalCalldata`.

4. **Put a copyable CLI equivalent next to each write action.** Under Confirm and
   Execute, a small "Do this from an agent" disclosure emitting the exact
   `npx chamber-operator confirm --chamber … --token-id … --nonce …` for that
   proposal. This teaches the SDK at the moment of need and makes the two
   surfaces visibly the same system.

---

## F. What not to change

- **Pre-flight simulation with mapped custom errors.** `useSimulateDelegate` /
  `useSimulateDeposit` / `useSimulateWithdraw` plus the `getErrorMessage` maps
  (`DelegationManager.tsx:175-186`, `TreasuryOverview.tsx:154-163`) turn reverts
  into sentences and disable the button before the wallet opens. This is better
  than most treasury tooling.
- **Rank-impact preview on delegation** (`DelegationManager.tsx:146-167`) —
  "would fill a board seat" is the clearest explanation of the whole delegation
  model anywhere in the product.
- **Risk classification and on-chain proposal metadata**
  (`classifyTransactionRisk`, `TransactionQueue.tsx:137-256`; upgrade, pause,
  unpause, and self-call are each called out by name).
- **`liveConfirmations` vs stored `confirmations`** and
  `requiredExecuteConfirmations = max(snapshot, live)`
  (`lib/chamberGovernance.ts:52-58`) — confirmations from evicted seats do not
  silently count. Keep the leftover-confirmation Revoke affordance
  (`TransactionQueue.tsx:1533-1548`) too.
- **Paused and registry-upgrade banners**, including the prefilled
  `?proposal=upgrade` flow (`ChamberDetail.tsx:260-303`,
  `TransactionQueue.tsx:2025-2052`). Turning "your proxy is stale" into a
  one-click reviewed proposal is excellent.
- **`DirectorProfile`** — per-member log-derived audit with submitted /
  confirmed / executed / cancelled counts and value proposed vs executed. Do not
  bury it.
- **"Your chambers, not a global directory"** (`Dashboard.tsx:152`) — the right
  product stance; keep the Open-by-address escape hatch.
- **Withdrawable vs delegated split** in the Withdraw panel
  (`TreasuryOverview.tsx:507-524`) — explains locked shares before the user hits
  a revert.
- **Deploy-time contract verification** — resolving name/symbol live and
  refusing to advance on a bad address (`DeployChamber.tsx:132-169`).
