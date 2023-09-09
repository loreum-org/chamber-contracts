// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";

import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC1155Holder } from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC721Holder } from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract Chamber is IChamber, ReentrancyGuard, Context, ERC721Holder, ERC1155Holder {

    uint8 constant public VERSION = 1;

    /**************************************************
        Chamber State Variables
     **************************************************/

    /// @notice memberToken The ERC721 contract used for membership.
    address public immutable memberToken;

    /// @notice govToken The ERC20 contract used for staking.
    address public immutable govToken;

    /// @notice The leaderboard
    uint8[5] public leaderboard;

    /**
     * @notice Tracks the amount of "govToken" staked for a given NFT ID.
     * @dev    1st element -> NFT tokenID, 2nd element -> amountStaked.
     */
    mapping(uint8 => uint256) public totalStake;

    /** 
     * @notice Tracks a given address's stake amount of "govToken" for a given NFT ID.
     * @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountStaked.
     */
    mapping(address => mapping(uint8 => uint256)) public accountNftStake;
    
    /** 
     * @notice Mapping of the Proposals
     * @dev    1st element -> index, 2nd element -> Proposal struct
     */
    mapping(uint256 => Proposal) public proposals;

    /** @notice proposalCount The number of proposals.*/
    uint256 public proposalCount;

    /** 
     * @notice Tracks which tokenIds have voted on proposals
     * @dev    1st element -> proposalId, 2nd element -> tokenId, 3rd element-> voted boolean
     */
    mapping(uint256 => mapping(uint256 => bool)) public voted;
    
    /**************************************************
        Constructor
     **************************************************/

    /** 
     * @param _memberToken The NFT collection used for membership.
     * @param _govToken    The fungible token use for amplifying governance power.
     */ 
    constructor(address _memberToken, address _govToken) {
        memberToken = _memberToken;
        govToken = _govToken;
    }

    /**************************************************
        Functions
     **************************************************/

    /** 
     * @notice Returns amount a user has staked against a given tokenId.
     * @param _member   The address staking.
     * @param _tokenId  The NFT tokenId a member has staked against.
     */
    function getUserStake(address _member, uint8 _tokenId) external view returns (uint256) {
        return accountNftStake[_member][_tokenId];
    }

    function getLeaderboard() external view returns (uint8[5] memory, uint256[5] memory) {
        uint8[5] memory _leaderboard = leaderboard;
        uint256[5] memory _stakes;
        for (uint8 i = 0; i < 5; i++) {
            _stakes[i] = totalStake[_leaderboard[i]];
        }
        return (_leaderboard, _stakes);
    }

    /// @inheritdoc IChamber
    function createProposal(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {
        if(IERC721(memberToken).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            voters: leaderboard,
            approvals: 0,
            state: State.Initialized
        });
        emit ProposalCreated(proposalCount, _target, _value, _data, leaderboard);
    }

    /// @inheritdoc IChamber
    function approveProposal(uint256 _proposalId, uint8 _tokenId) external {
        if(_msgSender() != IERC721(memberToken).ownerOf(_tokenId)) revert invalidApproval("Sender isn't owner");
        if(proposals[_proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[_proposalId][_tokenId]) revert invalidApproval("TokenID aleready voted");
        
        uint8[5] memory voters = proposals[_proposalId].voters;
        bool onVoterList = false;

        for (uint i = 0; i < voters.length; i++) {
            if (_tokenId == voters[i]) onVoterList = true;
        }

        if (!onVoterList) revert invalidApproval("TokenId not on voter list");

        voted[_proposalId][_tokenId] = true;
        proposals[_proposalId].approvals += 1;
        emit ProposalApproved(_proposalId, _tokenId, proposals[_proposalId].approvals);
        if (proposals[_proposalId].approvals == 3) {
            _executeProposal(_proposalId);
        }
    }

    /** 
     * @notice _executeProposal function
     * @param  _proposalId The ID of the proposal to execute.
     */
    function _executeProposal(uint256 _proposalId) private {
        if(proposals[_proposalId].state != State.Initialized) revert invalidProposalState();
       
        Proposal memory proposal = proposals[_proposalId];
        proposals[_proposalId].state = State.Executed;
        
        for (uint256 i = 0; i < proposal.data.length; i++) {
            (bool success,) = proposal.target[i].call{value: proposal.value[i]}(proposal.data[i]);
            if(!success) revert executionFailed();
        }
        emit ProposalExecuted(_proposalId);
    }

    /// @inheritdoc IChamber
    function stake(uint256 _amt, uint8 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidStake();
        
        totalStake[_tokenId] += _amt;
        accountNftStake[_msgSender()][_tokenId] += _amt;
        _updateLeaderboard(_tokenId);
        
        SafeERC20.safeTransferFrom(IERC20(govToken), _msgSender(), address(this), _amt);
        emit Staked(_msgSender(), _amt, _tokenId);
    }

    /// @notice Updates the leaderboard
    function _updateLeaderboard (uint8 _tokenId) private {
        for (uint8 i = 0; i < 5; i++) {
            if (leaderboard[i] == _tokenId) break;
            if (totalStake[_tokenId] > totalStake[leaderboard[i]]) {
                uint8 temp = leaderboard[i];
                leaderboard[i] = _tokenId;
                for (uint8 j = i; j < 5; j++) {
                    if (j == 4) break;
                    uint8 temp2 = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                    temp = temp2;
                }
                break;
            }
        }
    }

    /// @inheritdoc IChamber
    function unstake(uint256 _amt, uint8 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidUnStake();
        if(accountNftStake[_msgSender()][_tokenId] < _amt) revert invalidUnStake();
        
        totalStake[_tokenId] -= _amt;
        accountNftStake[_msgSender()][_tokenId] -= _amt;
        _updateLeaderboard(_tokenId);
        
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), _amt);
        emit Unstaked(_msgSender(), _amt, _tokenId);
    }

    fallback() external payable { 
        if (msg.value > 0) emit ReceivedEther(_msgSender(), msg.value);
    }

    receive() external payable {}
}