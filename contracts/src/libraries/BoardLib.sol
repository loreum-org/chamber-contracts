// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IBoard} from "src/interfaces/IBoard.sol";
import {BoardTypes} from "src/types/BoardTypes.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

/**
 * @title BoardLib
 * @notice Linked external library for Board linked-list and seat governance logic.
 * @dev Extracted to keep `Chamber` implementation under the EIP-170 size limit.
 */
library BoardLib {
    using EnumerableSet for EnumerableSet.UintSet;
    using BoardTypes for BoardTypes.BoardStorage;

    function getNode(BoardTypes.BoardStorage storage $, uint256 tokenId) external view returns (BoardTypes.Node memory) {
        return $.nodes[tokenId];
    }

    function delegate(
        BoardTypes.BoardStorage storage $,
        uint256 tokenId,
        uint256 amount,
        address sender,
        IERC721 nft
    ) external {
        uint256[] memory prevTop = topTokenIds($);
        BoardTypes.Node storage node = $.nodes[tokenId];
        if (node.tokenId == tokenId) {
            node.amount += amount;
            reposition($, tokenId);
        } else {
            insert($, tokenId, amount);
        }
        refreshSeating($, prevTop);
        syncTopSeatControl($, nft);
        syncSeatingControl($, nft, tokenId);
        emit IBoard.Delegate(sender, tokenId, amount);
    }

    function undelegate(
        BoardTypes.BoardStorage storage $,
        uint256 tokenId,
        uint256 amount,
        address sender,
        IERC721 nft
    ) external {
        uint256[] memory prevTop = topTokenIds($);
        BoardTypes.Node storage node = $.nodes[tokenId];
        if (node.tokenId != tokenId) revert IBoard.NodeDoesNotExist();
        if (amount > node.amount) revert IBoard.AmountExceedsDelegation();

        node.amount -= amount;

        if (node.amount == 0) {
            remove($, tokenId);
        } else {
            reposition($, tokenId);
        }
        refreshSeating($, prevTop);
        syncTopSeatControl($, nft);
        syncSeatingControl($, nft, tokenId);
        emit IBoard.Undelegate(sender, tokenId, amount);
    }

    function reposition(BoardTypes.BoardStorage storage $, uint256 tokenId) public {
        if ($.nodes[tokenId].tokenId != tokenId) revert IBoard.NodeDoesNotExist();
        uint256 amount = $.nodes[tokenId].amount;

        while ($.nodes[tokenId].prev != 0 && amount > $.nodes[$.nodes[tokenId].prev].amount) {
            swapUp($, tokenId);
        }

        if ($.nodes[tokenId].prev == 0 || amount <= $.nodes[$.nodes[tokenId].prev].amount) {
            while ($.nodes[tokenId].next != 0 && amount < $.nodes[$.nodes[tokenId].next].amount) {
                swapDown($, tokenId);
            }
        }
    }

    function insert(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 amount) public {
        if (tokenId > type(uint128).max) revert IBoard.TokenIdTooLarge();

        if ($.size >= BoardTypes.MAX_NODES) {
            if (amount <= $.nodes[$.tail].amount) revert IBoard.MaxNodesReached();
            uint256 evicted = $.tail;
            remove($, evicted);
            $.evictedTokenIds.add(evicted);
        }
        $.evictedTokenIds.remove(tokenId);

        if ($.head == 0) {
            initializeFirstNode($, tokenId, amount);
        } else {
            insertNodeInOrder($, tokenId, amount);
        }
        unchecked {
            $.size++;
        }
    }

    function remove(BoardTypes.BoardStorage storage $, uint256 tokenId) public returns (bool) {
        BoardTypes.Node storage node = $.nodes[tokenId];

        if (node.tokenId != tokenId) {
            return false;
        }

        uint256 prev = uint256(node.prev);
        uint256 next = uint256(node.next);

        if (prev != 0) {
            $.nodes[prev].next = uint128(next);
        } else {
            $.head = next;
        }

        if (next != 0) {
            $.nodes[next].prev = uint128(prev);
        } else {
            $.tail = prev;
        }

        delete $.nodes[tokenId];
        if ($.seatedAt[tokenId] != 0) {
            delete $.seatedAt[tokenId];
        }

        if ($.size > 0) {
            unchecked {
                $.size--;
            }
        }
        return true;
    }

    function getTop(BoardTypes.BoardStorage storage $, uint256 count)
        external
        view
        returns (uint256[] memory tokenIds, uint256[] memory amounts)
    {
        uint256 _size = $.size;

        if (_size == 0) {
            return (new uint256[](0), new uint256[](0));
        }

        uint256 resultCount = count > _size ? _size : count;
        tokenIds = new uint256[](resultCount);
        amounts = new uint256[](resultCount);

        uint256 current = $.head;
        for (uint256 i = 0; i < resultCount && current != 0; i++) {
            tokenIds[i] = current;
            amounts[i] = $.nodes[current].amount;
            current = uint256($.nodes[current].next);
        }
    }

    /// @dev Integer formula used for both configured seats and reachable-director counts (PMN-M01).
    function quorumFor(uint256 n) public pure returns (uint256) {
        return 1 + (n * 51) / 100;
    }

    /// @notice Configured-seat quorum. Board unit tests and first-time `setSeats` use this.
    /// @dev Chamber wallet confirm/execute uses {getQuorum(BoardStorage, IERC721, address)} instead.
    function getQuorum(BoardTypes.BoardStorage storage $) public view returns (uint256) {
        return quorumFor($.seats);
    }

    /// @notice Quorum over reachable authorized top-seat tokenIds (PMN-M01 Solution A).
    /// @dev `ownerOf` succeeds and the owner is not `excludeOwner` (Chamber itself: chamber-held).
    ///      Empty slots and burned/inert ids do not inflate the denominator.
    function getQuorum(BoardTypes.BoardStorage storage $, IERC721 nft, address excludeOwner)
        public
        view
        returns (uint256)
    {
        return quorumFor(countReachableAuthorized($, nft, excludeOwner));
    }

    /// @dev Top-`seats` nodes whose `ownerOf` succeeds and is not `excludeOwner`.
    function countReachableAuthorized(BoardTypes.BoardStorage storage $, IERC721 nft, address excludeOwner)
        public
        view
        returns (uint256 n)
    {
        uint256 current = $.head;
        uint256 remaining = $.seats;
        unchecked {
            while (current != 0 && remaining != 0) {
                address owner = tryOwnerOf(nft, current);
                if (owner != address(0) && owner != excludeOwner) {
                    ++n;
                }
                current = uint256($.nodes[current].next);
                --remaining;
            }
        }
    }

    function getSeats(BoardTypes.BoardStorage storage $) external view returns (uint256) {
        return $.seats;
    }

    function setSeats(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 numOfSeats) external {
        setSeats($, tokenId, numOfSeats, getQuorum($));
    }

    function setSeats(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 numOfSeats, uint256 liveQuorum)
        public
    {
        if (numOfSeats <= 0) revert IBoard.InvalidNumSeats();

        if ($.seats == 0) {
            $.seats = uint32(numOfSeats);
            emit IBoard.ExecuteSetSeats(tokenId, numOfSeats);
            return;
        }

        BoardTypes.SeatUpdate storage proposal = $.seatUpdate;

        if (proposal.timestamp == 0) {
            proposal.proposedSeats = numOfSeats;
            proposal.timestamp = block.timestamp;
            proposal.requiredQuorum = liveQuorum;
        } else {
            if (proposal.proposedSeats != numOfSeats) {
                authorizeSeatUpdateCancel(proposal, tokenId);
                delete $.seatUpdate;
                emit IBoard.SeatUpdateCancelled(tokenId);
                return;
            }

            for (uint256 i; i < proposal.supporters.length;) {
                if (proposal.supporters[i] == tokenId) {
                    revert IBoard.AlreadySentUpdateRequest();
                }
                unchecked {
                    ++i;
                }
            }
        }

        proposal.supporters.push(tokenId);
        emit IBoard.SetSeats(tokenId, numOfSeats);
    }

    function executeSeatsUpdate(BoardTypes.BoardStorage storage $, uint256 tokenId, IERC721 nft) external {
        uint256[] memory prevTop = topTokenIds($);
        BoardTypes.SeatUpdate storage proposal = $.seatUpdate;

        if (proposal.timestamp == 0) revert IBoard.InvalidProposal();
        if (block.timestamp < proposal.timestamp + BoardTypes.SEAT_UPDATE_TIMELOCK) revert IBoard.TimelockNotExpired();

        uint256 s = $.seats;
        uint256[] memory topIds = new uint256[](s);
        uint256 current = $.head;
        uint256 filled;
        unchecked {
            while (current != 0 && filled < s) {
                topIds[filled] = current;
                current = uint256($.nodes[current].next);
                ++filled;
            }
        }

        uint256 validSupport;
        uint256 supportersLen = proposal.supporters.length;
        bool checkOwner = address(nft) != address(0) && address(nft).code.length != 0;
        unchecked {
            for (uint256 i; i < supportersLen; ++i) {
                uint256 sup = proposal.supporters[i];
                // PMN-M01: burned / inert supporters do not count toward seat-change quorum.
                if (checkOwner && tryOwnerOf(nft, sup) == address(0)) {
                    continue;
                }
                for (uint256 j; j < filled; ++j) {
                    if (topIds[j] == sup) {
                        ++validSupport;
                        break;
                    }
                }
            }
        }

        if (validSupport < proposal.requiredQuorum) {
            revert IBoard.InsufficientVotes();
        }

        uint256 newSeats = proposal.proposedSeats;
        $.seats = uint32(newSeats);
        delete $.seatUpdate;
        refreshSeating($, prevTop);
        syncTopSeatControl($, nft);
        emit IBoard.ExecuteSetSeats(tokenId, newSeats);
    }

    /// @dev Immediate seat decrease for PMN-M01 Solution C. Caller enforces recovery preconditions.
    function recoverSeats(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 newSeats, IERC721 nft)
        external
    {
        if (newSeats == 0 || newSeats >= $.seats) revert IBoard.InvalidNumSeats();
        uint256[] memory prevTop = topTokenIds($);
        $.seats = uint32(newSeats);
        delete $.seatUpdate;
        refreshSeating($, prevTop);
        syncTopSeatControl($, nft);
        emit IBoard.ExecuteSetSeats(tokenId, newSeats);
    }

    function cancelSeatUpdate(BoardTypes.BoardStorage storage $, uint256 tokenId) external {
        BoardTypes.SeatUpdate storage proposal = $.seatUpdate;
        if (proposal.timestamp == 0) revert IBoard.InvalidProposal();

        authorizeSeatUpdateCancel(proposal, tokenId);
        delete $.seatUpdate;
        emit IBoard.SeatUpdateCancelled(tokenId);
    }

    function topTokenIds(BoardTypes.BoardStorage storage $) public view returns (uint256[] memory ids) {
        uint256 n = $.seats;
        if (n == 0 || $.head == 0) {
            return new uint256[](0);
        }

        ids = new uint256[](n);
        uint256 current = $.head;
        uint256 filled;
        unchecked {
            while (current != 0 && filled < n) {
                ids[filled] = current;
                current = uint256($.nodes[current].next);
                ++filled;
            }
        }
        if (filled == n) {
            return ids;
        }

        uint256[] memory trimmed = new uint256[](filled);
        for (uint256 i; i < filled;) {
            trimmed[i] = ids[i];
            unchecked {
                ++i;
            }
        }
        return trimmed;
    }

    function getSeatedAt(BoardTypes.BoardStorage storage $, uint256 tokenId) external view returns (uint256) {
        return $.seatedAt[tokenId];
    }

    function isSeatingMature(BoardTypes.BoardStorage storage $, uint256 tokenId) external view returns (bool) {
        uint256 seatedAt = $.seatedAt[tokenId];
        if (seatedAt == 0) return true;
        return block.number >= seatedAt;
    }

    /// @dev Stored checkpoint, or `block.number + SEATING_DELAY` when `ownerOf` != seated snap (PMN-H01 A).
    function effectiveSeatedAt(BoardTypes.BoardStorage storage $, IERC721 nft, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 stored = $.seatedAt[tokenId];
        address snap = $.seatedOwner[tokenId];
        if (snap == address(0)) return stored;
        address owner = tryOwnerOf(nft, tokenId);
        if (owner != address(0) && owner != snap) {
            return block.number + BoardTypes.SEATING_DELAY;
        }
        return stored;
    }

    function isSeatingMature(BoardTypes.BoardStorage storage $, IERC721 nft, uint256 tokenId)
        external
        view
        returns (bool)
    {
        uint256 seatedAt = effectiveSeatedAt($, nft, tokenId);
        if (seatedAt == 0) return true;
        return block.number >= seatedAt;
    }

    /// @dev Bind or reset the seating clock when `ownerOf` changes. Call after board mutations and before director checks.
    function syncSeatingControl(BoardTypes.BoardStorage storage $, IERC721 nft, uint256 tokenId) public {
        address owner = tryOwnerOf(nft, tokenId);
        if (owner == address(0)) {
            delete $.seatedOwner[tokenId];
            return;
        }

        address snap = $.seatedOwner[tokenId];
        if (snap == address(0)) {
            $.seatedOwner[tokenId] = owner;
            return;
        }
        if (snap == owner) return;

        $.seatedOwner[tokenId] = owner;
        if (inTopSeats($, tokenId)) {
            $.seatedAt[tokenId] = block.number + BoardTypes.SEATING_DELAY;
        }
    }

    function syncTopSeatControl(BoardTypes.BoardStorage storage $, IERC721 nft) public {
        uint256 current = $.head;
        uint256 remaining = $.seats;
        while (current != 0 && remaining != 0) {
            syncSeatingControl($, nft, current);
            current = uint256($.nodes[current].next);
            unchecked {
                --remaining;
            }
        }
    }

    function tryOwnerOf(IERC721 nft, uint256 tokenId) internal view returns (address owner) {
        if (address(nft) == address(0) || address(nft).code.length == 0) return address(0);
        try nft.ownerOf(tokenId) returns (address o) {
            return o;
        } catch {
            return address(0);
        }
    }

    /// @dev Rank occupancy by configured `seats`. Inert ids still occupy a slot if weight remains
    ///      (PMN-M02 rank cleanup). Quorum denominator uses {countReachableAuthorized} instead.
    function inTopSeats(BoardTypes.BoardStorage storage $, uint256 tokenId) internal view returns (bool) {
        uint256 current = $.head;
        uint256 remaining = $.seats;
        while (current != 0 && remaining != 0) {
            if (current == tokenId) return true;
            current = uint256($.nodes[current].next);
            unchecked {
                --remaining;
            }
        }
        return false;
    }

    /// @dev Live top-seat flags whose recorded controller still matches `ownerOf` (PMN-H01 A).
    function countCurrentDirectorFlags(
        BoardTypes.BoardStorage storage $,
        IERC721 nft,
        mapping(uint256 nonce => mapping(uint256 tokenId => bool)) storage flags,
        mapping(uint256 nonce => mapping(uint256 tokenId => address)) storage flagOwners,
        uint256 nonce
    ) external view returns (uint256 count) {
        uint256 current = $.head;
        uint256 remaining = $.seats;
        unchecked {
            while (current != 0 && remaining > 0) {
                if (flags[nonce][current] && flagBelongsToCurrentController(nft, flagOwners, nonce, current)) {
                    ++count;
                }
                current = uint256($.nodes[current].next);
                --remaining;
            }
        }
    }

    function flagBelongsToCurrentController(
        IERC721 nft,
        mapping(uint256 nonce => mapping(uint256 tokenId => address)) storage flagOwners,
        uint256 nonce,
        uint256 tokenId
    ) internal view returns (bool) {
        address owner = tryOwnerOf(nft, tokenId);
        // PMN-M01 / minimal PMN-M02: burned or otherwise inert tokenIds do not contribute flags.
        if (owner == address(0)) return false;
        address recorded = flagOwners[nonce][tokenId];
        if (recorded == address(0)) return true;
        return owner == recorded;
    }

    function swapUp(BoardTypes.BoardStorage storage $, uint256 tokenId) internal {
        uint256 prevId = uint256($.nodes[tokenId].prev);
        uint256 aId = uint256($.nodes[prevId].prev);
        uint256 bId = uint256($.nodes[tokenId].next);

        if (aId != 0) {
            $.nodes[aId].next = uint128(tokenId);
        } else {
            $.head = tokenId;
        }
        $.nodes[tokenId].prev = uint128(aId);
        $.nodes[tokenId].next = uint128(prevId);

        $.nodes[prevId].prev = uint128(tokenId);
        $.nodes[prevId].next = uint128(bId);
        if (bId != 0) {
            $.nodes[bId].prev = uint128(prevId);
        } else {
            $.tail = prevId;
        }
    }

    function swapDown(BoardTypes.BoardStorage storage $, uint256 tokenId) internal {
        uint256 nextId = uint256($.nodes[tokenId].next);
        uint256 aId = uint256($.nodes[tokenId].prev);
        uint256 bId = uint256($.nodes[nextId].next);

        if (aId != 0) {
            $.nodes[aId].next = uint128(nextId);
        } else {
            $.head = nextId;
        }
        $.nodes[nextId].prev = uint128(aId);
        $.nodes[nextId].next = uint128(tokenId);

        $.nodes[tokenId].prev = uint128(nextId);
        $.nodes[tokenId].next = uint128(bId);
        if (bId != 0) {
            $.nodes[bId].prev = uint128(tokenId);
        } else {
            $.tail = tokenId;
        }
    }

    function initializeFirstNode(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 amount) internal {
        $.nodes[tokenId] = BoardTypes.Node({tokenId: tokenId, amount: amount, next: 0, prev: 0});
        $.head = tokenId;
        $.tail = tokenId;
    }

    function insertNodeInOrder(BoardTypes.BoardStorage storage $, uint256 tokenId, uint256 amount) internal {
        uint256 current = $.head;
        uint256 previous;

        unchecked {
            while (current != 0 && amount <= $.nodes[current].amount) {
                previous = current;
                current = uint256($.nodes[current].next);
            }

            BoardTypes.Node storage newNode = $.nodes[tokenId];
            newNode.tokenId = tokenId;
            newNode.amount = amount;
            newNode.next = uint128(current);
            newNode.prev = uint128(previous);

            if (current == 0) {
                $.nodes[previous].next = uint128(tokenId);
                $.tail = tokenId;
            } else if (previous == 0) {
                $.nodes[current].prev = uint128(tokenId);
                $.head = tokenId;
            } else {
                $.nodes[previous].next = uint128(tokenId);
                $.nodes[current].prev = uint128(tokenId);
            }
        }
    }

    function refreshSeating(BoardTypes.BoardStorage storage $, uint256[] memory prevTop) internal {
        uint256 current = $.head;
        uint256 remaining = $.seats;
        uint256 activationBlock = block.number + BoardTypes.SEATING_DELAY;

        while (current != 0) {
            if (remaining != 0) {
                // TokenId-scoped: a token already in the previous top keeps seatedAt.
                // Control-transfer reset is Chamber/BoardLib.syncSeatingControl (PMN-H01 A).
                if ($.seatedAt[current] == 0 && !wasInTop(current, prevTop)) {
                    $.seatedAt[current] = activationBlock;
                }
                unchecked {
                    --remaining;
                }
            } else if ($.seatedAt[current] != 0) {
                delete $.seatedAt[current];
            }
            current = uint256($.nodes[current].next);
        }
    }

    function wasInTop(uint256 tokenId, uint256[] memory prevTop) internal pure returns (bool) {
        uint256 len = prevTop.length;
        for (uint256 i; i < len;) {
            if (prevTop[i] == tokenId) return true;
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function authorizeSeatUpdateCancel(BoardTypes.SeatUpdate storage proposal, uint256 tokenId) internal view {
        if (proposal.supporters.length > 0 && proposal.supporters[0] == tokenId) {
            return;
        }
        if (proposal.timestamp != 0 && block.timestamp >= proposal.timestamp + BoardTypes.SEAT_UPDATE_EXPIRY) {
            return;
        }
        revert IBoard.OnlyProposerCanCancel();
    }

    function collectDelegations(
        BoardTypes.BoardStorage storage $b,
        mapping(address => mapping(uint256 => uint256)) storage holderDelegation,
        mapping(address => uint256) storage totalHolderDelegations,
        mapping(address => EnumerableSet.UintSet) storage holderDelegatedTokenIds,
        address holder
    ) external view returns (uint256[] memory tokenIds, uint256[] memory amounts) {
        EnumerableSet.UintSet storage tracked = holderDelegatedTokenIds[holder];
        uint256[] memory setIds = tracked.values();
        uint256 setLen = setIds.length;

        uint256 trackedTotal;
        for (uint256 i = 0; i < setLen;) {
            trackedTotal += holderDelegation[holder][setIds[i]];
            unchecked {
                ++i;
            }
        }

        if (trackedTotal == totalHolderDelegations[holder]) {
            tokenIds = setIds;
            amounts = new uint256[](setLen);
            for (uint256 i = 0; i < setLen;) {
                amounts[i] = holderDelegation[holder][setIds[i]];
                unchecked {
                    ++i;
                }
            }
            return (tokenIds, amounts);
        }

        uint256 maxLen = setLen + uint256($b.size) + $b.evictedTokenIds.length();
        uint256[] memory tmpIds = new uint256[](maxLen);
        uint256[] memory tmpAmts = new uint256[](maxLen);
        uint256 n;

        for (uint256 i = 0; i < setLen;) {
            uint256 id = setIds[i];
            uint256 amount = holderDelegation[holder][id];
            if (amount > 0) {
                tmpIds[n] = id;
                tmpAmts[n] = amount;
                unchecked {
                    ++n;
                }
            }
            unchecked {
                ++i;
            }
        }

        uint256 tokenId = $b.head;
        while (tokenId != 0) {
            uint256 amount = holderDelegation[holder][tokenId];
            if (amount > 0 && !tracked.contains(tokenId)) {
                tmpIds[n] = tokenId;
                tmpAmts[n] = amount;
                unchecked {
                    ++n;
                }
            }
            tokenId = uint256($b.nodes[tokenId].next);
        }

        uint256 evictedLen = $b.evictedTokenIds.length();
        for (uint256 i = 0; i < evictedLen;) {
            uint256 evictedId = $b.evictedTokenIds.at(i);
            uint256 amount = holderDelegation[holder][evictedId];
            if (amount > 0 && !tracked.contains(evictedId) && $b.nodes[evictedId].tokenId != evictedId) {
                tmpIds[n] = evictedId;
                tmpAmts[n] = amount;
                unchecked {
                    ++n;
                }
            }
            unchecked {
                ++i;
            }
        }

        tokenIds = new uint256[](n);
        amounts = new uint256[](n);
        for (uint256 i = 0; i < n;) {
            tokenIds[i] = tmpIds[i];
            amounts[i] = tmpAmts[i];
            unchecked {
                ++i;
            }
        }
    }

    function syncTrackedDelegations(
        BoardTypes.BoardStorage storage $b,
        mapping(address => mapping(uint256 => uint256)) storage holderDelegation,
        mapping(address => EnumerableSet.UintSet) storage holderDelegatedTokenIds,
        address holder
    ) external {
        EnumerableSet.UintSet storage tracked = holderDelegatedTokenIds[holder];

        uint256 tokenId = $b.head;
        while (tokenId != 0) {
            if (holderDelegation[holder][tokenId] > 0) {
                tracked.add(tokenId);
            }
            tokenId = uint256($b.nodes[tokenId].next);
        }

        uint256 evictedLen = $b.evictedTokenIds.length();
        for (uint256 i = 0; i < evictedLen;) {
            uint256 evictedId = $b.evictedTokenIds.at(i);
            if (holderDelegation[holder][evictedId] > 0) {
                tracked.add(evictedId);
            }
            unchecked {
                ++i;
            }
        }
    }
}
