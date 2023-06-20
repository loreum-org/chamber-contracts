// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkedList} from "src/LinkedList.sol";

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/utils/Context.sol";

interface IERC721_Chamber {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Chamber is Context, LinkedList, ERC721Holder, ERC1155Holder {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    enum State { Null, Initialized, Executed }

    struct Proposal {
        address[] target;
        uint256[] value;
        bytes[] data;
        uint256[] voters;
        uint256 approvals;
        State state;
    }

    uint256 public proposalCount;

    /// @dev NFT The ERC721/1155 contract used for governance.
    address public immutable NFT;

    /// @dev stakingToken The ERC20 contract used for staking.
    address public immutable stakingToken;

    /// @dev quorum The number of voting captains.
    uint16 public quorum;

    /// @dev leaders The number of leaders that can vote, based on leaderboard position.
    uint16 public leaders;

    /// @notice Tracks the amount of "stakingToken" staked for a given NFT ID.
    /// @dev    1st element -> NFT tokenID, 2nd element -> amountStaked.
    mapping(uint256 => uint256) public totalStake;

    /// @notice Tracks a given address's stake amount of "stakingToken" for a given NFT ID.
    /// @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountStaked.
    mapping(address => mapping(uint256 => uint256)) public userStakeIndividualNFT;

    mapping(uint256 => Proposal) public proposals;

    /// @dev voted[proposalId][nftId]
    mapping(uint256 => mapping(uint256 => bool)) public voted;


    // -----------------
    //    Constructor
    // -----------------

    /// @param _NFT The NFT collection that will gain governance power.
    /// @param _stakingToken The token staked in this contract, amplifying governance power.
    /// @param _quorum The number of votes required for a proposal to be executed.
    /// @param _leaders The number of leaders at the top of the leaderboard.
    constructor(address _NFT, address _stakingToken, uint16 _quorum, uint16 _leaders) {
        NFT = _NFT;
        stakingToken = _stakingToken;
        quorum = _quorum;
        leaders = _leaders;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted upon stake().
    /// @param staker   The address staking.
    /// @param amt      The amount of "stakingToken" staked.
    /// @param tokenId  The ID of the NFT that tokens will be staked against.
    event Staked(address staker, uint256 amt, uint256 tokenId);

    /// @notice Emitted upon unstake().
    /// @param staker   The address unstaking.
    /// @param amt      The amount of "stakingToken" unstaked.
    /// @param tokenId  The ID of the NFT that tokens were staked against.
    event Unstaked(address staker, uint256 amt, uint256 tokenId);

    event ProposalApproved(uint256 proposalId, uint256 nftId, uint256 approvals);

    event ProposalCreated(uint256 proposalId, address[] target, uint256[] value, bytes[] data, uint256[] voters);

    event ProposalExecuted(uint256 proposalId);

    event ReceivedEther(address indexed sender, uint256 value);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Returns amount a user has staked against a given NFT ID ("tokenID").
    /// @param user     The address staking.
    /// @param tokenId  The ID of the NFT "user" has staked against.
    function getUserStakeIndividualNFT(address user, uint256 tokenId) external view returns (uint256) {
        return userStakeIndividualNFT[user][tokenId];
    }

    function viewRankings() public view returns(uint[] memory rankings, uint[] memory stakes) {
        uint index = head;
        rankings = new uint256[](leaders);
        stakes = new uint256[](leaders);
        for (uint i = 0; i < leaders; i++) {
            rankings[i] = index;
            stakes[i] = totalStake[index];
            index = list[index][_PREV];
            if (index == 0) { return (rankings, stakes); }
        }
    }
    
    event Log(uint,uint,uint,uint);

    function viewRankingsAll() public returns(uint[] memory rankings, uint[] memory stakes) {
        if (size == 0) { return (rankings, stakes); }
        (uint tokenId, uint rank) = (head, 0);
        rankings = new uint256[](size);
        stakes = new uint256[](size);
        while (true) {
            rankings[rank] = tokenId;
            stakes[rank] = totalStake[tokenId];
            emit Log(tokenId, totalStake[tokenId], list[tokenId][_PREV], list[tokenId][_NEXT]);
            tokenId = list[tokenId][_PREV];
            if (tokenId == 0) { return (rankings, stakes); }
            rank++;
        }
    }

    function helperView() public {
        for (uint tokenId = 0; tokenId <= 10; tokenId++) {
            emit Log(tokenId, totalStake[tokenId], list[tokenId][_PREV], list[tokenId][_NEXT]);
        }
    }

    /// @notice approveProposal function
    /// @param  proposalId The ID of the proposal to approve.
    /// @param  nftId The ID of the NFT to vote.
    function approveProposal(uint256 proposalId, uint256 nftId) external {

        require(_msgSender() == IERC721_Chamber(NFT).ownerOf(nftId), "Caller does not own NFT.");
        require(proposals[proposalId].state == State.Initialized, "Proposal is not initialized.");
        require(!voted[proposalId][nftId], "NFT has already voted.");

        bool detected;

        for (uint i = 0; i < proposals[proposalId].voters.length; i++) {
            if (nftId == proposals[proposalId].voters[i]) { detected = true; break; }
        }

        require(detected, "NFT not eligible to vote.");

        voted[proposalId][nftId] = true;
        proposals[proposalId].approvals += 1;

        emit ProposalApproved(proposalId, nftId, proposals[proposalId].approvals);

        if (proposals[proposalId].approvals >= quorum) {
            _executeProposal(proposalId);
        }

    }

    /// @notice createProposal function
    /// @param  _target The address of contract to send transaction
    /// @param  _value The uint256 amount of ETH to send with transaction
    /// @param  _data The bytes[] of transaction data
    function createProposal(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {

        require(IERC721_Chamber(NFT).balanceOf(_msgSender()) >= 1, "NFT balance is 0.");

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

    /// @notice _executeProposal function
    /// @param  _proposalId The ID of the proposal to execute.
    function _executeProposal(uint256 _proposalId) private {

        require(proposals[_proposalId].state == State.Initialized, "Proposal is not initialized.");

        Proposal memory proposal = proposals[_proposalId];

        proposals[_proposalId].state = State.Executed;

        for (uint256 i = 0; i < proposal.data.length; i++) {
            (bool success, ) = proposal.target[i].call{value: proposal.value[i]}(proposal.data[i]);
            require(success, "Failed to execute proposal data");
        }

        emit ProposalExecuted(_proposalId);
    }

    /// @notice Stakes a given amount of "stakingToken" against the provided NFT ID.
    /// @param amt      The amount of "stakingToken" to stake.
    /// @param tokenId  The ID of the NFT to stake against.
    function stake(uint256 amt, uint256 tokenId) public {

        require(amt != 0 && tokenId != 0);
        
        emit Staked(_msgSender(), amt, tokenId);

        IERC20(stakingToken).safeTransferFrom(_msgSender(), address(this), amt);
        userStakeIndividualNFT[_msgSender()][tokenId] += amt;
        totalStake[tokenId] += amt;

        if (tokenId == head) { return; }

        // NFT Stake > 0
        if (inList(tokenId)) {
            // Get adjacent node data.
            (, uint prev, uint next) = getData(tokenId);

            // Position unchanged, do nothing.
            if (totalStake[next] >= totalStake[tokenId] && totalStake[prev] <= totalStake[tokenId]) {
                return;
            }

            // Position changed, do something.
            else {
                // Remove token from list.
                remove(tokenId);

                // Add to front.
                if (totalStake[tokenId] >= totalStake[head]) {
                    pushFront(tokenId);
                    head = tokenId;
                }

                // Add to middle (or end).
                else {
                    uint i = 0;
                    (, prev) = getPrev(head);
                    while (prev != 0) {
                        // Insert after if eligble.
                        if (totalStake[tokenId] >= totalStake[prev]) {
                            insertAfter(prev, tokenId);
                            return;
                        }
                        // Cycle through.
                        (, prev) = getPrev(prev);
                        i++;
                    }
                    if (i < leaders) {
                        insertAfter(prev, tokenId);
                    }
                }

            }
        }
        // NFT Stake == 0
        else {
            // Push to head.
            if (totalStake[tokenId] >= totalStake[head]) {
                pushFront(tokenId);
                head = tokenId;
            }
            else {
                uint i = 0;
                // uint prev = list[tokenId][_PREV];
                (, uint prev) = getPrev(head);
                // prev != 0 means there is a link "PREV" to a node.
                while (prev != 0) {
                    // Insert after if available.
                    if (totalStake[tokenId] >= totalStake[prev]) {
                        insertAfter(prev, tokenId);
                        return;
                    }
                    // Cycle through.
                    (, prev) = getPrev(prev);
                    i++;
                }
                if (i < leaders) {
                    insertAfter(prev, tokenId);
                }
            }
        }

        // Final check, if size >= leaders ... pop last element.
        // if (size > leaders) { emit Checkpoint(13); popBack(); }
        
    }

    /// @notice Unstakes a given amount of "stakingToken" from the provided NFT ID.
    /// @param amt      The amount of "stakingToken" to unstake.
    /// @param tokenId  The ID of the NFT to unstake from.
    function unstake(uint256 amt, uint256 tokenId) public {
        require(amt != 0 && tokenId != 0);
        
        require(
            userStakeIndividualNFT[_msgSender()][tokenId] >= amt,
            "Chamber::unstake() userStakeIndividualNFT[_msgSender()][tokenId] < amt"
        );

        emit Unstaked(_msgSender(), amt, tokenId);

        IERC20(stakingToken).safeTransfer(_msgSender(), amt);
        userStakeIndividualNFT[_msgSender()][tokenId] -= amt;
        totalStake[tokenId] -= amt;

        // Remove token from list.
        if (tokenId == head && size != 0) {
            (, uint prev) = getPrev(head);
            if (totalStake[tokenId] >= totalStake[prev]) {
                return;
            }
            (, head) = getPrev(head);
            remove(tokenId);
        }
        else {
            remove(tokenId);
        }

        if (totalStake[tokenId] == 0) { return; }
        if (size == 0) { pushFront(tokenId); head = tokenId; return; }

        uint i = 0;
        (, uint _prev) = getPrev(head);
        while (_prev != 0) {
            // Insert after if eligble.
            if (totalStake[tokenId] >= totalStake[_prev]) {
                insertAfter(_prev, tokenId);
                return;
            }
            // Cycle through.
            (, _prev) = getPrev(_prev);
            i++;
        }
        if (i < leaders) {
            insertAfter(_prev, tokenId);
        }

    }

    /// @notice Migrates a staked amount of "stakingToken" from one NFT ID to another.
    /// @param amt          The amount of "stakingToken" to migrate.
    /// @param fromTokenId  The ID of the NFT that tokens are staked currently.
    /// @param toTokenId    The ID of the NFT that tokens will be migrated to.
    function migrate(uint256 amt, uint256 fromTokenId, uint256 toTokenId) external {
        unstake(amt, fromTokenId);
        stake(amt, toTokenId);
    }

    fallback() external payable { emit ReceivedEther(msg.sender, msg.value); }

    receive() external payable {}

}