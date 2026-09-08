// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {MockBoard} from "test/mock/MockBoard.sol";
import {BoardTypes} from "src/types/BoardTypes.sol";

/// @notice Symbolic verification of Board linked-list and seating invariants via Halmos
/// @dev Bounded to two nodes so default `--loop 2` can close list walks.
contract BoardSymTest is Test, SymTest {
    MockBoard internal board;

    function setUp() public {
        board = new MockBoard();
    }

    /// @dev After two inserts, the board remains sorted in descending order by amount
    function symbolicSortedOrderAfterTwoInserts() public {
        uint256 tokenId1 = svm.createUint(128, "tokenId1");
        uint256 tokenId2 = svm.createUint(128, "tokenId2");
        vm.assume(tokenId1 > 0 && tokenId2 > 0 && tokenId1 != tokenId2);

        uint256 amount1 = svm.createUint256("amount1");
        uint256 amount2 = svm.createUint256("amount2");
        vm.assume(amount1 > 0 && amount2 > 0);

        board.insert(tokenId1, amount1);
        board.insert(tokenId2, amount2);

        _assertSortedDescending(2);
        _assertUniqueTop(2);
    }

    /// @dev Production `delegate` path never inserts a second node for the same tokenId
    function symbolicDelegateSameIdDoesNotDuplicateNode() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        uint256 first = svm.createUint(64, "first");
        uint256 extra = svm.createUint(64, "extra");
        vm.assume(tokenId > 0 && first > 0 && extra > 0);
        vm.assume(first <= type(uint256).max - extra);

        board.exposed_delegate(tokenId, first);
        board.exposed_delegate(tokenId, extra);

        assertEq(board.getSize(), 1);
        MockBoard.Node memory node = board.getNode(tokenId);
        assertEq(node.tokenId, tokenId);
        assertEq(node.amount, first + extra);
        _assertUniqueTop(1);
    }

    /// @dev Delegate then undelegate preserves the node's remaining delegation amount
    function symbolicDelegateUndelegateConservation() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        vm.assume(tokenId > 0);

        uint256 initial = svm.createUint256("initial");
        uint256 extra = svm.createUint256("extra");
        uint256 undelegate = svm.createUint256("undelegate");
        vm.assume(initial > 0 && extra > 0);
        vm.assume(initial <= type(uint256).max - extra);

        uint256 total = initial + extra;
        vm.assume(undelegate > 0 && undelegate <= total);

        board.exposed_delegate(tokenId, initial);
        board.exposed_delegate(tokenId, extra);
        board.exposed_undelegate(tokenId, undelegate);

        MockBoard.Node memory node = board.getNode(tokenId);
        assertEq(node.amount, total - undelegate);
        _assertSortedDescending(board.getSize());
    }

    /// @dev Quorum is the integer formula `1 + (seats * 51) / 100` for every legal seat count
    function symbolicQuorumFormula() public {
        uint256 seats = svm.createUint(5, "seats");
        vm.assume(seats >= 1 && seats <= 20);

        board.setSeats(0, seats);

        assertEq(board.getSeats(), seats);
        assertEq(board.getQuorum(), 1 + (seats * 51) / 100);
    }

    /// @dev A token that newly enters the top-seat set is immature until `SEATING_DELAY` blocks
    function symbolicSeatingDelayOnNewTopNode() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        uint256 amount = svm.createUint(64, "amount");
        vm.assume(tokenId > 0 && amount > 0);

        board.setSeats(0, 1);
        uint256 start = block.number;
        board.exposed_delegate(tokenId, amount);

        assertEq(board.getSeatedAt(tokenId), start + BoardTypes.SEATING_DELAY);
        assertFalse(board.isSeatingMature(tokenId));

        vm.roll(start + BoardTypes.SEATING_DELAY);
        assertTrue(board.isSeatingMature(tokenId));
    }

    /// @dev Additional delegation to an already-top token does not restart the seating delay
    function symbolicSeatingDelayNotResetOnExistingTop() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        uint256 first = svm.createUint(32, "first");
        uint256 extra = svm.createUint(32, "extra");
        vm.assume(tokenId > 0 && first > 0 && extra > 0);

        board.setSeats(0, 1);
        board.exposed_delegate(tokenId, first);
        uint256 seatedAt = board.getSeatedAt(tokenId);

        board.exposed_delegate(tokenId, extra);
        assertEq(board.getSeatedAt(tokenId), seatedAt);
    }

    /// @dev First seat-update after seats are live snapshots the current quorum
    function symbolicSeatUpdateSnapshotsQuorum() public {
        uint256 currentSeats = svm.createUint(5, "currentSeats");
        uint256 proposedSeats = svm.createUint(5, "proposedSeats");
        vm.assume(currentSeats >= 1 && currentSeats <= 20);
        vm.assume(proposedSeats >= 1 && proposedSeats <= 20);
        vm.assume(proposedSeats != currentSeats);

        board.setSeats(0, currentSeats);
        uint256 liveQuorum = board.getQuorum();
        board.setSeats(1, proposedSeats);

        (uint256 proposed, uint256 timestamp, uint256 requiredQuorum,) = board.getSeatUpdate();
        assertEq(proposed, proposedSeats);
        assertEq(timestamp, block.timestamp);
        assertEq(requiredQuorum, liveQuorum);
    }

    /// @dev Shared OZ reentrancy guard blocks a second delegate while the lock is held
    function symbolicCircuitBreakerBlocksReentrantDelegate() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        uint256 amount = svm.createUint256("amount");
        vm.assume(tokenId > 0 && amount > 0);

        (bool success,) = address(board).call(abi.encodeCall(MockBoard.lockAndDelegate, (tokenId, amount)));
        assertFalse(success);
    }

    function _assertSortedDescending(uint256 count) internal view {
        if (count < 2) return;

        (uint256[] memory topIds, uint256[] memory topAmounts) = board.getTop(count);
        assertEq(topIds.length, count);
        assertEq(topAmounts.length, count);

        for (uint256 i = 1; i < topAmounts.length; ++i) {
            assertGe(topAmounts[i - 1], topAmounts[i]);
        }
    }

    function _assertUniqueTop(uint256 count) internal view {
        (uint256[] memory topIds,) = board.getTop(count);
        assertEq(topIds.length, count);
        for (uint256 i = 0; i < topIds.length; ++i) {
            for (uint256 j = i + 1; j < topIds.length; ++j) {
                assertTrue(topIds[i] != topIds[j]);
            }
            MockBoard.Node memory node = board.getNode(topIds[i]);
            assertEq(node.tokenId, topIds[i]);
        }
    }
}
