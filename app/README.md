# Chamber App

A decentralized treasury governance application for Loreum Chambers. This application serves as a Gnosis Safe-like interface for managing multi-signature treasury operations with board-based governance.

## Features

- **Deploy Chambers**: Create new treasury governance instances via the Factory (Registry fallback)
- **Board Visualization**: Beautiful graphical representation of board members and their voting power
- **Transaction Queue**: Submit, confirm, and execute multi-signature transactions
- **Treasury Management**: Deposit/withdraw assets using ERC4626 vault mechanics
- **Delegation System**: Delegate voting power to NFT holders to compete for board seats
- **Chamber assets (overview)**: Optional ERC-20 and NFT holdings via Alchemy when `VITE_ALCHEMY_API_KEY` is set. On local Anvil **31337**, the panel reads **Ethereum mainnet** balances for the chamber address (same as a mainnet fork).

## Tech Stack

- **React 18** with TypeScript
- **Vite** for fast development and building
- **wagmi v2** + **viem** for Ethereum interactions
- **RainbowKit v2** for wallet connection
- **TanStack Query** for data fetching
- **Tailwind CSS** for styling
- **Framer Motion** for animations

## Design

The application features a "Futuristic Western Civilization" design aesthetic:
- Dark theme with marble and gold accents
- Classical architectural elements (columns, pediments)
- Modern glowing effects and gradients
- Serif typography for headers, sans-serif for content

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn or pnpm

### Installation

```bash
cd app
npm install
```

### Configuration

1. Optional — **Alchemy** for indexed chamber assets on the Chamber overview tab. Create an API key at [alchemy.com](https://www.alchemy.com) and add to `app/.env`:
   ```bash
   VITE_ALCHEMY_API_KEY=your_key
   ```
   Enable Ethereum, Sepolia, Base, and Arbitrum apps in the Alchemy dashboard. The same key powers **wagmi RPC** (read/write on those chains) and the **Chamber assets** panel. Production `eth_getLogs` pagination for **My chambers** also uses this RPC (not a single getLogs-from-0).

2. Optional — **Ponder indexer** ([loreum-org/chamber-indexer](https://github.com/loreum-org/chamber-indexer)) for **My chambers** that survive public-RPC log truncation and a new browser (no `localStorage` recents). Dual discovery: Factory `ChamberCreated` (when `PONDER_FACTORY_ADDRESS` is set on the indexer) plus leftover Registry creates. GraphQL `chambers` / `chamberHolders` = creator OR current share balance.
   ```bash
   VITE_INDEXER_URL=https://your-ponder-host.example
   # VITE_INDEXER_CHAIN_ID=11155111
   ```
   The app POSTs to `{VITE_INDEXER_URL}/graphql` (`MyChambers`). If the host is unset or down, discovery falls back to chunked Factory/Registry `getLogs` from the configured start block (Sepolia default `7453704`, same as the indexer). A live Ponder host is not required. See `app/.env.template`.

3. Update the WalletConnect Project ID in `src/lib/wagmi.ts`:
   ```typescript
   projectId: 'YOUR_WALLETCONNECT_PROJECT_ID'
   ```

4. Sepolia Factory / Registry / demo ERC-20 / membership ERC-721 come from
   `contracts/deployments/sepolia.txt` (parsed by `getContractAddresses(11155111)`).
   Env vars (`VITE_SEPOLIA_*`) still override. Other networks: set `VITE_*` in `.env`.

### Development

```bash
npm run dev
```

The app will be available at `http://localhost:5173`

### Build

```bash
npm run build
```

### Sepolia wallet smoke (Playwright + MetaMask)

Short wallet-UI smoke on **Sepolia (11155111)**: load the app, connect via the RainbowKit modal + MetaMask (Dappwright), stay on Sepolia, then open a known chamber by address (or assert connected **My chambers**). This is not a submit / confirm / execute cycle.

`scripts/verify-sepolia-discovery.ts` stays the RPC-only discovery check (`npm run test:discovery`). This script is the wallet layer on top of that.

| Variable | Required to run | Notes |
| --- | --- | --- |
| `E2E_SEPOLIA_PRIVATE_KEY` or `SEPOLIA_PRIVATE_KEY` | yes | Throwaway account. **Never commit.** Fund it with Sepolia ETH (faucet) before a real run. |
| `PLAYWRIGHT_BASE_URL` | no | Defaults to `https://app.loreum.org`. |
| `PLAYWRIGHT_SEPOLIA_CHAMBER` | no | Chamber to open. Default is a known Sepolia chamber from Factory `0x43aA92c8A26392f21F63cdA88B6BaB5031C40550` / discovery. |

```bash
cd app
# Skips with exit 0 when neither key env is set (default CI stays green)
npm run test:e2e:sepolia
```

The key is read from the environment only. Do not put it in the repo, commit messages, or Playwright artifacts.

## Project Structure

```
app/
├── public/              # Static assets
├── src/
│   ├── components/      # Reusable UI components
│   │   ├── Layout.tsx
│   │   ├── ChamberCard.tsx
│   │   ├── BoardVisualization.tsx
│   │   ├── TreasuryOverview.tsx
│   │   └── DelegationManager.tsx
│   ├── contracts/       # Contract ABIs
│   ├── hooks/           # Custom React hooks
│   │   ├── useChamber.ts
│   │   └── useRegistry.ts
│   ├── lib/             # Utilities and config
│   │   ├── wagmi.ts
│   │   └── utils.ts
│   ├── pages/           # Page components
│   │   ├── Dashboard.tsx
│   │   ├── DeployChamber.tsx
│   │   ├── ChamberDetail.tsx
│   │   └── TransactionQueue.tsx
│   ├── types/           # TypeScript types
│   ├── App.tsx          # Main app component
│   ├── main.tsx         # Entry point
│   └── index.css        # Global styles
├── package.json
├── tailwind.config.js
├── tsconfig.json
└── vite.config.ts
```

## Key Functionality

### Chamber Management
- **My chambers** via Ponder (`VITE_INDEXER_URL`) or chunked Factory/Registry `ChamberCreated` logs, plus recents and open-by-address
- Deploy new chambers with custom parameters
- View chamber details (assets, board, transactions)

### Board Governance
- Visual representation of board seats in a semi-circular "senate" layout
- Leaderboard showing all members ranked by delegated voting power
- Directors are the top N members (where N = number of seats)

### Transaction Queue (Safe-like)
- Submit new transactions (ETH transfers, token transfers, custom calls)
- View pending transactions awaiting confirmations
- Confirm transactions as a director
- Execute transactions once quorum is reached
- View transaction history

### Treasury (ERC4626 Vault)
- Deposit assets to receive shares
- Withdraw assets by burning shares
- View share/asset ratio
- Track total assets and supply

### Delegation
- Delegate shares to NFT token IDs
- Undelegate to reclaim voting power
- View your active delegations
- Locked shares cannot be transferred

## Contract Integration

The app integrates with the following contracts:

- **Factory**: Permissionless create path; `ChamberCreated` is the discovery event (no world list)
- **Registry**: Deprecated index + leftover create path; still scanned for legacy chambers
- **Chamber**: Main contract combining:
  - ERC4626 vault for asset management
  - Board governance for director elections
  - Wallet multisig for transaction execution

## License

MIT
