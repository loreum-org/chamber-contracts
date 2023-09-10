// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IChamber {

     /// @notice The State of a proposal
    enum State { Null, Initialized, Executed }

    /// @notice The structue of a proposal
    struct Proposal {
        address[]   target;
        uint256[]   value;
        bytes[]     data;
        uint8[5]     voters;
        uint8     approvals;
        State       state;
    }

    error invalidDemotion();

    error invalidPromotion();

    error invalidTokenOwner();

    error invalidProposalState();

    error invalidVote();

    error executionFailed();

    error insufficientBalance();

    error invalidApproval(string message);

    error invalidChangeAmount();


    /**************************************************
        Events
     **************************************************/

    /** 
     * @notice Emitted upon promote()
     * @param promoter   The address of the promoter
     * @param amt        The amount of "govToken" delegated
     * @param tokenId    The ID of the NFT that tokens will be promoted against
     */ 
    event Promoted(address promoter, uint256 amt, uint8 tokenId);

    /** 
     * @notice Emitted upon demote()
     * @param demoter   The address of the demoter
     * @param amt       The amount of "govToken" demoted
     * @param tokenId   The ID of the NFT that tokens were demoted against
     */ 
    event Demoted(address demoter, uint256 amt, uint8 tokenId);
    
    /**
     * @notice Emitted when a proposal is approved
     * @param proposalId The unique identifier of the approved proposal
     * @param tokenId    The tokenId that the proposal was associated with
     * @param approvals  The total number of approvals that the proposal received
     */
    event ProposalApproved(uint8 proposalId, uint8 tokenId, uint256 approvals);

    /**
     * @notice Emitted when a proposal is created
     * @param proposalId    The unique identifier of the created proposal
     * @param target        The array of addresses that the proposal targets
     * @param value         The array of monetary values associated with each target
     * @param data          The array of data payloads associated with each target
     * @param voters        The array of voters associated with each target
     */
    event ProposalCreated(uint8 proposalId, address[] target, uint256[] value, bytes[] data, uint8[5] voters);

    /**
     * @notice Emitted when a proposal is executed
     * @param proposalId The unique identifier of the executed proposal
     */
    event ProposalExecuted(uint8 proposalId);

    /**
     * @notice Emitted when Ether is received
     * @param sender The address of the sender of the Ether
     * @param value  The amount of Ether received
     */
    event ReceivedEther(address indexed sender, uint256 value);

    /**
     * @notice Emitted when Payable received
     * @param sender The address of Asset sender
     * @param value  The amount received
     */
    event ReceivedFallback(address indexed sender, uint256 value);

    /**************************************************
        Functions
     **************************************************/

    /// @notice Initializes the Chamber
    function initialize(address _memberToken, address _govToken) external;
    
    /// @notice Returns the version of the Chamber
    function version() external view returns (string memory);

    /// @notice Returns the amount of govToken delegated against a given tokenId by an account
    function accountDelegation(address _account, uint8 _tokenId) external view returns (uint256);

    /// @notice Returns the total amount of govToken delegated against a given tokenId
    function totalDelegation(uint8 _tokenId) external view returns (uint256);

    /// @notice Returns the total number of proposals
    function proposalCount() external view returns (uint8);

    /// @notice Returns the number of approvals and the state of a proposal
    function proposals(uint8 _proposalId) external view returns (uint8 approvals, State state);

    /// @notice Returns two arrays, the leaders and their delegations
    function getLeaderboard() external view returns (uint8[5] memory, uint256[5] memory);

    /** 
     * @notice approve Proposal function
     * @param  _proposalId The ID of the proposal to approve
     * @param  _tokenId    The ID of the NFT to vote
     */ 
    function approveProposal(uint8 _proposalId, uint8 _tokenId) external;

    /** 
     * @notice create Proposal function
     * @param  _target The address of contract to send transaction
     * @param  _value  The uint256 amount of ETH to send with transaction
     * @param  _data   The bytes[] of transaction data
     */
    function createProposal(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external;

    /** 
     * @notice Promotes an amount of govToken against a provided memberToken Id
     * @param _amt      The amount of govToken for promotion
     * @param _tokenId  The Id of the memberToken to promote
     */
    function promote(uint256 _amt, uint8 _tokenId) external;

    /** 
     * @notice Demotes an amount of govToken from the provided memberToken Id
     * @param _amt      The amount of govToken for demotion
     * @param _tokenId  The Id of the memberToken to demote from
     */ 
    function demote(uint256 _amt, uint8 _tokenId) external;
}