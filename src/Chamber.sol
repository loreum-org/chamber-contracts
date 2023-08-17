// SPDX-License-Identifier: MIT
// Loreum Chamber v0.0.1

pragma solidity 0.8.19;

import { IChamber } from "./IChamber.sol";

import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

interface IERC721_Chamber {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Chamber is IChamber {

    /**************************************************
        Chamber State Variables
     **************************************************/

    /** @notice proposalCount The number of proposals.*/
    uint256 public proposalCount;

    /** @notice memberToken The ERC721 contract used for membership.*/
    address public immutable memberToken;

    /** @notice govToken The ERC20 contract used for staking.*/
    address public immutable govToken;

    /** @notice quorum The number of approvals required.*/
    uint8 public quorum;

    /** @notice leaders The number of authorized signers on the leaderboard.*/
    uint8 public leaders;

    /**
     * @notice Tracks the amount of "govToken" staked for a given NFT ID.
     * @dev    1st element -> NFT tokenID, 2nd element -> amountStaked.
     */
    mapping(uint256 => uint256) public totalStake;

    /** 
     * @notice Tracks a given address's stake amount of "govToken" for a given NFT ID.
     * @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountStaked.
     */
    mapping(address => mapping(uint256 => uint256)) public accountNftStake;
    
    /** 
     * @notice Mapping of the Proposals
     * @dev    1st element -> index, 2nd element -> Proposal struct
     */
    mapping(uint256 => Proposal) public proposals;

    /** 
     * @notice Tracks which tokenIds have voted on proposals
     * @dev    1st element -> proposalId, 2nd element -> tokenId, 3rd element-> voted boolean
     */
    mapping(uint256 => mapping(uint256 => bool)) public voted;
    
    /**************************************************
        LinkedList State Variables
     **************************************************/

    /** @notice Head is the first tokenId of the Leaderboard */
    uint public head;
    
    /** @notice Size is the total number of tokenIds on the leaderboard */
    uint public size;

    /** 
     * @notice The Leaderboard is a linked list of NFT tokenIds
     * @dev    1st element -> tokenId, 2nd element -> direction, 3rd element-> tokenId
     * @dev    direction: False -> previous, True -> next
     */
    mapping(uint => mapping(bool => uint)) public list;
    
    // LinkedList constants
    uint internal constant _NULL = 0;
    bool internal constant _PREV = false;
    bool internal constant _NEXT = true;
    
    /**************************************************
        Constructor
     **************************************************/

    /** 
     * @param _memberToken The NFT collection used for membership.
     * @param _govToken    The fungible token use for amplifying governance power.
     * @param _quorum          The number of votes required for a proposal to be executed.
     * @param _leaders         The number of leaders at the top of the leaderboard.
     */ 
    constructor(address _memberToken, address _govToken, uint8 _quorum, uint8 _leaders) {
        memberToken = _memberToken;
        govToken = _govToken;
        quorum = _quorum;
        leaders = _leaders;
    }

    /**************************************************
        Functions
     **************************************************/

    /** 
     * @notice Returns amount a user has staked against a given NFT ID ("tokenID").
     * @param _member   The address staking.
     * @param _tokenId  The NFT tokenId a member has staked against.
     */
    function getUserStakeIndividualNFT(address _member, uint256 _tokenId) external view returns (uint256) {
        return accountNftStake[_member][_tokenId];
    }

    function viewRankings() public view returns(uint[] memory _rankings, uint[] memory _stakes) {
        uint index = head;
        _rankings = new uint256[](leaders);
        _stakes = new uint256[](leaders);
        uint leadersNumber = leaders;
        for (uint i = 0; i < leadersNumber; i++) {
            _rankings[i] = index;
            _stakes[i] = totalStake[index];
            index = list[index][_PREV];
            if (index == 0) { return (_rankings, _stakes); }
        }
    }

    /**
     * @notice Returns the rankings and the stakes of all the tokens in the contract.
     * @dev Iterates through the linked list starting from the head and retrieves the stake of each token.
     * @return _rankings An array containing the token IDs, ranked by their stakes.
     * @return _stakes An array containing the staked amounts, corresponding to the token IDs in the _rankings array.
     */
    function viewRankingsAll() public view returns(uint[] memory _rankings, uint[] memory _stakes) {
        if (size == 0) { return (_rankings, _stakes); }
        (uint tokenId, uint rank) = (head, 0);
        _rankings = new uint256[](size);
        _stakes = new uint256[](size);
        while (true) {
            _rankings[rank] = tokenId;
            _stakes[rank] = totalStake[tokenId];
            tokenId = list[tokenId][_PREV];
            if (tokenId == 0) { return (_rankings, _stakes); }
            rank++;
        }
    }

    /// @inheritdoc IChamber
    function approveTx(uint256 _proposalId, uint256 _tokenId) external {

        if(_msgSender() != IERC721_Chamber(memberToken).ownerOf(_tokenId)) revert invalidApproval("Sender isn't owner");
        if(proposals[_proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[_proposalId][_tokenId]) revert invalidApproval("TokenID aleready voted");

        bool onVoterList = false;
        uint proposalsVotersLength = proposals[_proposalId].voters.length;
        for (uint i = 0; i < proposalsVotersLength; i++) {
            if (_tokenId == proposals[_proposalId].voters[i]) onVoterList = true;
        }

        if (!onVoterList) revert invalidApproval("TokenId not on voter list");

        voted[_proposalId][_tokenId] = true;
        proposals[_proposalId].approvals += 1;

        if (proposals[_proposalId].approvals >= quorum) {
            _executeProposal(_proposalId);
        }
        
        emit ProposalApproved(_proposalId, _tokenId, proposals[_proposalId].approvals);
    }

    /// @inheritdoc IChamber
    function createTx(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {

        if(IERC721_Chamber(memberToken).balanceOf(_msgSender()) < 1) revert insufficientBalance();

        proposalCount++;

        (uint256[] memory _voters, ) = viewRankings();

        proposals[proposalCount] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            voters: _voters,
            approvals: 0,
            state: State.Initialized
        });

        emit ProposalCreated(proposalCount, _target, _value, _data, _voters);
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
            (bool success, ) = proposal.target[i].call{value: proposal.value[i]}(proposal.data[i]);
            if(!success) revert executionFailed();
        }

        emit ProposalExecuted(_proposalId);
    }

    /// @inheritdoc IChamber
    function stake(uint256 _amt, uint256 _tokenId) public {

        if(_amt == 0 && _tokenId == 0) revert invalidStake();
        
        totalStake[_tokenId] += _amt;
        accountNftStake[_msgSender()][_tokenId] += _amt;
        _stakeUpdater(_tokenId);
        SafeERC20.safeTransferFrom(IERC20(govToken), _msgSender(), address(this), _amt);
        emit Staked(_msgSender(), _amt, _tokenId);
    }

    /** 
     * @notice _stakeUpdatList function updates state for the stake function
     * @param  _tokenId The nft ID that is being updated
     */
    function _stakeUpdater (uint256 _tokenId) private {
        if (_tokenId == head) { return; }

        // NFT Stake > 0
        if (inList(_tokenId)) {
            // Get adjacent node data.
            (, uint prev, uint next) = getData(_tokenId);

            // Position unchanged, do nothing.
            if (totalStake[next] >= totalStake[_tokenId] && totalStake[prev] <= totalStake[_tokenId]) {
                return;
            }

            // Position changed, do something.
            else {
                // Remove token from list.
                remove(_tokenId);

                // Add to front.
                if (totalStake[_tokenId] >= totalStake[head]) {
                    pushFront(_tokenId);
                    head = _tokenId;
                }

                // Add to middle (or end).
                else {
                    uint i = 0;
                    (, prev) = getPrev(head);
                    while (prev != 0) {
                        // Insert after if eligble.
                        if (totalStake[_tokenId] >= totalStake[prev]) {
                            insertAfter(prev, _tokenId);
                            return;
                        }
                        // Cycle through.
                        (, prev) = getPrev(prev);
                        i++;
                    }
                    if (i < leaders) {
                        insertAfter(prev, _tokenId);
                    }
                }

            }
        }
        // NFT Stake == 0
        else {
            // Push to head.
            if (totalStake[_tokenId] >= totalStake[head]) {
                pushFront(_tokenId);
                head = _tokenId;
            }
            else {
                uint i = 0;
                // uint prev = list[tokenId][_PREV];
                (, uint prev) = getPrev(head);
                // prev != 0 means there is a link "PREV" to a node.
                while (prev != 0) {
                    // Insert after if available.
                    if (totalStake[_tokenId] >= totalStake[prev]) {
                        insertAfter(prev, _tokenId);
                        return;
                    }
                    // Cycle through.
                    (, prev) = getPrev(prev);
                    i++;
                }
                if (i < leaders) {
                    insertAfter(prev, _tokenId);
                }
            }
        }

        // Final check, if size >= leaders ... pop last element.
        // if (size > leaders) { emit Checkpoint(13); popBack(); }
    }

    /// @inheritdoc IChamber
    function unstake(uint256 _amt, uint256 _tokenId) public {
        if(_amt == 0 && _tokenId == 0) revert invalidUnStake();
        
        if(accountNftStake[_msgSender()][_tokenId] < _amt) revert invalidUnStake();
        
        totalStake[_tokenId] -= _amt;
        accountNftStake[_msgSender()][_tokenId] -= _amt;
        _unstakeUpdater(_tokenId);
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), _amt);

        emit Unstaked(_msgSender(), _amt, _tokenId);
    }

    /** 
     * @notice _unstakeUpdater function updates state for the unstake function
     * @param  _tokenId The nft ID that is being updated
     */
    function _unstakeUpdater (uint256 _tokenId) private {
        // Remove token from list.
        if (_tokenId == head && size != 0) {
            (, uint prev) = getPrev(head);
            if (totalStake[_tokenId] >= totalStake[prev]) {
                return;
            }
            (, head) = getPrev(head);
            remove(_tokenId);
        }
        else {
            remove(_tokenId);
        }

        if (totalStake[_tokenId] == 0) { return; }
        if (size == 0) { pushFront(_tokenId); head = _tokenId; return; }

        uint i = 0;
        (, uint _prev) = getPrev(head);
        while (_prev != 0) {
            // Insert after if eligble.
            if (totalStake[_tokenId] >= totalStake[_prev]) {
                insertAfter(_prev, _tokenId);
                return;
            }
            // Cycle through.
            (, _prev) = getPrev(_prev);
            i++;
        }
        if (i < leaders) {
            insertAfter(_prev, _tokenId);
        }
    }

    /// @inheritdoc IChamber
    function migrate(uint256 _amt, uint256 _fromTokenId, uint256 _toTokenId) external {
        unstake(_amt, _fromTokenId);
        stake(_amt, _toTokenId);
    }
    
    /**************************************************
        Linked List Functions
     **************************************************/
    
    function isInitialized() public view returns (bool initialized) {
        return list[head][_PREV] != _NULL || list[head][_NEXT] != _NULL;
    }

    function inList(uint _tokenId) public view returns (bool exists) {
        if (list[_tokenId][_PREV] == _NULL && list[_tokenId][_NEXT] == _NULL) {
            return head == _tokenId;
            // return list[head][_NEXT] == _tokenId;
        }
        else { return true; }
    }
    
    function getData(uint _tokenId) public view returns (bool exists, uint prev, uint next) {
        return (inList(_tokenId), list[_tokenId][_PREV], list[_tokenId][_PREV]);
    }

    function getPrev(uint _tokenId) public view returns (bool exists, uint prev) {
        return (inList(_tokenId), list[_tokenId][_PREV]);
    }

    function getNext(uint _tokenId) public view returns (bool exists, uint next) {
        return (inList(_tokenId), list[_tokenId][_NEXT]);
    }

    function getAdjacent(uint _tokenId, bool direction) public view returns (bool, uint) {
        return inList(_tokenId) ? (false, 0) : (true, list[_tokenId][direction]);
    }

    function getNextNode(uint _tokenId) public view returns (bool, uint) {
        return getAdjacent(_tokenId, _NEXT);
    }

    function getPreviousNode(uint _tokenId) public view returns (bool, uint) {
        return getAdjacent(_tokenId, _PREV);
    }
    
    function insertAfter(uint _byTokenId, uint _newTokenId) internal {
        _insert(_byTokenId, _newTokenId, _NEXT);
    }

    function _insert(uint _byTokenId, uint _newTokenId, bool _direction) private {
        if (!inList(_newTokenId) && inList(_byTokenId)) {
            uint id = list[_byTokenId][_direction];
            _createLink(_byTokenId, _newTokenId, _direction);
            _createLink(_newTokenId, id, _direction);
            size += 1;
            return;
        }
        revert();
    }

    function _createLink(uint _tokenId, uint _linkTokenId, bool _direction) private {
        list[_linkTokenId][!_direction] = _tokenId;
        list[_tokenId][_direction] = _linkTokenId;
    }
    
    function remove(uint _tokenId) internal {
        if ((_tokenId == _NULL) || (!inList(_tokenId)) && size != 1) {
            revert();
        }
        _createLink(list[_tokenId][_PREV], list[_tokenId][_NEXT], _NEXT);
        delete list[_tokenId][_PREV];
        delete list[_tokenId][_NEXT];

        size -= 1;
    }

    function pushFront(uint _tokenId) internal {
        _push(_tokenId, _NEXT);
    }

    function _push(uint _tokenId, bool _direction) private {
        _insert(head, _tokenId, _direction);
    }
    
    /**************************************************
        OZ Utilities
     **************************************************/
    
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    fallback() external payable { emit ReceivedEther(_msgSender(), msg.value); }

    receive() external payable {}

}