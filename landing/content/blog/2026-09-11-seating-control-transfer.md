---
title: Seating delay binds to NFT control transfer
date: 2026-09-11
summary: Transferring a seated membership NFT now resets the seating clock and drops the prior owner's confirm/cancel bits.
---

11 September 2026. Seating delay binds to NFT control transfer.

- Seating delay now binds to who controls the NFT (`ownerOf`), not only to a tokenId entering the top seats.
- On control change, the new controller waits a fresh `SEATING_DELAY` before they can act as seated.
- Confirm/cancel flags recorded under the previous owner no longer count toward quorum or execute.
- Session keys still go stale on transfer (unchanged).
- Chamber contracts version `1.1.7`. This does not clear the pre-mainnet gate by itself.
