// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title Finding 11: Permanent Delegation Lock on Evicted Board Nodes [HIGH] — FIXED
 * @notice Verifies that undelegate() correctly handles evicted board nodes by updating
 *         delegation accounting without reverting when the node no longer exists.
 */
contract EvictedNodeDelegationLockTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public filler = makeAddr("filler");
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 20, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        token.mint(alice, 1000e18);
        token.mint(bob, 1000e18);
        token.mint(filler, 100000e18);

        nft.mintWithTokenId(alice, 55);
        nft.mintWithTokenId(bob, 200);
        for (uint256 i = 1; i <= 49; i++) {
            nft.mintWithTokenId(filler, i);
        }
    }

    /**
     * @notice FIXED: Alice can undelegate from an evicted node and withdraw her funds
     */
    function test_Fixed_UndelegateFromEvictedNode() public {
        // Fill board: Alice adds tail node (50) first, then filler adds 49 nodes (52 each)
        // Result: 49 nodes with 52, 1 node (55) with 50 as tail
        vm.startPrank(alice);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, alice);
        chamber.delegate(55, 50); // Alice creates tail node with 50
        vm.stopPrank();

        vm.startPrank(filler);
        token.approve(chamberAddress, 100000e18);
        chamber.deposit(100000e18, filler);
        for (uint256 i = 1; i <= 49; i++) {
            chamber.delegate(i, 52); // 49 nodes with 52 each
        }
        vm.stopPrank();

        assertEq(chamber.getSize(), 50, "Board should be full");
        assertEq(chamber.getHolderDelegation(alice, 55), 50, "Alice should have 50 delegated to 55");

        // Bob delegates 51 to new tokenId 200 — evicts tail (55) since 51 > 50
        vm.startPrank(bob);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, bob);
        chamber.delegate(200, 51);
        vm.stopPrank();

        assertEq(chamber.getSize(), 50, "Board still full after eviction");
        // Node 55 no longer exists on board

        // FIXED: Alice can undelegate even though node 55 was evicted
        vm.prank(alice);
        chamber.undelegate(55, 50);

        assertEq(chamber.getHolderDelegation(alice, 55), 0, "Alice delegation should be cleared");
        assertEq(chamber.getTotalHolderDelegations(alice), 0, "Alice total delegations should be 0");

        // Alice can now withdraw
        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        chamber.redeem(aliceShares, alice, alice);

        assertEq(chamber.balanceOf(alice), 0, "Alice should have no shares left");
        assertGt(token.balanceOf(alice), 0, "Alice should have withdrawn tokens");
    }

    /**
     * @notice FIXED: User can withdraw after undelegating from evicted node
     */
    function test_Fixed_WithdrawAfterUndelegateFromEvictedNode() public {
        // Same setup as above
        vm.startPrank(alice);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, alice);
        chamber.delegate(55, 50);
        vm.stopPrank();

        vm.startPrank(filler);
        token.approve(chamberAddress, 100000e18);
        chamber.deposit(100000e18, filler);
        for (uint256 i = 1; i <= 49; i++) {
            chamber.delegate(i, 52);
        }
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, bob);
        chamber.delegate(200, 51);
        vm.stopPrank();

        vm.prank(alice);
        chamber.undelegate(55, 50);

        // Withdraw should succeed
        uint256 assets = chamber.convertToAssets(chamber.balanceOf(alice));
        vm.prank(alice);
        chamber.withdraw(assets, alice, alice);

        assertEq(chamber.balanceOf(alice), 0);
        assertGt(token.balanceOf(alice), 0);
    }
}
