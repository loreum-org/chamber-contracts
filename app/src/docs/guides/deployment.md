# Deploying Chambers (for operators)

> **Audience:** developers and operators running Foundry scripts. End users normally create Chambers through the app’s **Deploy** page — see **[Getting started](../introduction/getting-started.md)**.

Contracts live in **`contracts/`**. New deploys go through the **Factory**. The **Registry** remains as a deprecated index + leftover create path.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)  
- RPC URL and funded deployer key  
- Optional: block explorer API key for verification  

```bash
cd contracts
forge install
```

## What Factory deploy does

`script/Factory.s.sol` (`DeployFactory`):

1. Deploy or reuse a **Chamber** implementation (`CHAMBER_IMPLEMENTATION`, or a new `Chamber`).  
2. Deploy **Factory** with that implementation and an **owner** (`ADMIN`, or `msg.sender`).  
3. Return the **Factory address** the app should use (`VITE_*_FACTORY` env vars).

Each **`Factory.createChamber`** then:

- Spawns a **Chamber proxy** initialized with your ERC‑20, ERC‑721, seats, name, symbol.  
- Transfers **ProxyAdmin ownership** to the Chamber (upgrades go through director queue).  
- Emits **`ChamberCreated`** for indexers / `getLogs`. It does **not** write parent/child tables.

Example:

```bash
cd contracts
forge script script/Factory.s.sol:DeployFactory \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

Set **`ADMIN`** in the environment if the owner should not be `msg.sender`.

## What leftover Registry deploy does

`script/Registry.s.sol` (via `DeployRegistry` helper) is the **deprecated** factory + index. It is not what Create uses when Factory is configured.

1. Deploy **Registry** implementation.  
2. Deploy **Chamber** implementation.  
3. Deploy **Registry proxy** with `initialize(chamberImplementation, admin)`.  
4. Return the **Registry address** (`VITE_*_REGISTRY` env vars).

Each leftover **`Registry.createChamber`** then:

- Spawns a **Chamber proxy** initialized with your ERC‑20, ERC‑721, seats, name, symbol.  
- Transfers **ProxyAdmin ownership** to the Chamber.  
- Optionally links **parent/child** if the asset token is another registered Chamber. That nested wiring is leftover — not the live architecture.

Example:

```bash
cd contracts
forge script script/Registry.s.sol:DeployRegistry \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

Set **`ADMIN`** in the environment if the admin should not be `msg.sender`.

## Standalone Chamber script (local only)

`script/Chamber.s.sol` deploys a Chamber proxy **without** Factory semantics (ProxyAdmin may stay with a separate admin EOA). Prefer **Factory** for production documentation and the app. Registry remains a leftover index + create path.

## Post-create board bootstrap (Anvil or Sepolia)

`createChamber` leaves the board empty. The creator must hold a membership NFT and delegate after depositing shares. Director rights unlock after `SEATING_DELAY` (1 block). Quorum stays `1 + (seats * 51) / 100`.

```bash
# 1. Membership NFT — mock mint on Anvil/Sepolia, or transfer an existing token
cast send "$ERC721" "mint(address)" "$CREATOR" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"

# 2. Shares (mock ERC-20 on test nets)
cast send "$ERC20" "mint(address,uint256)" "$CREATOR" 100ether \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$ERC20" "approve(address,uint256)" "$CHAMBER" 100ether \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
cast send "$CHAMBER" "deposit(uint256,address)" 100ether "$CREATOR" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"

# 3. Delegate to the token you hold
cast send "$CHAMBER" "delegate(uint256,uint256)" "$TOKEN_ID" 100ether \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"

# 4. Wait SEATING_DELAY (1 block)
cast rpc evm_mine --rpc-url http://127.0.0.1:8545   # Anvil
# On Sepolia, wait for the next block

# 5. Confirm the creator is seated
cast call "$CHAMBER" "getDirectors()(address[])" --rpc-url "$RPC_URL"
cast call "$CHAMBER" "getSeatedAt(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL"
```

Do not auto-seat addresses that do not hold a membership NFT.

## App configuration

Sepolia Factory, Registry, Chamber implementation, and demo ERC-20 / membership ERC-721
are read from **`contracts/deployments/sepolia.txt`**. Optional env overrides:
`VITE_SEPOLIA_REGISTRY`, `VITE_SEPOLIA_FACTORY`, `VITE_SEPOLIA_CHAMBER_IMPL`,
`VITE_SEPOLIA_MOCK_ERC20`, `VITE_SEPOLIA_MOCK_ERC721`.

Optional **My chambers** indexer: `VITE_INDEXER_URL` → [loreum-org/chamber-indexer](https://github.com/loreum-org/chamber-indexer) GraphQL. Unset → chunked Factory/Registry `getLogs`.

See **`app/README.md`** and repo deployment docs under **`docs/guides/deployment.md`**.

## Read next

- **[Architecture](../protocol/architecture.md)**  
- **[API reference](../reference/api-reference.md)**  
- **[Getting started](../introduction/getting-started.md)** — user-facing deploy wizard  
