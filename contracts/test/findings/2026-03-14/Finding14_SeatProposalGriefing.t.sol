// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IBoard} from "src/interfaces/IBoard.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title Finding 14: Seat Update Proposal Griefing by Minority Director [LOW] — FIXED
 *
 * @notice Only the proposer can cancel a pending seat update proposal. Non-proposers
 *         calling updateSeats() with a different value revert with OnlyProposerCanCancel.
 *
 * Fix: Require cancellation to come from the proposer (supporters[0]) only.
 */
contract SeatProposalGriefingTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public director1 = address(0x1);
    address public director2 = address(0x2);
    address public director3 = address(0x3);
    address public griefer = address(0x4); // minority director with smallest stake
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        // 4 seats chamber; quorum = 1 + (4 * 51) / 100 = 1 + 2 = 3
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 4, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        // Directors 1-3 have large stake; griefer has minimal stake
        _setupDirector(director1, 1, 1000e18);
        _setupDirector(director2, 2, 1000e18);
        _setupDirector(director3, 3, 1000e18);
        _setupDirector(griefer, 4, 1e18); // just 1 share — weakest director
        vm.roll(block.number + 1);

        assertEq(chamber.getSeats(), 4, "4 seats");
        assertEq(chamber.getQuorum(), 3, "quorum = 3");
    }

    /**
     * @notice FIXED: Non-proposer cannot cancel the proposal — reverts with OnlyProposerCanCancel
     */
    function test_Fixed_NonProposerCannotCancel() public {
        // Majority (directors 1, 2, 3) want to reduce seats from 4 to 3
        vm.prank(director1);
        chamber.updateSeats(1, 3);

        vm.prank(director2);
        chamber.updateSeats(2, 3);

        vm.prank(director3);
        chamber.updateSeats(3, 3);

        // Proposal exists with 3 supporters (proposer = director1/tokenId 1)
        (uint256 proposedSeats, uint256 timestamp,,) = chamber.getSeatUpdate();
        assertEq(proposedSeats, 3, "Proposal for 3 seats");
        assertGt(timestamp, 0, "Proposal active");

        // Griefer (tokenId 4, not proposer) cannot cancel — reverts
        vm.prank(griefer);
        vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
        chamber.updateSeats(4, 5);

        // Proposal still exists
        (uint256 proposedSeatsAfter, uint256 timestampAfter,,) = chamber.getSeatUpdate();
        assertEq(proposedSeatsAfter, 3, "Proposal intact");
        assertGt(timestampAfter, 0, "Proposal still active");
    }

    /**
     * @notice Demonstrates that a valid proposal (no griefing) executes correctly.
     */
    function test_Baseline_ValidProposalExecutes() public {
        vm.prank(director1);
        chamber.updateSeats(1, 3);
        vm.prank(director2);
        chamber.updateSeats(2, 3);
        vm.prank(director3);
        chamber.updateSeats(3, 3);

        // Wait for 7-day timelock
        vm.warp(block.timestamp + 7 days + 1);

        // Execute (griefer didn't intervene)
        vm.prank(director1);
        chamber.executeSeatsUpdate(1);

        assertEq(chamber.getSeats(), 3, "Seats reduced to 3");
        console.log("[BASELINE] Valid proposal executes after timelock");
    }

    /**
     * @notice FIXED: Griefer cannot cancel — each attempt reverts
     */
    function test_Fixed_GriefingBlocked() public {
        vm.prank(director1);
        chamber.updateSeats(1, 3);
        vm.prank(director2);
        chamber.updateSeats(2, 3);
        vm.prank(director3);
        chamber.updateSeats(3, 3);

        // Griefer cannot cancel — reverts every time
        for (uint256 round = 0; round < 3; round++) {
            vm.prank(griefer);
            vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
            chamber.updateSeats(4, 5 + round);
        }

        // Proposal intact, can proceed after timelock
        (uint256 proposedSeats,,,) = chamber.getSeatUpdate();
        assertEq(proposedSeats, 3, "Proposal intact");
    }

    // ─── helpers ────────────────────────────────────────────────────────────────

    function _setupDirector(address user, uint256 tokenId, uint256 amount) internal {
        token.mint(user, amount);
        nft.mintWithTokenId(user, tokenId);

        vm.startPrank(user);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user);
        uint256 shares = chamber.balanceOf(user);
        chamber.delegate(tokenId, shares);
        vm.stopPrank();
    }
}
