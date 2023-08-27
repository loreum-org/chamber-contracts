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
        uint256[]   voters;
        uint256     approvals;
        State       state;
    }

    error invalidUnStake();

    error invalidStake();

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
     * @notice Emitted upon stake()
     * @param staker   The address staking
     * @param amt      The amount of "stakingToken" staked
     * @param tokenId  The ID of the NFT that tokens will be staked against
     */ 
    event Staked(address staker, uint256 amt, uint256 tokenId);

    /** 
     * @notice Emitted upon unstake()
     * @param staker   The address unstaking
     * @param amt      The amount of "stakingToken" unstaked
     * @param tokenId  The ID of the NFT that tokens were staked against
     */ 
    event Unstaked(address staker, uint256 amt, uint256 tokenId);
    
    /**
     * @notice Emitted when a proposal is approved
     * @param proposalId The unique identifier of the approved proposal
     * @param tokenId      The tokenId that the proposal was associated with
     * @param approvals  The total number of approvals that the proposal received
     */
    event ProposalApproved(uint256 proposalId, uint256 tokenId, uint256 approvals);

    /**
     * @notice Emitted when a proposal is created
     * @param proposalId The unique identifier of the created proposal
     * @param target     The array of addresses that the proposal targets
     * @param value      The array of monetary values associated with each target
     * @param data       The array of data payloads associated with each target
     * @param voters     The array of votes associated with each target
     */
    event ProposalCreated(uint256 proposalId, address[] target, uint256[] value, bytes[] data, uint256[] voters);

    /**
     * @notice Emitted when a proposal is executed
     * @param proposalId The unique identifier of the executed proposal
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @notice Emitted when Ether is received
     * @param sender The address of the sender of the Ether
     * @param value  The amount of Ether received
     */
    event ReceivedEther(address indexed sender, uint256 value);

    /**************************************************
        Functions
     **************************************************/

    /** 
     * @notice approve Proposal function
     * @param  _proposalId The ID of the proposal to approve
     * @param  _tokenId    The ID of the NFT to vote
     */ 
    function approveTx(uint256 _proposalId, uint256 _tokenId) external;

    /** 
     * @notice create Proposal function
     * @param  _target The address of contract to send transaction
     * @param  _value  The uint256 amount of ETH to send with transaction
     * @param  _data   The bytes[] of transaction data
     */
    function createTx(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external;

    /** 
     * @notice Stakes a given amount of "stakingToken" against the provided NFT ID
     * @param _amt      The amount of "stakingToken" to stake
     * @param _tokenId  The ID of the NFT to stake against
     */
    function stake(uint256 _amt, uint256 _tokenId) external;

    /** 
     * @notice Unstakes a given amount of "stakingToken" from the provided NFT ID
     * @param _amt      The amount of "stakingToken" to unstake
     * @param _tokenId  The ID of the NFT to unstake from
     */ 
    function unstake(uint256 _amt, uint256 _tokenId) external;
}