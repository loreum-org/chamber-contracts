# Chamber Architecture

## System Overview

Chamber is a modular smart contract system that combines three core functionalities:
1. **ERC4626 Vault** - Asset management and tokenization
2. **Board Governance** - NFT-based delegation and director selection
3. **Wallet Multisig** - Quorum-based transaction management

## Contract Hierarchy

```
Registry
  └── Chamber (ERC4626Upgradeable, Board, Wallet)
        ├── Board (abstract)
        └── Wallet (abstract)
```

## Core Components

### 1. Registry Contract

**Purpose**: Factory contract for deploying Chamber instances using minimal proxy pattern.

**Key Features**:
- Gas-efficient deployment via `Clones.clone()`
- Tracks all deployed chambers
- Access control for admin functions

**Storage**:
- `implementation`: Address of Chamber implementation contract
- `_chambers[]`: Array of deployed chamber addresses
- `_isChamber`: Mapping to verify chamber addresses

### 2. Chamber Contract

**Purpose**: Main contract combining all functionality.

**Inheritance**:
- `ERC4626Upgradeable`: Vault functionality
- `ReentrancyGuardUpgradeable`: Reentrancy protection
- `Board`: Governance functionality
- `Wallet`: Multisig functionality
- `IChamber`: Interface compliance

**Key State Variables**:
- `nft`: ERC721 token contract for membership
- `agentDelegation`: Mapping of agent → tokenId → amount
- `totalAgentDelegations`: Total delegations per agent
- `version`: Implementation version string

### 3. Board Contract

**Purpose**: Manages delegation leaderboard and director selection.

**Data Structures**:
```solidity
struct Node {
    uint256 tokenId;
    uint256 amount;      // Total delegations
    uint256 next;        // Next node in sorted list
    uint256 prev;        // Previous node in sorted list
}

struct SeatUpdate {
    uint256 proposedSeats;
    uint256 timestamp;
    uint256 requiredQuorum;
    uint256[] supporters;
}
```

**Key Features**:
- **Sorted Linked List**: Maintains nodes sorted by delegation amount (descending)
- **Circuit Breaker**: Prevents reentrancy during repositioning
- **Seat Management**: Dynamic seat updates with timelock and quorum
- **Quorum Calculation**: `1 + (n * 51) / 100` where `n` is reachable authorized top-seat `tokenId`s (integer division; empty/inert slots do not inflate `n`; one- and two-director boards require all reachable directors; token-weighted — one owner of `quorum` top-seat NFTs is a single-actor treasury)

**Operations**:
- `_delegate()`: Add/update delegation, maintain sorted order
- `_undelegate()`: Remove delegation, update or remove node
- `_reposition()`: Re-sort node after amount change
- `_insert()`: Insert new node in sorted position
- `_remove()`: Remove node from list
- `_getTop()`: Retrieve top N nodes

### 4. Wallet Contract

**Purpose**: Multisig transaction management.

**Data Structures**:
```solidity
struct Transaction {
    bool executed;
    uint8 confirmations;
    address target;
    uint256 value;
    bytes data;
}
```

**Key Features**:
- Transaction submission with auto-confirmation
- Quorum-based confirmation system
- Batch operations support
- CEI pattern for execution safety

**Operations**:
- `_submitTransaction()`: Create transaction, auto-confirm submitter
- `_confirmTransaction()`: Add confirmation from director
- `_revokeConfirmation()`: Remove confirmation
- `_executeTransaction()`: Execute transaction after quorum

## Data Flow

### Delegation Flow

```
User → delegate(tokenId, amount)
  → Update agentDelegation mapping
  → Board._delegate()
    → Update/create Node
    → Reposition in sorted list
  → Emit DelegationUpdated event
```

### Transaction Flow

```
Director → submitTransaction(tokenId, target, value, data)
  → Wallet._submitTransaction()
    → Create Transaction struct
    → Auto-confirm submitter
  → Directors → confirmTransaction(tokenId, transactionId)
    → Increment confirmations
    → Check quorum reached
  → Director → executeTransaction(tokenId, transactionId)
    → Check quorum
    → Execute external call
    → Mark executed
```

### Director Selection Flow

```
Delegation changes
  → Board updates sorted list
  → getDirectors() called
    → getTop(seats)
    → Resolve NFT owners
    → Return director addresses
```

## Security Patterns

### 1. Circuit Breaker

The Board contract implements a circuit breaker pattern to prevent reentrancy during critical operations:

```solidity
modifier circuitBreaker() {
    if (locked) revert CircuitBreakerActive();
    locked = true;
    _;
    locked = false;
}
```

Used during `_reposition()` to prevent state corruption during linked list updates.

### 2. ReentrancyGuard

Chamber uses OpenZeppelin's `ReentrancyGuardUpgradeable` for transaction execution:

```solidity
function executeTransaction(...) public nonReentrant {
    // Execute external call
}
```

### 3. CEI Pattern

Wallet contract follows Checks-Effects-Interactions pattern:

```solidity
function _executeTransaction(...) internal {
    // Check
    if (transaction.executed) revert();
    
    // Effect
    transaction.executed = true;
    
    // Interaction
    (bool success, ) = target.call{value: value}(data);
    if (!success) {
        transaction.executed = false; // Revert on failure
        revert();
    }
}
```

### 4. Input Validation

All public functions validate inputs:
- Zero address checks
- Zero amount checks
- Balance checks
- Existence checks (NFT, transaction, node)

### 5. Storage Gaps

All upgradeable contracts include storage gaps:

```solidity
uint256[50] private __gap;
```

Prevents storage collisions during upgrades.

## Upgradeability

### Proxy Pattern

Chamber uses OpenZeppelin's upgradeable contracts with TransparentUpgradeableProxy:

1. **Implementation Contract**: Contains logic (no state)
2. **Proxy Contract**: Stores state, delegates calls to implementation
3. **Admin**: Controls upgrades

### Initialization

All contracts use `initializer` pattern:

```solidity
function initialize(...) external initializer {
    __ERC4626_init(...);
    __ReentrancyGuard_init();
    // Initialize state
}
```

## Gas Optimization

### 1. Minimal Proxy Pattern

Registry uses `Clones.clone()` for gas-efficient Chamber deployment:
- ~45,000 gas vs ~2,000,000+ gas for full deployment
- Shared implementation code
- Separate storage per instance

### 2. Unchecked Arithmetic

Used in loops where overflow is impossible:

```solidity
for (uint256 i = 0; i < count;) {
    // operations
    unchecked { ++i; }
}
```

### 3. Storage Packing

Structs designed to pack efficiently:
- `Transaction`: bool + uint8 + address + uint256 + bytes
- `Node`: 4 × uint256

### 4. Batch Operations

Batch functions reduce transaction overhead:
- `submitBatchTransactions()`
- `confirmBatchTransactions()`
- `executeBatchTransactions()`

## Limitations

### Board Limitations

- **Max Nodes**: 100 nodes in linked list
- **Max Seats**: 20 seats maximum
- **Gas Costs**: O(n) operations for large lists

### Wallet Limitations

- **No Scheduling**: Transactions execute immediately when quorum reached
- **No Conditions**: No time-based or condition-based execution
- **No Cancellation**: Transactions cannot be cancelled (only revoked)

### Chamber Limitations

- **Single NFT Contract**: One ERC721 per Chamber for **membership / director identity**
- **Single Asset**: One ERC20 asset per Chamber as the **ERC-4626 vault underlying**
- **No Multi-Asset vault**: The vault cannot hold multiple ERC20 tokens as the share-accounting asset
- **NFT custody**: `onERC721Received` accepts any ERC-721 for treasury custody (not limited to the membership NFT). There is no ERC-1155 receiver; ERC-1155 `safeTransferFrom` reverts.

## Future Enhancements

1. **Multi-Asset Support**: Hold multiple ERC20 tokens
2. **Transaction Scheduling**: Time-based execution
3. **Conditional Execution**: Execute based on conditions
4. **Governance Strategies**: Configurable quorum calculations
5. **Metadata Tracking**: Enhanced Registry with metadata

## Design Decisions

### Why Sorted Linked List?

- Efficient insertion/removal: O(n) worst case
- Maintains order automatically
- No need for external sorting
- Gas-efficient for typical use cases (< 100 nodes)

### Why NFT-Based Directors?

- Flexible membership model
- Can represent roles, members, or entities
- Transferable governance power
- Compatible with existing NFT ecosystems

### Why ERC4626?

- Standard vault interface
- Composability with DeFi protocols
- Tokenized shares
- Standard deposit/withdraw patterns

## Testing Strategy

1. **Unit Tests**: Test each contract in isolation
2. **Integration Tests**: Test contract interactions
3. **Fuzz Tests**: Property-based testing
4. **Gas Tests**: Optimize gas usage
5. **Upgrade Tests**: Verify upgrade compatibility

## References

- [ERC4626 Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [Minimal Proxy Pattern (EIP-1167)](https://eips.ethereum.org/EIPS/eip-1167)
