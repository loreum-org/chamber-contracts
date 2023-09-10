// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";

import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC1155Holder } from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { 
    ERC1967UpgradeUpgradeable 
} from "openzeppelin-contracts-upgradeable/contracts/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol";

contract Chamber is IChamber, 
    ERC1967UpgradeUpgradeable, 
    ReentrancyGuard, 
    Context, 
    ERC721Holder, 
    ERC1155Holder {

    string public version;

    /**************************************************
        Chamber State Variables
     **************************************************/

    /// @notice memberToken The ERC721 contract used for membership.
    address public memberToken;

    /// @notice govToken The ERC20 contract used for staking.
    address public govToken;

    /// @notice The leaderboard
    uint8[5] public leaderboard;

    /**
     * @notice Tracks the amount of "govToken" delegated to a given NFT ID.
     * @dev    1st element -> NFT tokenID, 2nd element -> amountDelegated.
     */
    mapping(uint8 => uint256) public totalDelegation;

    /** 
     * @notice Tracks a given address's delegatation balance of govToken for a given NFT ID.
     * @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountDelegated.
     */
    mapping(address => mapping(uint8 => uint256)) public accountDelegation;
    
    /** 
     * @notice Mapping of the Proposals
     * @dev    1st element -> index, 2nd element -> Proposal struct
     */
    mapping(uint8 => Proposal) public proposals;

    /** @notice proposalCount The number of proposals.*/
    uint8 public proposalCount;

    /** 
     * @notice Tracks which tokenIds have voted on proposals
     * @dev    1st element -> proposalId, 2nd element -> tokenId, 3rd element-> voted boolean
     */
    mapping(uint8 => mapping(uint8 => bool)) public voted;
    
    /**************************************************
        Constructor
     **************************************************/

    constructor() {
        _disableInitializers();
    }

    /**************************************************
        Functions
     **************************************************/
    
    /**
     * @notice Initializes a new version of Chamber
     * @param _memberToken  The address of the ERC721 contract used for membership.
     * @param _govToken     The address of the ERC20 contract used for delegation.
     */
    function initialize(address _memberToken, address _govToken) external initializer {
        version = "0.1.0-alpha";
        memberToken = _memberToken;
        govToken = _govToken;
    }
    
    /// @inheritdoc IChamber
    function getLeaderboard() external view returns (uint8[5] memory, uint256[5] memory) {
        uint8[5] memory _leaderboard = leaderboard;
        uint256[5] memory _delegations;
        for (uint8 i = 0; i < 5; i++) {
            _delegations[i] = totalDelegation[_leaderboard[i]];
        }
        return (_leaderboard, _delegations);
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
    function approveProposal(uint8 _proposalId, uint8 _tokenId) external {
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
    function _executeProposal(uint8 _proposalId) private {
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
        _updateLeaderboard(_tokenId);
        
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), _amt);
        emit Demoted(_msgSender(), _amt, _tokenId);
    }

    /// @notice Updates the leaderboard
    function _updateLeaderboard (uint8 _tokenId) private {
        for (uint8 i = 0; i < 5; i++) {
            if (leaderboard[i] == _tokenId) break;
            if (totalDelegation[_tokenId] > totalDelegation[leaderboard[i]]) {
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

    fallback() external payable { 
        if (msg.value > 0) emit ReceivedEther(_msgSender(), msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit ReceivedFallback(msg.sender, msg.value);
    }
}