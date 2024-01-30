// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import "./GuardManager.sol";
import "./Common.sol";

contract Chamber is IChamber, Common, GuardManager{
    using ECDSA for bytes32;

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH= 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    /// @notice memberToken The ERC721 contract used for membership.
    address public memberToken;

    /// @notice govToken The ERC20 contract used for staking.
    address public govToken;

    /// @notice leaderboard ff members based on total delegation.
    /// @dev    Limited to maximum 5 leaders requiring 3 approvals
    uint8[] public leaderboard;

    /// @notice proposalCount The number of proposals.
    uint8 public proposalCount;

    /// @notice Counter to track the nonce for each proposal
    uint256 public nonce;

    /// @notice totalDelegation Tracks the amount of govToken delegated to a given NFT ID.
    /// @dev    1st element -> NFT tokenID, 2nd element -> amountDelegated.
    mapping(uint8 => uint256) public totalDelegation;

    /// @notice accountDelegation Tracks a given address's delegatation balance of govToken for a given NFT ID.
    /// @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountDelegated.
    mapping(address => mapping(uint8 => uint256)) public accountDelegation;
    
    /// @notice proposals Mapping of the Proposals.
    /// @dev    1st element -> index, 2nd element -> Proposal struct
    mapping(uint8 => Proposal) private proposals;

    /// @inheritdoc IChamber
    function proposal(uint8 proposalId) public view returns(uint8 approvals, State state){
        return (proposals[proposalId].approvals, proposals[proposalId].state);
    }

    /// @notice vtoed Tracks which tokenIds have voted on proposals
    /// @dev    1st element -> proposalId, 2nd element -> tokenId, 3rd element-> voted boolean
    mapping(uint8 => mapping(uint8 => bool)) public voted;

    /// @notice contrcutor disables initialize function on deployment of base implementation.
    constructor() { _disableInitializers(); }
    
    /// @inheritdoc IChamber
    function initialize(address _memberToken, address _govToken) external initializer {
        memberToken = _memberToken;
        govToken = _govToken;
    }
    
    /// @inheritdoc IChamber
    function getLeaderboard() external view returns (uint8[] memory, uint256[] memory) {
        uint8[] memory _leaderboard = leaderboard;
        uint256[] memory _delegations = new uint256[](_leaderboard.length);
        for (uint8 i = 0; i < _leaderboard.length; i++) {
            _delegations[i] = totalDelegation[_leaderboard[i]];
        }
        return (_leaderboard, _delegations);
    }

    /// @inheritdoc IChamber
    function createProposal(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {
        if(IERC721(memberToken).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        uint8[5] memory topFiveLeader;
        for (uint8 i=0; i<5; i++){
            topFiveLeader[i]= leaderboard[i];
        }
        proposalCount++;
        nonce++;
        proposals[proposalCount] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            voters: topFiveLeader,
            approvals: 0,
            nonce: nonce,
            state: State.Initialized
        });
        emit ProposalCreated(proposalCount, _target, _value, _data, topFiveLeader, nonce);
    }

    /// @inheritdoc IChamber
    function approveProposal(uint8 _proposalId, uint8 _tokenId, bytes memory _signature) external {
        if(_msgSender() != IERC721(memberToken).ownerOf(_tokenId)) revert invalidApproval("Sender isn't NFT owner");
        if(proposals[_proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[_proposalId][_tokenId]) revert invalidApproval("TokenID already voted");

        require(verifySignature(_proposalId, _tokenId, _signature), "Invalid signature");

        uint8[5] memory voters = proposals[_proposalId].voters;
        bool onVoterList = false;

        for (uint i = 0; i < voters.length; i++) {
            if (_tokenId == voters[i]) onVoterList = true;
        }

        if (!onVoterList) revert invalidApproval("TokenId not on voter list");

        voted[_proposalId][_tokenId] = true;
        proposals[_proposalId].approvals += 1;
        emit ProposalApproved(_proposalId, _tokenId, proposals[_proposalId].approvals);
        if (proposals[_proposalId].approvals == 3) { // TODO: Make quorum dynamic
            _executeProposal(_proposalId, _tokenId, _signature);
        }
    }

    /// @inheritdoc IChamber
    function promote(uint256 _amt, uint8 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidPromotion();
        
        totalDelegation[_tokenId] += _amt;
        accountDelegation[_msgSender()][_tokenId] += _amt;
        _updateLeaderboard(_tokenId);
        
        SafeERC20.safeTransferFrom(IERC20(govToken), _msgSender(), address(this), _amt);
        emit Promoted(_msgSender(), _amt, _tokenId);
    }

    /// @inheritdoc IChamber
    function demote(uint256 _amt, uint8 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidDemotion();
        if(accountDelegation[_msgSender()][_tokenId] < _amt) revert invalidDemotion();
        
        totalDelegation[_tokenId] -= _amt;
        accountDelegation[_msgSender()][_tokenId] -= _amt;
        if (totalDelegation[_tokenId]== 0){
            _removeFromLeaderboard(_tokenId);
        }else{
            _updateLeaderboard(_tokenId);
        }
        
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), _amt);
        emit Demoted(_msgSender(), _amt, _tokenId);
    }

    /// @notice _executeProposal function executes the proposal
    /// @param  _proposalId The ID of the proposal to execute.
    function _executeProposal(uint8 _proposalId, uint8 _tokenId, bytes memory _signature) private {

        // TODO Implement Gas handling and Optimizations
        // TODO Implement before and after guards

        if(proposals[_proposalId].state != State.Initialized) revert invalidProposalState();
       
        Proposal memory proposalData = proposals[_proposalId];
        proposals[_proposalId].state = State.Executed;

        address guard = getGuard();
        if (guard != address (0)){
            Guard(guard).checkTransaction(
                proposals[_proposalId].target,
                proposals[_proposalId].value,
                proposals[_proposalId].data,
                proposals[_proposalId].voters,
                proposals[_proposalId].state,
                _signature,
                msg.sender,
                _proposalId,
                _tokenId
            );
        }
        bool finalSuccess;
        for (uint256 i = 0; i < proposalData.data.length; i++) {
            (bool success,) = proposalData.target[i].call{value: proposalData.value[i]}(proposalData.data[i]);
            finalSuccess = success;
            if(!success) revert executionFailed();
        }
        emit ProposalExecuted(_proposalId);
        {
            if (guard != address(0)){
                Guard(guard).checkAfterExecution(constructMessageHash(_proposalId, _tokenId), finalSuccess);
            }
        }
    }

    /// @notice _updateLeaderboard Updates the leaderboard array 
    /// @param _tokenId The ID of the NFT to update.
    function _updateLeaderboard(uint8 _tokenId) private {
        bool tokenIdExists = false;
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i] == _tokenId) {
                tokenIdExists = true;
                break;
            }
        }
        if (tokenIdExists) {
            _bubbleSort();
        } else {
            leaderboard.push(_tokenId);
            _bubbleSort();
        }
    }

    /// @notice _bubbleSort Updates the leaderboard with bubble sort
    function _bubbleSort() private {
        bool swapped;
        for (uint256 i = 0; i < leaderboard.length; i++) {
            swapped = false;
            for (uint256 j = 0; j < leaderboard.length - i - 1; j++) {
                if (totalDelegation[leaderboard[j]] < totalDelegation[leaderboard[j + 1]]) {
                    (leaderboard[j], leaderboard[j + 1]) = (leaderboard[j + 1], leaderboard[j]);
                    swapped = true;
                }
            }
            if (!swapped) {
                break;
            }
        }
    }

    /// @notice _removeFromLeaderboard Removes the Token ID
    /// @param _tokenId The ID of the NFT to remove.
    function _removeFromLeaderboard(uint8 _tokenId) private {
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i] == _tokenId) {
                for (uint256 j = i; j < leaderboard.length - 1; j++) {
                    leaderboard[j] = leaderboard[j + 1];
                }
                leaderboard.pop();
                break;
            }
        }
    }

    /// @inheritdoc IChamber
    function verifySignature(
        uint8 _proposalId,
        uint8 _tokenId,
        bytes memory _signature
    ) public view returns (bool) {
        bytes32 messageHash = constructMessageHash(_proposalId, _tokenId);
        address signer = ECDSA.recover(messageHash, _signature);
        return signer == IERC721(memberToken).ownerOf(_tokenId);
    }

    /// @inheritdoc IChamber
    function domainSeparator() public view returns (bytes32) {
        uint256 chainId;
        assembly {
           chainId := chainid()
        }
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this));
    }

    function encodeData(
        address[] memory _to,
        uint256[] memory _value,
        bytes[]   memory _data,
        uint8[5]  memory _voters,
        uint8            _approvals,
        uint256          _nonce,
        State            _state,
        uint256          _proposalId,
        uint8            _tokenId
    )internal view returns(bytes memory){
        bytes32 txHash  = keccak256(
            abi.encode(
                _to,
                _value,
                _data,
                _voters,
                _approvals,
                _nonce,
                _state,
                _proposalId,
                _tokenId
            )
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), txHash);
    }

    /// @inheritdoc IChamber
    function constructMessageHash(
        uint8 _proposalId, 
        uint8 _tokenId
    ) public view returns (bytes32) {
        return keccak256(
            encodeData(
                proposals[_proposalId].target,
                proposals[_proposalId].value,
                proposals[_proposalId].data,
                proposals[_proposalId].voters,
                proposals[_proposalId].approvals,
                proposals[_proposalId].nonce,
                proposals[_proposalId].state,
                _proposalId,
                _tokenId
            )
        );
    }

    fallback() external payable {
        if (msg.value > 0) emit ReceivedEther(_msgSender(), msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit ReceivedFallback(msg.sender, msg.value);
    }
}