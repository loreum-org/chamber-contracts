// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IBoard} from "src/interfaces/IBoard.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title H-03: Seat-update slot has no expiry [HIGH] — FIXED
 *
 * @notice The single SeatUpdate slot could only be cancelled by supporters[0], and
 *         updateSeats is isDirector-gated. If the proposer left before quorum, the
 *         slot stayed occupied forever. After a 14-day expiry, any current director
 *         may delete the proposal. The 7-day execute timelock is unchanged.
 */
contract SeatUpdateExpiryTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public director1 = address(0x1);
    address public director2 = address(0x2);
    address public director3 = address(0x3);
    address public minority = address(0x4);
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        // 4 seats; quorum = 1 + (4 * 51) / 100 = 3
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 4, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        _setupDirector(director1, 1, 1000e18);
        _setupDirector(director2, 2, 1000e18);
        _setupDirector(director3, 3, 1000e18);
        _setupDirector(minority, 4, 1e18);
        vm.roll(block.number + 1);

        assertEq(chamber.getSeats(), 4);
        assertEq(chamber.getQuorum(), 3);
    }

    /**
     * @notice After expiry, a current director can clear a stuck proposal even if the
     *         original proposer is no longer a director.
     */
    function test_ExpiredProposal_CurrentDirectorCanClear() public {
        vm.prank(director1);
        chamber.updateSeats(1, 5);

        // Proposer leaves the board — cannot cancel via isDirector-gated updateSeats
        uint256 stake = chamber.getHolderDelegation(director1, 1);
        vm.prank(director1);
        chamber.undelegate(1, stake);
        assertEq(chamber.getSize(), 3, "proposer left the leaderboard");

        vm.prank(director1);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.cancelSeatUpdate(1);

        vm.prank(director2);
        vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
        chamber.cancelSeatUpdate(2);

        vm.warp(block.timestamp + 14 days);

        vm.prank(director2);
        chamber.cancelSeatUpdate(2);

        (uint256 proposedSeats, uint256 timestamp,, uint256[] memory supporters) = chamber.getSeatUpdate();
        assertEq(proposedSeats, 0, "proposal cleared");
        assertEq(timestamp, 0, "slot empty");
        assertEq(supporters.length, 0, "no leftover supporters");

        // Slot is reusable: a remaining director can open a new proposal
        vm.prank(director2);
        chamber.updateSeats(2, 3);
        (uint256 nextSeats, uint256 nextTimestamp,,) = chamber.getSeatUpdate();
        assertEq(nextSeats, 3);
        assertGt(nextTimestamp, 0);
    }

    /**
     * @notice Before expiry, a minority director cannot grief-cancel by proposing a
     *         different seat count or calling cancelSeatUpdate.
     */
    function test_UnexpiredProposal_MinorityCannotGriefCancel() public {
        vm.prank(director1);
        chamber.updateSeats(1, 3);
        vm.prank(director2);
        chamber.updateSeats(2, 3);
        vm.prank(director3);
        chamber.updateSeats(3, 3);

        vm.prank(minority);
        vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
        chamber.updateSeats(4, 5);

        vm.prank(minority);
        vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
        chamber.cancelSeatUpdate(4);

        // Still inside the 7–14 day execute window: minority still cannot cancel
        vm.warp(block.timestamp + 8 days);
        vm.prank(minority);
        vm.expectRevert(IBoard.OnlyProposerCanCancel.selector);
        chamber.cancelSeatUpdate(4);

        (uint256 proposedSeats, uint256 timestamp,,) = chamber.getSeatUpdate();
        assertEq(proposedSeats, 3, "proposal intact");
        assertGt(timestamp, 0, "proposal still active");
    }

    /**
     * @notice Execute still requires the 7-day timelock even when the proposal has quorum.
     */
    function test_ExecuteStillRequiresTimelock() public {
        vm.prank(director1);
        chamber.updateSeats(1, 3);
        vm.prank(director2);
        chamber.updateSeats(2, 3);
        vm.prank(director3);
        chamber.updateSeats(3, 3);

        vm.prank(director1);
        vm.expectRevert(IBoard.TimelockNotExpired.selector);
        chamber.executeSeatsUpdate(1);

        vm.warp(block.timestamp + 7 days - 1);
        vm.prank(director1);
        vm.expectRevert(IBoard.TimelockNotExpired.selector);
        chamber.executeSeatsUpdate(1);

        vm.warp(block.timestamp + 1);
        vm.prank(director1);
        chamber.executeSeatsUpdate(1);
        assertEq(chamber.getSeats(), 3, "seats reduced after timelock");
    }

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
