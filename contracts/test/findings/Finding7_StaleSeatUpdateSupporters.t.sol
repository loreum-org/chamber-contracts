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
 * @title Finding 7: Stale Seat Update Supporters [MEDIUM] — FIXED
 * @notice Verifies that _executeSeatsUpdate now validates supporters are still
 *         in top seats at execution time.
 */
contract StaleSeatUpdateSupportersTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 3, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        _setupDirector(user1, 1, 100e18);
        _setupDirector(user2, 2, 100e18);
        _setupDirector(user3, 3, 100e18);
        vm.roll(block.number + 1);
    }

    /**
     * @notice FIXED: Seat update proposal now fails if supporters lost directorship.
     */
    function test_Fixed_StaleProposalRejected() public {
        // Step 1: All three directors support seat change to 5
        vm.prank(user1);
        chamber.updateSeats(1, 5);
        vm.prank(user2);
        chamber.updateSeats(2, 5);
        vm.prank(user3);
        chamber.updateSeats(3, 5);

        // Step 2: user1 and user2 undelegate (lose directorship)
        vm.prank(user1);
        chamber.undelegate(1, 1);
        vm.prank(user2);
        chamber.undelegate(2, 1);

        assertEq(chamber.getSize(), 1, "Only 1 director remains");

        // Step 3: Wait for timelock
        vm.warp(block.timestamp + 7 days + 1);

        // Step 4: FIXED — execution now reverts because only 1 of 3 supporters is still a director
        // Quorum was 2 at proposal time, but only 1 valid supporter remains
        vm.prank(user3);
        vm.expectRevert(IBoard.InsufficientVotes.selector);
        chamber.executeSeatsUpdate(3);

        // Seats unchanged
        assertEq(chamber.getSeats(), 3, "Seats remain unchanged");
        console.log("FIXED: Stale supporters correctly rejected");
    }

    /**
     * @notice Verify that proposal succeeds when all supporters are still directors.
     */
    function test_Fixed_ValidProposalSucceeds() public {
        vm.prank(user1);
        chamber.updateSeats(1, 5);
        vm.prank(user2);
        chamber.updateSeats(2, 5);
        vm.prank(user3);
        chamber.updateSeats(3, 5);

        vm.warp(block.timestamp + 7 days + 1);

        // All supporters still have directorship — should succeed
        vm.prank(user3);
        chamber.executeSeatsUpdate(3);

        assertEq(chamber.getSeats(), 5, "Seats updated with valid supporters");
    }

    function _setupDirector(address user, uint256 tokenId, uint256 amount) internal {
        token.mint(user, amount);
        nft.mintWithTokenId(user, tokenId);

        vm.startPrank(user);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, 1);
        vm.stopPrank();
    }
}
