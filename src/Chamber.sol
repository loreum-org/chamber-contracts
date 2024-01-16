// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import "./Common.sol";

contract Chamber is IChamber, Common {

    /// @notice memberToken The ERC721 contract used for membership.
    address public memberToken;

    /// @notice govToken The ERC20 contract used for staking.
    address public govToken;

    /// @notice leaderboard ff members based on total delegation.
    /// @dev    Limited to maximum 5 leaders requiring 3 approvals
    uint8[] public leaderboard;

    /// @notice proposalCount The number of proposals.
    uint8 public proposalCount;

    /// @notice totalDelegation Tracks the amount of govToken delegated to a given NFT ID.
    /// @dev    1st element -> NFT tokenID, 2nd element -> amountDelegated.
    mapping(uint8 => uint256) public totalDelegation;

    /// @notice accountDelegation Tracks a given address's delegatation balance of govToken for a given NFT ID.
    /// @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountDelegated.
    mapping(address => mapping(uint8 => uint256)) public accountDelegation;
    
    /// @notice proposals Mapping of the Proposals.
    /// @dev    1st element -> index, 2nd element -> Proposal struct
    mapping(uint8 => Proposal) public proposals;

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
        proposals[proposalCount] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            voters: topFiveLeader,
            approvals: 0,
            state: State.Initialized
        });
        emit ProposalCreated(proposalCount, _target, _value, _data, topFiveLeader);
    }

    /// @inheritdoc IChamber
    function approveProposal(uint8 _proposalId, uint8 _tokenId) external {
        if(_msgSender() != IERC721(memberToken).ownerOf(_tokenId)) revert invalidApproval("Sender isn't NFT owner");
        if(proposals[_proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[_proposalId][_tokenId]) revert invalidApproval("TokenID already voted");
        
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
            _executeProposal(_proposalId);
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
    function _executeProposal(uint8 _proposalId) private {

        // TODO Implement Gas handling and Optimizations
        // TODO Implement before and after guards

        if(proposals[_proposalId].state != State.Initialized) revert invalidProposalState();
       
        Proposal memory proposal = proposals[_proposalId];
        proposals[_proposalId].state = State.Executed;
        
        for (uint256 i = 0; i < proposal.data.length; i++) {
            (bool success,) = proposal.target[i].call{value: proposal.value[i]}(proposal.data[i]);
            if(!success) revert executionFailed();
        }
        emit ProposalExecuted(_proposalId);
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

    fallback() external payable {
        if (msg.value > 0) emit ReceivedEther(_msgSender(), msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit ReceivedFallback(msg.sender, msg.value);
    }
}