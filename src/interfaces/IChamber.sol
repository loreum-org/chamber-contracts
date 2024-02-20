// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IGuardManager.sol";

interface IChamber is IGuardManager{

    /**************************************************
        State
     **************************************************/

     /// @notice The State of a proposal
    enum State { Null, Initialized, Executed, Canceled }

    /// @notice The structue of a proposal
    struct Proposal {
        address[]   target;
        uint256[]   value;
        bytes[]     data;
        uint256[5]  voters;
        uint256     approvals;
        uint256     nonce;
        State       state;
    }

    /**************************************************
        Events
     **************************************************/

    /// @notice Emitted upon promote()
    /// @param promoter   The address of the promoter
    /// @param amt        The amount of "govToken" delegated
    /// @param tokenId    The ID of the NFT that tokens will be promoted against
    event Promoted(address promoter, uint256 amt, uint256 tokenId);

    /// @notice Emitted upon demote()
    /// @param demoter   The address of the demoter
    /// @param amt       The amount of "govToken" demoted
    /// @param tokenId   The ID of the NFT that tokens were demoted against
    event Demoted(address demoter, uint256 amt, uint256 tokenId);
    
    /// @notice Emitted when a proposal is approved
    /// @param proposalId The unique identifier of the approved proposal
    /// @param tokenId    The tokenId that the proposal was associated with
    /// @param approvals  The total number of approvals that the proposal received
    event ProposalApproved(uint256 proposalId, uint256 tokenId, uint256 approvals);

    /// @notice Emitted when a proposal is created
    /// @param proposalId    The unique identifier of the created proposal
    /// @param target        The array of addresses that the proposal targets
    /// @param value         The array of monetary values associated with each target
    /// @param data          The array of data payloads associated with each target
    /// @param voters        The array of voters associated with each target
    /// @param nonce         The nonce associated with the created proposal
    event ProposalCreated(uint256 proposalId, address[] target, uint256[] value, bytes[] data, uint256[5] voters, uint256 nonce);

    /// @notice Emitted when a proposal is executed
    /// @param proposalId The unique identifier of the executed proposal
    event ProposalExecuted(uint256 proposalId);

    /// @notice Emitted when a proposal is canceled
    /// @param proposalId The unique identifier of the executed proposal
    event ProposalCanceled(uint256 proposalId);

    /// @notice Emitted when Ether is received
    /// @param sender The address of the sender of the Ether
    /// @param value  The amount of Ether received
    event ReceivedEther(address indexed sender, uint256 value);

    /// @notice Emitted when Payable received
    /// @param sender The address of Asset sender
    /// @param value  The amount received
    event ReceivedFallback(address indexed sender, uint256 value);

    /**************************************************
        Functions
     **************************************************/

    /// @notice Initializes a new version of Chamber
    /// @param memberToken  The address of the ERC721 contract used for membership.
    /// @param govToken     The address of the ERC20 contract used for delegation.
    function initialize(address memberToken, address govToken) external;

    /// @notice Returns the amount of govToken delegated against a given tokenId by an account
    /// @param account The address of the account to query
    /// @param tokenId The ID of the NFT to query
    function accountDelegation(address account, uint256 tokenId) external view returns (uint256);

    /// @notice Returns the total amount of govToken delegated against a given tokenId
    /// @param tokenId The ID of the NFT to query
    function totalDelegation(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the total number of proposals
    function proposalCount() external view returns (uint256);

    /// @notice Returns the number of approvals and the state of a proposal
    /// @param proposalId The ID of the proposal to query
    function proposal(uint256 proposalId) external view returns (uint256 approvals, State state);

    /// @notice Returns two arrays, the leaders and their delegations
    function getLeaderboard() external view returns (uint256[] memory, uint256[] memory);


    /// @notice approve Proposal function
    /// @param  proposalId The ID of the proposal to approve
    /// @param  tokenId    The ID of the NFT to vote 
    /// @param  signature  The cryptographic signature to be verified
    function approveProposal(uint256 proposalId, uint256 tokenId,bytes memory signature) external;

    /// @notice execute Proposal function
    /// @param  proposalId The ID of the proposal to approve
    /// @param  tokenId    The ID of the NFT to vote 
    /// @param  signature  The cryptographic signature to be verified
    function executeProposal(uint256 proposalId, uint256 tokenId, bytes memory signature) external;

    /// @notice cancel Proposal function
    /// @param  proposalId The ID of the proposal to cancel
    function cancelProposal(uint256 proposalId) external;

    /// @notice create Proposal function
    /// @param  target The address of contract to send transaction
    /// @param  value  The uint256 amount of ETH to send with transaction
    /// @param  data   The bytes[] of transaction data
    function createProposal(address[] memory target, uint256[] memory value, bytes[] memory data) external;

    /// @notice Promotes an amount of govToken against a provided memberToken Id
    /// @param amount   The amount of govToken for promotion
    /// @param tokenId  The Id of the memberToken to promote
    function promote(uint256 amount, uint256 tokenId) external;

    /// @notice Demotes an amount of govToken from the provided memberToken Id
    /// @param amount   The amount of govToken for demotion
    /// @param tokenId  The Id of the memberToken to demote from 
    function demote(uint256 amount, uint256 tokenId) external;

    /// @notice Returns the domain separator for this contract, as defined in the EIP-712 standard.
    /// @return bytes32 The domain separator hash.
    function domainSeparator() external view returns (bytes32);

    /// @notice verify Signature function
    /// @param  proposalId The ID of the proposal to approve
    /// @param  tokenId    The ID of the NFT to vote 
    /// @param  signature  The cryptographic signature to be verified
    function verifySignature(uint256 proposalId, uint256 tokenId, bytes memory signature) external view returns (bool);

    /// @notice construct Message Hash function
    /// @param  proposalId The ID of the proposal to approve
    /// @param  tokenId    The ID of the NFT to vote 
    function constructMessageHash(uint256 proposalId, uint256 tokenId) external view returns (bytes32);

    /**************************************************
        Errors
     **************************************************/

    error invalidDemotion();

    error invalidPromotion();

    error invalidTokenOwner();

    error invalidProposalState();

    error invalidVote();

    error executionFailed();

    error insufficientBalance();

    error invalidApproval(string message);

    error invalidChangeAmount();
}