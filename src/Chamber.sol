// SPDX-License-Identifier: MIT
// Loreum Chamber v0.0.1

pragma solidity ^0.8.19;

interface IERC721_Chamber {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC20_Chamber {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);    
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Chamber {

    // ---------------------
    //    State Variables
    // ---------------------
    
    /// Chamber State Variables /// 
    
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

    /// @dev membershipToken The ERC721 contract used for membership.
    address public immutable membershipToken;

    /// @dev stakingToken The ERC20 contract used for staking.
    address public immutable stakingToken;

    /// @dev quorum The number of approvals required.
    uint16 public quorum;

    /// @dev leaders The number of authorized signers on the leaderboard.
    uint16 public leaders;

    /// @notice Tracks the amount of "stakingToken" staked for a given NFT ID.
    /// @dev    1st element -> NFT tokenID, 2nd element -> amountStaked.
    mapping(uint256 => uint256) public totalStake;

    /// @notice Tracks a given address's stake amount of "stakingToken" for a given NFT ID.
    /// @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountStaked.
    mapping(address => mapping(uint256 => uint256)) public memberNftStake;

    mapping(uint256 => Proposal) public proposals;

    /// @dev voted[proposalId][nftId]
    mapping(uint256 => mapping(uint256 => bool)) public voted;
    
    /// LinkedList State Variables ///
    
    uint internal constant _NULL = 0;
    bool internal constant _PREV = false;
    bool internal constant _NEXT = true;

    uint public head;
    uint public size;

    // list[tokenId][direction] = tokenId
    mapping(uint => mapping(bool => uint)) public list;

    struct Stake {
        uint stake;
    }

    mapping(uint => Stake) public tokenIdData;


    // -----------------
    //    Constructor
    // -----------------

    /// @param _membershipToken The NFT collection used for membership.
    /// @param _stakingToken The fungible token use for amplifying governance power.
    /// @param _quorum The number of votes required for a proposal to be executed.
    /// @param _leaders The number of leaders at the top of the leaderboard.
    constructor(address _membershipToken, address _stakingToken, uint16 _quorum, uint16 _leaders) {
        membershipToken = _membershipToken;
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
    /// @param _member     The address staking.
    /// @param _tokenId  The NFT tokenId a member has staked against.
    function getUserStakeIndividualNFT(address _member, uint256 _tokenId) external view returns (uint256) {
        return memberNftStake[_member][_tokenId];
    }

    function viewRankings() public view returns(uint[] memory _rankings, uint[] memory _stakes) {
        uint index = head;
        _rankings = new uint256[](leaders);
        _stakes = new uint256[](leaders);
        for (uint i = 0; i < leaders; i++) {
            _rankings[i] = index;
            _stakes[i] = totalStake[index];
            index = list[index][_PREV];
            if (index == 0) { return (_rankings, _stakes); }
        }
    }
    
    event Log(uint,uint,uint,uint);

    function viewRankingsAll() public view returns(uint[] memory _rankings, uint[] memory _stakes) {
        if (size == 0) { return (_rankings, _stakes); }
        (uint tokenId, uint rank) = (head, 0);
        _rankings = new uint256[](size);
        _stakes = new uint256[](size);
        while (true) {
            _rankings[rank] = tokenId;
            _stakes[rank] = totalStake[tokenId];
            // emit Log(tokenId, totalStake[tokenId], list[tokenId][_PREV], list[tokenId][_NEXT]);
            tokenId = list[tokenId][_PREV];
            if (tokenId == 0) { return (_rankings, _stakes); }
            rank++;
        }
    }

    function helperView() public {
        for (uint tokenId = 0; tokenId <= 10; tokenId++) {
            emit Log(tokenId, totalStake[tokenId], list[tokenId][_PREV], list[tokenId][_NEXT]);
        }
    }

    /// @notice approve Proposal function
    /// @param  _proposalId The ID of the proposal to approve.
    /// @param  _tokenId The ID of the NFT to vote.
    function approve(uint256 _proposalId, uint256 _tokenId) external {

        require(_msgSender() == IERC721_Chamber(membershipToken).ownerOf(_tokenId), "Caller does not own NFT.");
        require(proposals[_proposalId].state == State.Initialized, "Proposal is not initialized.");
        require(!voted[_proposalId][_tokenId], "NFT has already voted.");

        bool detected;

        for (uint i = 0; i < proposals[_proposalId].voters.length; i++) {
            if (_tokenId == proposals[_proposalId].voters[i]) { detected = true; break; }
        }

        require(detected, "NFT not eligible to vote.");

        voted[_proposalId][_tokenId] = true;
        proposals[_proposalId].approvals += 1;

        if (proposals[_proposalId].approvals >= quorum) {
            _executeProposal(_proposalId);
        }
        
        emit ProposalApproved(_proposalId, _tokenId, proposals[_proposalId].approvals);
    }

    /// @notice create Proposal function
    /// @param  _target The address of contract to send transaction
    /// @param  _value The uint256 amount of ETH to send with transaction
    /// @param  _data The bytes[] of transaction data
    function create(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {

        require(IERC721_Chamber(membershipToken).balanceOf(_msgSender()) >= 1, "NFT balance is 0.");

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
    /// @param _amt      The amount of "stakingToken" to stake.
    /// @param _tokenId  The ID of the NFT to stake against.
    function stake(uint256 _amt, uint256 _tokenId) public {

        require(_amt != 0 && _tokenId != 0);
        
        totalStake[_tokenId] += _amt;
        memberNftStake[_msgSender()][_tokenId] += _amt;
        IERC20_Chamber(stakingToken).transferFrom(_msgSender(), address(this), _amt);

        emit Staked(_msgSender(), _amt, _tokenId);

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

    /// @notice Unstakes a given amount of "stakingToken" from the provided NFT ID.
    /// @param _amt      The amount of "stakingToken" to unstake.
    /// @param _tokenId  The ID of the NFT to unstake from.
    function unstake(uint256 _amt, uint256 _tokenId) public {
        require(_amt != 0 && _tokenId != 0);
        
        require(
            memberNftStake[_msgSender()][_tokenId] >= _amt,
            "Chamber::unstake() memberNftStake[_msgSender()][tokenId] < amt"
        );
        
        totalStake[_tokenId] -= _amt;
        memberNftStake[_msgSender()][_tokenId] -= _amt;
        IERC20_Chamber(stakingToken).transfer(_msgSender(), _amt);

        emit Unstaked(_msgSender(), _amt, _tokenId);

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

    /// @notice Migrates a staked amount of "stakingToken" from one NFT ID to another.
    /// @param _amt          The amount of "stakingToken" to migrate.
    /// @param _fromTokenId  The ID of the NFT that tokens are staked currently.
    /// @param _toTokenId    The ID of the NFT that tokens will be migrated to.
    function migrate(uint256 _amt, uint256 _fromTokenId, uint256 _toTokenId) external {
        unstake(_amt, _fromTokenId);
        stake(_amt, _toTokenId);
    }
    
    
    /// LikedList Utility Functions ///
    
    // Checkers.

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
    
    // Getters.

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
    
    // Insert.

    function insertAfter(uint _byTokenId, uint _newTokenId) internal {
        _insert(_byTokenId, _newTokenId, _NEXT);
    }

    function insertBefore(uint _byTokenId, uint _newTokenId) internal {
        _insert(_byTokenId, _newTokenId, _PREV);
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
    
    // Remove.

    function remove(uint _tokenId) internal {
        if ((_tokenId == _NULL) || (!inList(_tokenId)) && size != 1) {
            revert();
        }
        _createLink(list[_tokenId][_PREV], list[_tokenId][_NEXT], _NEXT);
        delete list[_tokenId][_PREV];
        delete list[_tokenId][_NEXT];

        size -= 1;
    }

    // Push and pop.

    function pushFront(uint _tokenId) internal {
        _push(_tokenId, _NEXT);
    }

    function pushBack(uint _tokenId) internal {
        _push(_tokenId, _PREV);
    }

    function popFront() internal {
        _pop(_NEXT);
    }

    function popBack() internal {
        _pop(_PREV);
    }

    function _push(uint _tokenId, bool _direction) private {
        _insert(head, _tokenId, _direction);
    }

    function _pop(bool _direction) private {
        (, uint adj) = getAdjacent(head, _direction);
        remove(adj);
    }
    
    /// OZ Utilities ///
    
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