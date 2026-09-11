// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IBoard} from "./IBoard.sol";
import {IWallet} from "./IWallet.sol";

/**
 * @title IChamber
 * @author xhad, Loreum DAO LLC
 * @notice Interface for the Chamber: ERC-4626 vault, delegation-weighted board, and director multisig wallet.
 * @dev Combines {IERC4626}, {IBoard}, and {IWallet}. Errors and events from those parents apply unless
 *      overridden or extended below. Share token transfers enforce that delegated weight cannot be stranded.
 */
interface IChamber is IERC4626, IBoard, IWallet {
    /**
     * @notice Initializes the proxy; callable once by the proxy during deployment.
     * @param erc20Token Standard ERC-20 vault asset (no fee-on-transfer or rebasing; see Chamber natspec)
     * @param erc721Token Membership ERC-721 whose holders may be directors when in top seats
     * @param seats Initial board seat count (must be 1..20 inclusive)
     * @param name ERC-20 name for chamber share tokens
     * @param symbol ERC-20 symbol for chamber share tokens
     */
    function initialize(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol
    ) external;

    /**
     * @notice Delegates a specified amount of tokens to a tokenId
     * @param tokenId The tokenId to which tokens are delegated
     * @param amount The amount of tokens to delegate
     */
    function delegate(uint256 tokenId, uint256 amount) external;

    /**
     * @notice Undelegates a specified amount of tokens from a tokenId
     * @param tokenId The tokenId from which tokens are undelegated
     * @param amount The amount of tokens to undelegate
     */
    function undelegate(uint256 tokenId, uint256 amount) external;

    /**
     * @notice Returns the list of tokenIds to which the holder has delegated tokens and the corresponding amounts
     * @dev Includes tokenIds evicted from the board leaderboard while the holder still has a positive amount.
     *      After an in-place upgrade the per-holder set is empty; leftover mapping amounts are still
     *      returned via a read-side union with the live board and the eviction index.
     * @param holder The address holding Chamber shares that delegated voting weight
     * @return tokenIds The list of tokenIds
     * @return amounts The list of amounts delegated to each tokenId
     */
    function getDelegations(address holder) external view returns (uint256[] memory tokenIds, uint256[] memory amounts);

    /**
     * @notice Returns the amount delegated by a holder to a specific membership tokenId
     * @param holder The delegating holder address
     * @param tokenId The token ID
     * @return amount The amount delegated
     */
    function getHolderDelegation(address holder, uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the total amount delegated by a holder across all tokenIds
     * @param holder The delegating holder address
     * @return amount The total amount delegated
     */
    function getTotalHolderDelegations(address holder) external view returns (uint256);

    /**
     * @notice Registers or clears the session key for a contract-owned membership NFT.
     * @dev Only `ownerOf(tokenId)` may call, and only when that owner is a contract.
     *      Chamber never consults ERC-1271. See docs/protocol/director-authorization.md.
     * @param tokenId Membership token the caller owns
     * @param operator Session key that may act for `tokenId`, or `address(0)` to clear
     */
    function setDirectorOperator(uint256 tokenId, address operator) external;

    /**
     * @notice Live session key for `tokenId`, or `address(0)` if none or stale.
     * @dev Stale after NFT transfer or while the current owner is an EOA.
     */
    function getDirectorOperator(uint256 tokenId) external view returns (address operator);

    /**
     * @notice Whether `account` may act for `tokenId` (owner or live session key).
     * @dev Does not check board seats or seating delay. Burned tokens return false.
     */
    function isTokenAuthorized(uint256 tokenId, address account) external view returns (bool);

    /**
     * @notice Binds `seatedAt` to the current `ownerOf(tokenId)` (PMN-H01 Solution A).
     * @dev Permissionless. Call after a seated NFT changes hands so the new controller's
     *      `SEATING_DELAY` is stored. Director actions that revert do not persist this write.
     * @param tokenId Membership token to rebind
     */
    function syncSeating(uint256 tokenId) external;

    /**
     * @notice Top-seat tokenIds that can still authorize (`ownerOf` succeeds, owner is not the chamber).
     * @dev Denominator for {getQuorum} (PMN-M01). Does not compact leaderboard rank (#210).
     */
    function getReachableDirectorCount() external view returns (uint256);

    /**
     * @notice Updates the number of seats
     * @param tokenId The tokenId proposing the update
     * @param numOfSeats The new number of seats
     */
    function updateSeats(uint256 tokenId, uint256 numOfSeats) external;

    /**
     * @notice Lowers `seats` when filled authorized directors are below the configured-seat quorum.
     * @dev PMN-M01 Solution C. Dedicated recovery; not an allowed wallet self-call, so ordinary
     *      spend cannot use this path. `newSeats` must be in `[1, filled]` and `< getSeats()`.
     * @param tokenId Director token authorizing the recovery
     * @param newSeats Seat count after recovery
     */
    function recoverSeats(uint256 tokenId, uint256 newSeats) external;

    /**
     * @notice Executes a pending seat update proposal if it has enough support and the timelock has expired
     * @param tokenId The tokenId executing the update
     */
    function executeSeatsUpdate(uint256 tokenId) external;

    /**
     * @notice Deletes the pending seat-update proposal.
     * @dev The original proposer may cancel at any time. After the 14-day expiry, any current
     *      director may clear the single slot (H-03). Does not change the 7-day execute timelock.
     * @param tokenId The director token ID requesting cancellation
     */
    function cancelSeatUpdate(uint256 tokenId) external;

    /**
     * @notice Optional hook reserved for registry flows; current implementation is a no-op.
     * @dev The registry transfers `ProxyAdmin` ownership to the chamber directly after deployment.
     */
    function acceptAdmin() external;

    /**
     * @notice Returns the `ProxyAdmin` contract address for this transparent proxy (ERC-1967 admin slot).
     * @return adminContract The OpenZeppelin `ProxyAdmin` instance controlling upgrades for this chamber
     */
    function getProxyAdmin() external view returns (address adminContract);

    /**
     * @notice Performs an implementation upgrade via the chamber-owned `ProxyAdmin`.
     * @dev Must be called with `msg.sender == address(this)` (e.g. via `executeTransaction`). Requires
     *      `ProxyAdmin.owner() == address(this)` and non-zero `newImplementation`.
     * @param newImplementation Address of the new implementation contract
     * @param data Optional data forwarded to `upgradeAndCall` (e.g. initializer on the new implementation)
     */
    function upgradeImplementation(address newImplementation, bytes calldata data) external;

    /**
     * @notice Pauses vault deposit/withdraw/mint/redeem and wallet execution.
     * @dev Must be called with `msg.sender == address(this)` after board quorum (via `executeTransaction`).
     *      Direct EOA or director calls revert. While paused, only a quorum self-call to {unpause} may execute.
     */
    function pause() external;

    /**
     * @notice Unpauses vault operations and wallet execution.
     * @dev Must be called with `msg.sender == address(this)` after board quorum (via `executeTransaction`).
     */
    function unpause() external;

    /**
     * @notice Returns true if the chamber is paused.
     */
    function paused() external view returns (bool);

    /// Events
    /**
     * @notice Emitted when delegation is updated
     * @param holder The address delegating Chamber shares
     * @param tokenId The tokenId being delegated to
     * @param amount The amount delegated
     */
    event DelegationUpdated(address indexed holder, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when a transaction is submitted (Chamber-specific event)
     * @param transactionId The ID of the submitted transaction
     * @param target The target address
     * @param value The ETH value
     */
    event TransactionSubmitted(uint256 indexed transactionId, address indexed target, uint256 value);

    /**
     * @notice Emitted when a transaction is confirmed (Chamber-specific event)
     * @param transactionId The ID of the confirmed transaction
     * @param confirmer The address of the confirmer
     */
    event TransactionConfirmed(uint256 indexed transactionId, address indexed confirmer);

    /**
     * @notice Emitted when a transaction is executed (Chamber-specific event)
     * @param transactionId The ID of the executed transaction
     * @param executor The address of the executor
     */
    event TransactionExecuted(uint256 indexed transactionId, address indexed executor);

    /**
     * @notice Emitted when a director votes to cancel a transaction
     * @param transactionId The ID of the transaction
     * @param voter The address of the director voting to cancel
     */
    event TransactionCancelVoted(uint256 indexed transactionId, address indexed voter);

    /**
     * @notice Emitted when the contract receives Ether
     * @param sender The address that sent the Ether
     * @param amount The amount of Ether received
     */
    event Received(address indexed sender, uint256 amount);

    /**
     * @notice Emitted when the contract receives an ERC-721 via `safeTransferFrom`.
     * @param token The ERC-721 collection (`msg.sender`); any collection is accepted
     * @param from The previous owner
     * @param tokenId The token ID received
     * @dev Receipt is treasury custody, not a membership or vault deposit. ERC-1155
     *      intake is not implemented.
     */
    event ReceivedERC721(address indexed token, address indexed from, uint256 indexed tokenId);

    /**
     * @notice Emitted when a contract NFT owner sets or clears a session key.
     * @param tokenId Membership token
     * @param owner Owner that registered the key (`ownerOf` at the time of the call)
     * @param operator Session key, or `address(0)` when cleared
     */
    event DirectorOperatorSet(uint256 indexed tokenId, address indexed owner, address indexed operator);

    /**
     * @notice Emitted when {recoverSeats} lowers the configured seat count (PMN-M01 C).
     * @param tokenId Director token that authorized the recovery
     * @param previousSeats Seat count before recovery
     * @param newSeats Seat count after recovery
     */
    event SeatsRecovered(uint256 indexed tokenId, uint256 previousSeats, uint256 newSeats);

    /// Errors
    /// @notice Thrown when there is insufficient delegated amount
    error InsufficientDelegatedAmount();

    /// @notice Thrown when chamber balance is insufficient
    error InsufficientChamberBalance();

    /// @notice Thrown when transfer would exceed delegated amount
    error ExceedsDelegatedAmount();

    /// @notice Thrown when trying to transfer to zero address
    error TransferToZeroAddress();

    /// @notice Thrown when array lengths don't match
    error ArrayLengthsMustMatch();

    /// @notice Thrown when there are not enough confirmations
    error NotEnoughConfirmations();

    /// @notice Thrown when caller is not a director
    error NotDirector();

    /// @notice Thrown when a tokenId is in the live top seats but the seating delay has not elapsed
    ///         (new top-seat entry, or `ownerOf` change since the last seating bind).
    error DirectorNotSeated();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when tokenId is zero
    error ZeroTokenId();

    /// @notice Thrown when tokenId is invalid
    error InvalidTokenId();

    /// @notice Thrown when number of seats is zero
    error ZeroSeats();

    /// @notice Thrown when {recoverSeats} is not available or `newSeats` is out of range (PMN-M01 C)
    error SeatRecoveryUnavailable();

    /// @notice Thrown when number of seats exceeds maximum
    error TooManySeats();

    /// @notice Thrown when transaction is invalid
    error InvalidTransaction();

    /// @notice Thrown when the caller is not authorized for an upgrade, or this
    ///         chamber is not the `ProxyAdmin` owner.
    error NotAuthorized();

    /// @notice Thrown when the vault's observed asset delta does not equal the requested amount
    /// @dev Rejects fee-on-transfer / deflating tokens on deposit and mint
    error AssetAmountMismatch();
}
