# Chamber Documentation

## Overview

Chamber is a smart contract system that combines ERC4626 vault functionality with NFT-based governance and multisig transaction management. It enables token-weighted voting through delegation to NFT token IDs, creating a flexible governance framework for managing assets.

## Key Features

- **ERC4626 Vault**: Standard vault interface for managing ERC20 assets
- **NFT-Based Governance**: Directors are determined by top delegations to NFT token IDs
- **Multisig Transactions**: Quorum-based transaction approval and execution
- **Delegation System**: Token holders can delegate voting power to NFT token IDs
- **Upgradeable**: Built with OpenZeppelin upgradeable contracts
- **Gas Efficient**: Uses minimal proxy pattern for Chamber deployment

## Architecture Components

### Core Contracts

1. **Chamber** (`src/Chamber.sol`)
   - Main contract combining ERC4626, Board governance, and Wallet multisig
   - Manages asset deposits, withdrawals, and delegation
   - Handles transaction submission, confirmation, and execution

2. **Board** (`src/Board.sol`)
   - Manages sorted linked list of delegations
   - Tracks top token IDs by delegation amount
   - Handles seat management and quorum calculations

3. **Wallet** (`src/Wallet.sol`)
   - Multisig transaction management
   - Handles transaction submission, confirmation, and execution
   - Implements quorum-based approval system

4. **Registry** (`src/Registry.sol`)
   - Factory contract for deploying Chamber instances
   - Uses minimal proxy pattern (Clones) for gas-efficient deployment
   - Tracks all deployed chambers

## Quick Start

### Prerequisites

- Solidity 0.8.30+
- Foundry
- Node.js (for testing)

### Installation

```bash
git clone <repository-url>
cd chamber
forge install
```

### Deployment

1. Deploy Registry:
```solidity
Registry registry = new Registry();
registry.initialize(chamberImplementation, admin);
```

2. Create a Chamber:
```solidity
address chamber = registry.createChamber(
    erc20Token,
    erc721Token,
    seats,      // 1-20
    name,
    symbol
);
```

3. Initialize Chamber:
```solidity
IChamber(chamber).initialize(
    erc20Token,
    erc721Token,
    seats,
    name,
    symbol
);
```

## Documentation Structure

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Detailed system architecture and design patterns
- **[API.md](./API.md)** - Complete API reference for all contracts
- **[SEQUENCE_DIAGRAMS.md](./SEQUENCE_DIAGRAMS.md)** - Mermaid sequence diagrams for key workflows
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Deployment guide and best practices

## Key Concepts

### Directors

Directors are determined by the top N token IDs (where N = number of seats) ranked by total delegation amount. Who may call as a given token is the NFT owner or one Chamber-registered session key — see [Director authorization](./protocol/director-authorization.md). Only directors can:
- Submit transactions
- Confirm transactions
- Execute transactions
- Propose seat updates

### Delegation

Token holders delegate their voting power to NFT token IDs. The delegation amount determines the ranking in the board leaderboard. Directors are selected from the top delegations.

### Quorum

Quorum is calculated as `1 + (n * 51) / 100` (integer division) where `n` is the
number of reachable authorized directors in the top-seat set (PMN-M01). Empty seats
and burned or chamber-held tokenIds do not inflate `n`. This is not a simple majority:
one- and two-director boards require all reachable directors. For example, when `n`
equals the configured seat count:
- 1 director → quorum = 1 + (1 * 51) / 100 = 1
- 2 directors → quorum = 1 + (2 * 51) / 100 = 2
- 5 directors → quorum = 1 + (5 * 51) / 100 = 3
- 7 directors → quorum = 1 + (7 * 51) / 100 = 4

Quorum is **token-weighted**, not 1-address-1-vote. `isDirector` and confirmations are per membership `tokenId`. An address that holds `quorum` distinct top-seat membership NFTs can submit, self-confirm, and execute — a **single-actor treasury**. Confirmations are not capped per owner.

### Transactions

Transactions require:
1. Submission by a director
2. Confirmation by quorum number of directors
3. Execution by any director (after quorum reached)

## Security Features

- **Circuit Breaker**: Prevents reentrancy and contract calls during critical operations
- **ReentrancyGuard**: Additional protection for external calls
- **Input Validation**: Comprehensive checks for all parameters
- **Storage Gaps**: Future-proofing for upgrades

## License

MIT

## Links

- [Architecture Documentation](./ARCHITECTURE.md)
- [API Reference](./API.md)
- [Sequence Diagrams](./SEQUENCE_DIAGRAMS.md)
- [Deployment Guide](./DEPLOYMENT.md)
