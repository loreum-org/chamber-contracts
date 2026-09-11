// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IBoard
 * @author xhad, Loreum DAO LLC
 * @notice Read API and events for the delegation-weighted sorted board (linked list by stake).
 * @dev Canonical structs live in {Board}: packed `Node` (`uint128` next/prev) and `SeatUpdate`.
 */
interface IBoard {
    /**
     * @notice Returns on-list data for a membership `tokenId` (zero values if not in the list).
     * @param tokenId The ERC-721 membership token ID
     * @return nodeTokenId Same as `tokenId` when the node exists, else zero
     * @return amount Total delegated weight for this token in the board list
     * @return next Token ID of the next node toward the tail (ascending rank), or zero
     * @return prev Token ID of the previous node toward the head, or zero
     */
    function getMember(uint256 tokenId)
        external
        view
        returns (uint256 nodeTokenId, uint256 amount, uint256 next, uint256 prev);

    /**
     * @notice Returns the first `count` entries in descending delegation order.
     * @param count Maximum number of `(tokenId, amount)` pairs to return
     * @return tokenIds Leaderboard token IDs
     * @return amounts Delegated amounts aligned with `tokenIds`
     */
    function getTop(uint256 count) external view returns (uint256[] memory tokenIds, uint256[] memory amounts);

    /**
     * @notice Number of nodes currently in the leaderboard list (capped by `MAX_NODES` in `Board`).
     * @return size Current list length
     */
    function getSize() external view returns (uint256 size);

    /**
     * @notice Wallet confirmation threshold: `1 + (n * 51) / 100` distinct director tokens.
     * @dev `n` is the number of reachable authorized top-seat `tokenId`s (`ownerOf` succeeds
     *      and the owner is not the chamber). Empty seats and burned/inert ids do not inflate
     *      `n` (PMN-M01). Integer (truncating) division. One- and two-director boards require
     *      all reachable directors. Quorum is token-weighted, not 1-address-1-vote. One address
     *      holding `quorum` top-seat NFTs is a single-actor treasury.
     * @return quorum Minimum confirmations required to execute a transaction
     */
    function getQuorum() external view returns (uint256 quorum);

    /**
     * @notice Governance parameter: how many top entries count as director seats.
     * @return seats Configured seat count
     */
    function getSeats() external view returns (uint256 seats);

    /**
     * @notice Resolves each top-seat `tokenId` to `IERC721.ownerOf`; burned or invalid IDs yield `address(0)`.
     * @return directors Owner addresses for the top `getSeats()` token IDs, in rank order
     */
    function getDirectors() external view returns (address[] memory directors);

    /**
     * @notice First block at which `tokenId` may exercise director rights.
     * @dev Zero means no checkpoint: a pre-upgrade incumbent already in the top set
     *      (treated as mature), or a token that is not seated. Newly entering tokenIds
     *      are set to `block.number + SEATING_DELAY`. After `ownerOf` changes for an
     *      already-seated token, the effective value moves to `block.number + SEATING_DELAY`
     *      until the new controller's delay elapses (PMN-H01 Solution A).
     * @param tokenId The membership token ID
     * @return seatedAtBlock Activation block, or zero if no checkpoint is stored
     */
    function getSeatedAt(uint256 tokenId) external view returns (uint256 seatedAtBlock);

    /**
     * @notice Active seat-change proposal, if any.
     * @return proposedSeats Target seat count
     * @return timestamp Proposal start (`block.timestamp`); zero if no proposal
     * @return requiredQuorum Supporter count required at execution (from proposal time)
     * @return supporters Token IDs that have endorsed this proposal
     */
    function getSeatUpdate()
        external
        view
        returns (uint256 proposedSeats, uint256 timestamp, uint256 requiredQuorum, uint256[] memory supporters);

    /// Events
    /**
     * @notice Emitted when the number of seats is set
     * @param tokenId The tokenId that called the function
     * @param numOfSeats The new number of seats
     */
    event SetSeats(uint256 indexed tokenId, uint256 numOfSeats);

    /**
     * @notice Emitted when a seat update proposal is cancelled
     * @param tokenId The tokenId who cancelled the proposal
     */
    event SeatUpdateCancelled(uint256 indexed tokenId);

    /**
     * @notice Emitted when a call to set the number of seats is made
     * @param tokenId The tokenId that called the function
     * @param seats The number of seats
     */
    event ExecuteSetSeats(uint256 indexed tokenId, uint256 seats);

    /**
     * @notice Emitted when a user delegates tokens to a tokenId
     * @param sender The address of the user delegating tokens
     * @param tokenId The tokenId to which tokens are delegated
     * @param amount The amount of tokens delegated
     */
    event Delegate(address indexed sender, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when a user undelegates tokens from a tokenId
     * @param sender The address of the user undelegating tokens
     * @param tokenId The tokenId from which tokens are undelegated
     * @param amount The amount of tokens undelegated
     */
    event Undelegate(address indexed sender, uint256 indexed tokenId, uint256 amount);

    /// Errors
    /// @notice Thrown when an update request has already been sent by the caller
    error AlreadySentUpdateRequest();

    /// @notice Thrown when the number of seats provided is invalid
    error InvalidNumSeats();

    /// @notice Thrown when the node does not exist
    error NodeDoesNotExist();

    /// @notice Thrown when the amount exceeds the delegation
    error AmountExceedsDelegation();

    /// @notice Thrown when the proposal ID is invalid or does not exist
    error InvalidProposal();

    /// @notice Thrown when attempting to execute a proposal before its timelock period has expired
    error TimelockNotExpired();

    /// @notice Thrown if updateSeats execution call hasn't got enough votes
    error InsufficientVotes();

    /// @notice Thrown when the linked list has reached its maximum size
    error MaxNodesReached();

    /// @notice Deprecated: reentrancy now reverts with OZ `ReentrancyGuardReentrantCall`.
    ///         Kept for ABI compatibility.
    error CircuitBreakerActive();

    /// @notice Thrown when a non-proposer attempts to cancel a seat update proposal before expiry (Fix Finding 14 / H-03)
    error OnlyProposerCanCancel();

    /// @notice Thrown when a tokenId exceeds type(uint128).max (Node.next/prev are packed as uint128)
    error TokenIdTooLarge();
}
