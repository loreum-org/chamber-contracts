# Chamber API Reference

## Registry Contract

### Functions

#### `initialize(address _implementation, address admin)`
Initializes the Registry contract.

**Parameters**:
- `_implementation`: Address of Chamber implementation contract
- `admin`: Address that will have admin role

**Reverts**:
- `ZeroAddress`: If any address is zero

**Access**: Initializer (can only be called once)

---

#### `createChamber(address erc20Token, address erc721Token, uint256 seats, string memory name, string memory symbol)`
Deploys a new Chamber instance using minimal proxy pattern.

**Parameters**:
- `erc20Token`: Standard ERC-20 vault asset (no factory allowlist; fee-on-transfer and rebasing tokens are unsupported)
- `erc721Token`: ERC721 token address for membership
- `seats`: Initial number of board seats (1-20)
- `name`: Name of chamber's ERC20 token
- `symbol`: Symbol of chamber's ERC20 token

**Returns**:
- `chamber`: Address of newly deployed chamber

**Reverts**:
- `ZeroAddress`: If token addresses are zero
- `InvalidSeats`: If seats is 0 or > 20

**Events**:
- `ChamberCreated(chamber, seats, name, symbol, erc20Token, erc721Token)`

---

#### `getAllChambers() → address[]`
Returns all deployed chamber addresses.

**Returns**: Array of chamber addresses

---

#### `getChamberCount() → uint256`
Returns total number of deployed chambers.

**Returns**: Number of chambers

---

#### `getChambers(uint256 limit, uint256 skip) → address[]`
Returns paginated list of chambers.

**Parameters**:
- `limit`: Maximum number of chambers to return
- `skip`: Number of chambers to skip

**Returns**: Array of chamber addresses

---

#### `isChamber(address chamber) → bool`
Checks if address is a deployed chamber.

**Parameters**:
- `chamber`: Address to check

**Returns**: `true` if chamber, `false` otherwise

---

## Chamber Contract

### Initialization

#### `initialize(address erc20Token, address erc721Token, uint256 seats, string calldata _name, string calldata _symbol)`
Initializes the Chamber contract.

**Parameters**:
- `erc20Token`: ERC20 token address
- `erc721Token`: ERC721 token address
- `seats`: Initial number of seats
- `_name`: ERC20 token name
- `_symbol`: ERC20 token symbol

**Reverts**:
- `ZeroAddress`: If token addresses are zero

**Access**: Initializer

---

### Delegation Functions

#### `delegate(uint256 tokenId, uint256 amount)`
Delegates tokens to a token ID.

**Parameters**:
- `tokenId`: NFT token ID to delegate to
- `amount`: Amount of tokens to delegate

**Reverts**:
- `ZeroTokenId`: If tokenId is 0
- `ZeroAmount`: If amount is 0
- `InsufficientChamberBalance`: If user balance < amount
- `InvalidTokenId`: If NFT doesn't exist

**Events**:
- `Delegate(sender, tokenId, amount)`
- `DelegationUpdated(agent, tokenId, newAmount)`

---

#### `undelegate(uint256 tokenId, uint256 amount)`
Undelegates tokens from a token ID.

**Parameters**:
- `tokenId`: NFT token ID to undelegate from
- `amount`: Amount of tokens to undelegate

**Reverts**:
- `ZeroTokenId`: If tokenId is 0
- `ZeroAmount`: If amount is 0
- `InsufficientDelegatedAmount`: If delegation < amount

**Events**:
- `Undelegate(sender, tokenId, amount)`
- `DelegationUpdated(agent, tokenId, newAmount)`

---

#### `getDelegations(address agent) → (uint256[] tokenIds, uint256[] amounts)`
Returns all delegations for an agent.

**Parameters**:
- `agent`: Address to query

**Returns**:
- `tokenIds`: Array of token IDs
- `amounts`: Array of delegated amounts

**Reverts**:
- `ZeroAddress`: If agent is zero

---

#### `getAgentDelegation(address agent, uint256 tokenId) → uint256`
Returns delegation amount for specific agent-tokenId pair.

**Parameters**:
- `agent`: Agent address
- `tokenId`: Token ID

**Returns**: Delegation amount

---

#### `getTotalAgentDelegations(address agent) → uint256`
Returns total delegations across all token IDs for an agent.

**Parameters**:
- `agent`: Agent address

**Returns**: Total delegation amount

---

### Board Functions

#### `getMember(uint256 tokenId) → (uint256 tokenId, uint256 amount, uint256 next, uint256 prev)`
Returns node information for a token ID.

**Parameters**:
- `tokenId`: Token ID to query

**Returns**: Node struct fields

---

#### `getTop(uint256 count) → (uint256[] tokenIds, uint256[] amounts)`
Returns top N token IDs by delegation amount.

**Parameters**:
- `count`: Number of top items to return

**Returns**:
- `tokenIds`: Array of token IDs (descending by amount)
- `amounts`: Array of delegation amounts

---

#### `getSize() → uint256`
Returns total number of nodes in board.

**Returns**: Board size

---

#### `getQuorum() → uint256`
Returns current quorum requirement.

**Returns**: Quorum value (`1 + (n * 51) / 100`) where `n` is reachable authorized top-seat directors (`getReachableDirectorCount`). Empty seats and burned or chamber-held tokenIds do not inflate `n`. One- and two-director boards require all reachable directors.

#### `getReachableDirectorCount() → uint256`
Returns how many top-seat tokenIds can still authorize (`ownerOf` succeeds, owner is not the chamber).

#### `recoverSeats(uint256 tokenId, uint256 newSeats)`
Lowers configured `seats` when filled authorized directors are below the configured-seat quorum. Dedicated recovery path; not an allowed wallet self-call.

**Note**: Quorum is token-weighted. It counts distinct director `tokenId` confirmations, not unique addresses. One owner of `quorum` top-seat membership NFTs is a single-actor treasury.

---

#### `getSeats() → uint256`
Returns current number of board seats.

**Returns**: Number of seats

---

#### `getDirectors() → address[]`
Returns addresses of current directors.

**Returns**: Array of director addresses (address(0) for invalid NFTs)

**Note**: Returns address(0) for token IDs where NFT ownership check fails

---

#### `updateSeats(uint256 tokenId, uint256 numOfSeats)`
Proposes or supports seat update.

**Parameters**:
- `tokenId`: Director's token ID
- `numOfSeats`: Proposed number of seats

**Reverts**:
- `NotDirector`: If caller is not a director
- `ZeroSeats`: If numOfSeats is 0
- `TooManySeats`: If numOfSeats > 20
- `AlreadySentUpdateRequest`: If already supported proposal

**Events**:
- `SetSeats(tokenId, numOfSeats)`
- `SeatUpdateCancelled(tokenId)` (if new proposal cancels existing)

**Access**: Directors only

---

#### `executeSeatsUpdate(uint256 tokenId)`
Executes pending seat update proposal.

**Parameters**:
- `tokenId`: Director's token ID executing

**Reverts**:
- `NotDirector`: If caller is not a director
- `InvalidProposal`: If no proposal exists
- `TimelockNotExpired`: If 7 days haven't passed
- `InsufficientVotes`: If quorum not maintained

**Events**:
- `ExecuteSetSeats(tokenId, newSeats)`

**Access**: Directors only

---

#### `getSeatUpdate() → (uint256 proposedSeats, uint256 timestamp, uint256 requiredQuorum, uint256[] supporters)`
Returns current seat update proposal.

**Returns**:
- `proposedSeats`: Proposed number of seats
- `timestamp`: Proposal creation timestamp
- `requiredQuorum`: Quorum required at proposal time
- `supporters`: Array of supporting token IDs

---

### Wallet Functions

#### `submitTransaction(uint256 tokenId, address target, uint256 value, bytes memory data)`
Submits a new transaction for approval.

**Parameters**:
- `tokenId`: Director's token ID
- `target`: Target address
- `value`: ETH amount to send
- `data`: Calldata

**Reverts**:
- `NotDirector`: If caller is not a director
- `ZeroAddress`: If target is zero
- `InvalidTransaction`: If target is Chamber itself
- `InsufficientChamberBalance`: If ETH balance < value

**Events**:
- `SubmitTransaction(tokenId, transactionId, target, value, data)`
- `TransactionSubmitted(transactionId, target, value)`

**Access**: Directors only

---

#### `confirmTransaction(uint256 tokenId, uint256 transactionId)`
Confirms a transaction.

**Parameters**:
- `tokenId`: Director's token ID
- `transactionId`: Transaction ID to confirm

**Reverts**:
- `NotDirector`: If caller is not a director
- `TransactionDoesNotExist`: If transaction doesn't exist
- `TransactionAlreadyExecuted`: If already executed
- `TransactionAlreadyConfirmed`: If already confirmed by this tokenId

**Events**:
- `ConfirmTransaction(tokenId, transactionId)`
- `TransactionConfirmed(transactionId, confirmer)`

**Access**: Directors only

---

#### `executeTransaction(uint256 tokenId, uint256 transactionId)`
Executes a transaction if quorum reached.

**Parameters**:
- `tokenId`: Director's token ID
- `transactionId`: Transaction ID to execute

**Reverts**:
- `NotDirector`: If caller is not a director
- `TransactionDoesNotExist`: If transaction doesn't exist
- `TransactionAlreadyExecuted`: If already executed
- `NotEnoughConfirmations`: If quorum not reached

**Events**:
- `ExecuteTransaction(tokenId, transactionId)`
- `TransactionExecuted(transactionId, executor)`

**Access**: Directors only
**Modifiers**: `nonReentrant`

---

#### `revokeConfirmation(uint256 tokenId, uint256 transactionId)`
Revokes a confirmation.

**Parameters**:
- `tokenId`: Director's token ID
- `transactionId`: Transaction ID

**Reverts**:
- `NotDirector`: If caller is not a director
- `TransactionDoesNotExist`: If transaction doesn't exist
- `TransactionAlreadyExecuted`: If already executed
- `TransactionNotConfirmed`: If not confirmed by this tokenId

**Events**:
- `RevokeConfirmation(tokenId, transactionId)`

**Access**: Directors only

---

#### `submitBatchTransactions(uint256 tokenId, address[] memory targets, uint256[] memory values, bytes[] memory data)`
Submits multiple transactions.

**Parameters**:
- `tokenId`: Director's token ID
- `targets`: Array of target addresses
- `values`: Array of ETH amounts
- `data`: Array of calldata

**Reverts**:
- `NotDirector`: If caller is not a director
- `ArrayLengthsMustMatch`: If array lengths differ
- `ZeroAmount`: If arrays are empty
- `InsufficientChamberBalance`: If total ETH balance insufficient
- `ZeroAddress`: If any target is zero
- `InvalidTransaction`: If any target is Chamber

**Events**: `TransactionSubmitted` for each transaction

**Access**: Directors only

---

#### `confirmBatchTransactions(uint256 tokenId, uint256[] memory transactionIds)`
Confirms multiple transactions.

**Parameters**:
- `tokenId`: Director's token ID
- `transactionIds`: Array of transaction IDs

**Reverts**: Same as `confirmTransaction` for each transaction

**Events**: `TransactionConfirmed` for each transaction

**Access**: Directors only

---

#### `executeBatchTransactions(uint256 tokenId, uint256[] memory transactionIds)`
Executes multiple transactions.

**Parameters**:
- `tokenId`: Director's token ID
- `transactionIds`: Array of transaction IDs

**Reverts**: Same as `executeTransaction` for each transaction

**Events**: `TransactionExecuted` for each transaction

**Access**: Directors only
**Modifiers**: `nonReentrant`

---

#### `getTransactionCount() → uint256`
Returns total number of transactions.

**Returns**: Transaction count

---

#### `getTransaction(uint256 nonce) → (bool executed, uint8 confirmations, address target, uint256 value, bytes memory data)`
Returns transaction details.

**Parameters**:
- `nonce`: Transaction index

**Returns**: Transaction struct fields

---

#### `getConfirmation(uint256 tokenId, uint256 nonce) → bool`
Checks if transaction is confirmed by tokenId.

**Parameters**:
- `tokenId`: Token ID to check
- `nonce`: Transaction index

**Returns**: `true` if confirmed, `false` otherwise

---

#### `getNextTransactionId() → uint256`
Returns next transaction ID.

**Returns**: Next transaction ID (equal to transaction count)

---

### Receive functions

#### `receive()`
Accepts native ETH with empty calldata. Emits `Received`.

#### `fallback()`
Accepts native ETH sent with calldata. Emits `Received` when `msg.value > 0`. Unknown selectors do not dispatch privileged logic.

#### `onERC721Received(address operator, address from, uint256 tokenId, bytes data) → bytes4`
ERC-721 receiver hook. Accepts **any** collection (`msg.sender` is not checked against `nft()`). Receipt is treasury custody: it does not mint shares or change board seats. Directors transfer received ERC-721s out via the wallet.

**Returns**: `IERC721Receiver.onERC721Received.selector`

**Events**: `ReceivedERC721(token, from, tokenId)` where `token` is the collection (`msg.sender`)

**Not implemented**: `onERC1155Received` / `onERC1155BatchReceived`. ERC-1155 `safeTransferFrom` to Chamber reverts.

---

### ERC4626 Functions

#### `deposit(uint256 assets, address receiver) → uint256`
Deposits assets and mints shares.

**Parameters**:
- `assets`: Amount of assets to deposit
- `receiver`: Address to receive shares

**Returns**: Shares minted

**Reverts**:
- `AssetAmountMismatch`: If the vault's observed `balanceOf` delta is not equal to `assets` (fee-on-transfer)

**Events**: `Deposit`, `Transfer`

---

#### `withdraw(uint256 assets, address receiver, address owner) → uint256`
Withdraws assets by burning shares.

**Parameters**:
- `assets`: Amount of assets to withdraw
- `receiver`: Address to receive assets
- `owner`: Owner of shares

**Returns**: Shares burned

**Reverts**:
- `ExceedsDelegatedAmount`: If withdrawal would exceed available balance after delegations

**Events**: `Withdraw`, `Transfer`

---

#### `mint(uint256 shares, address receiver) → uint256`
Mints shares for assets.

**Parameters**:
- `shares`: Shares to mint
- `receiver`: Address to receive shares

**Returns**: Assets deposited

**Reverts**:
- `AssetAmountMismatch`: If the vault's observed `balanceOf` delta is not equal to the pulled asset amount (fee-on-transfer)

**Events**: `Deposit`, `Transfer`

---

#### `redeem(uint256 shares, address receiver, address owner) → uint256`
Redeems shares for assets.

**Parameters**:
- `shares`: Shares to redeem
- `receiver`: Address to receive assets
- `owner`: Owner of shares

**Returns**: Assets withdrawn

**Reverts**:
- `ExceedsDelegatedAmount`: If redemption would exceed available balance after delegations

**Events**: `Withdraw`, `Transfer`

---

### ERC20 Functions

#### `transfer(address to, uint256 value) → bool`
Transfers tokens.

**Parameters**:
- `to`: Recipient address
- `value`: Amount to transfer

**Returns**: `true` on success

**Reverts**:
- `TransferToZeroAddress`: If recipient is zero
- `ZeroAmount`: If amount is zero
- `InsufficientChamberBalance`: If balance insufficient
- `ExceedsDelegatedAmount`: If transfer would exceed available balance after delegations

**Events**: `Transfer`

---

#### `transferFrom(address from, address to, uint256 value) → bool`
Transfers tokens from another address.

**Parameters**:
- `from`: Sender address
- `to`: Recipient address
- `value`: Amount to transfer

**Returns**: `true` on success

**Reverts**: Same as `transfer` plus allowance checks

**Events**: `Transfer`

---

## Events

### Registry Events

- `ChamberCreated(address indexed chamber, uint256 seats, string name, string symbol, address erc20Token, address erc721Token)`

### Chamber Events

- `DelegationUpdated(address indexed agent, uint256 indexed tokenId, uint256 amount)`
- `TransactionSubmitted(uint256 indexed transactionId, address indexed target, uint256 value)`
- `TransactionConfirmed(uint256 indexed transactionId, address indexed confirmer)`
- `TransactionExecuted(uint256 indexed transactionId, address indexed executor)`
- `Received(address indexed sender, uint256 amount)`
- `ReceivedERC721(address indexed token, address indexed from, uint256 indexed tokenId)` — any ERC-721 collection; not limited to the membership NFT

### Board Events

- `SetSeats(uint256 indexed tokenId, uint256 numOfSeats)`
- `SeatUpdateCancelled(uint256 indexed tokenId)`
- `ExecuteSetSeats(uint256 indexed tokenId, uint256 seats)`
- `Delegate(address indexed sender, uint256 indexed tokenId, uint256 amount)`
- `Undelegate(address indexed sender, uint256 indexed tokenId, uint256 amount)`

### Wallet Events

- `SubmitTransaction(uint256 indexed tokenId, uint256 indexed nonce, address indexed to, uint256 value, bytes data)`
- `ConfirmTransaction(uint256 indexed tokenId, uint256 indexed nonce)`
- `RevokeConfirmation(uint256 indexed tokenId, uint256 indexed nonce)`
- `ExecuteTransaction(uint256 indexed tokenId, uint256 indexed nonce)`

## Errors

### Registry Errors

- `ZeroAddress()`: Address is zero
- `InvalidSeats()`: Seats value is invalid (0 or > 20)

### Chamber Errors

- `InsufficientDelegatedAmount()`: Insufficient delegated amount
- `InsufficientChamberBalance()`: Insufficient chamber balance
- `ExceedsDelegatedAmount()`: Transfer exceeds delegated amount
- `TransferToZeroAddress()`: Transfer to zero address
- `ArrayLengthsMustMatch()`: Array lengths don't match
- `NotEnoughConfirmations()`: Not enough confirmations
- `NotDirector()`: Caller is not a director
- `DirectorNotSeated()`: Director token is in the top seats but the seating delay has not elapsed
- `ZeroAddress()`: Address is zero
- `ZeroAmount()`: Amount is zero
- `ZeroTokenId()`: Token ID is zero
- `InvalidTokenId()`: Token ID is invalid
- `ZeroSeats()`: Number of seats is zero
- `TooManySeats()`: Too many seats
- `InvalidTransaction()`: Invalid transaction
- `NotAuthorized()`: Upgrade caller is not the chamber, or the chamber is not the ProxyAdmin owner
- `AssetAmountMismatch()`: Vault observed asset delta does not equal the requested deposit/mint amount

### Board Errors

- `AlreadySentUpdateRequest()`: Already sent update request
- `InvalidNumSeats()`: Invalid number of seats
- `NodeDoesNotExist()`: Node does not exist
- `AmountExceedsDelegation()`: Amount exceeds delegation
- `InvalidProposal()`: Invalid proposal
- `TimelockNotExpired()`: Timelock not expired
- `InsufficientVotes()`: Insufficient votes
- `MaxNodesReached()`: Maximum nodes reached
- `CircuitBreakerActive()`: Circuit breaker active

### Wallet Errors

- `TransactionDoesNotExist()`: Transaction does not exist
- `TransactionAlreadyExecuted()`: Transaction already executed
- `TransactionAlreadyConfirmed()`: Transaction already confirmed
- `TransactionNotConfirmed()`: Transaction not confirmed
- `TransactionFailed(bytes reason)`: Transaction execution failed
- `InvalidTarget()`: Invalid target address
