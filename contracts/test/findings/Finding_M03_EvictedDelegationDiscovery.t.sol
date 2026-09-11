// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title M-03: Evicted delegations are undiscoverable via getDelegations — FIXED
 * @notice After MAX_NODES tail eviction, holderDelegation and totalHolderDelegations remain,
 *         but getDelegations previously walked only the live board list. Holders can now list
 *         evicted tokenIds, undelegate them, and then withdraw/transfer.
 */
contract EvictedDelegationDiscoveryTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public carol = makeAddr("carol");
    address public bob = makeAddr("bob");
    address public filler = makeAddr("filler");
    address public chamberAddress;
    IChamber public chamber;

    uint256 internal constant EVICTED_TOKEN = 55;
    uint256 internal constant ALICE_AMOUNT = 50;
    uint256 internal constant CAROL_AMOUNT = 40;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 20, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        token.mint(alice, 1000e18);
        token.mint(carol, 1000e18);
        token.mint(bob, 1000e18);
        token.mint(filler, 100000e18);

        nft.mintWithTokenId(alice, EVICTED_TOKEN);
        nft.mintWithTokenId(bob, 200);
        for (uint256 i = 1; i <= 49; i++) {
            nft.mintWithTokenId(filler, i);
        }
    }

    function _fillBoardWithAliceAsTail() internal {
        vm.startPrank(alice);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, alice);
        chamber.delegate(EVICTED_TOKEN, ALICE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(filler);
        token.approve(chamberAddress, 100000e18);
        chamber.deposit(100000e18, filler);
        for (uint256 i = 1; i <= 49; i++) {
            chamber.delegate(i, 52);
        }
        vm.stopPrank();

        assertEq(chamber.getSize(), 50, "Board should be full");
    }

    function _evictTail(uint256 newAmount) internal {
        vm.startPrank(bob);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, bob);
        chamber.delegate(200, newAmount);
        vm.stopPrank();

        assertEq(chamber.getSize(), 50, "Board still full after eviction");
        (uint256 tokenId,,,) = chamber.getMember(EVICTED_TOKEN);
        assertEq(tokenId, 0, "Evicted tokenId must be gone from the board");
    }

    function _containsDelegation(address holder, uint256 expectedTokenId, uint256 expectedAmount)
        internal
        view
        returns (bool)
    {
        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(holder);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == expectedTokenId && amounts[i] == expectedAmount) {
                return true;
            }
        }
        return false;
    }

    /// @notice After eviction, getDelegations still lists the evicted tokenId and amount.
    function test_M03_GetDelegationsIncludesEvictedTokenId() public {
        _fillBoardWithAliceAsTail();
        _evictTail(51);

        assertEq(chamber.getHolderDelegation(alice, EVICTED_TOKEN), ALICE_AMOUNT);
        assertEq(chamber.getTotalHolderDelegations(alice), ALICE_AMOUNT);
        assertTrue(_containsDelegation(alice, EVICTED_TOKEN, ALICE_AMOUNT), "getDelegations must include evicted id");
    }

    /// @notice Holder can undelegate the listed evicted tokenId; withdraw then succeeds.
    function test_M03_ListUndelegateThenWithdraw() public {
        _fillBoardWithAliceAsTail();
        _evictTail(51);

        assertTrue(_containsDelegation(alice, EVICTED_TOKEN, ALICE_AMOUNT));

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.redeem(aliceShares, alice, alice);

        vm.prank(alice);
        chamber.undelegate(EVICTED_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getHolderDelegation(alice, EVICTED_TOKEN), 0);
        assertEq(chamber.getTotalHolderDelegations(alice), 0);
        (uint256[] memory tokenIds,) = chamber.getDelegations(alice);
        assertEq(tokenIds.length, 0, "cleared evicted id should leave the enumerable set");

        vm.prank(alice);
        chamber.redeem(aliceShares, alice, alice);
        assertEq(chamber.balanceOf(alice), 0);
        assertGt(token.balanceOf(alice), 0);
    }

    /// @notice After undelegate, share transfer is no longer blocked by the evicted lock.
    function test_M03_TransferWorksAfterUndelegate() public {
        _fillBoardWithAliceAsTail();
        _evictTail(51);

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.transfer(carol, aliceShares);

        vm.prank(alice);
        chamber.undelegate(EVICTED_TOKEN, ALICE_AMOUNT);

        vm.prank(alice);
        bool sent = chamber.transfer(carol, aliceShares);
        assertTrue(sent);
        assertEq(chamber.balanceOf(alice), 0);
        assertEq(chamber.balanceOf(carol), aliceShares);
    }

    /// @notice Partial undelegate after eviction keeps the tokenId listed with the remainder.
    function test_M03_PartialUndelegateKeepsEvictedTokenIdListed() public {
        _fillBoardWithAliceAsTail();
        _evictTail(51);

        vm.prank(alice);
        chamber.undelegate(EVICTED_TOKEN, 20);

        assertEq(chamber.getHolderDelegation(alice, EVICTED_TOKEN), 30);
        assertTrue(_containsDelegation(alice, EVICTED_TOKEN, 30));

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.transfer(carol, aliceShares);
    }

    /// @notice Two holders on the same evicted node; one undelegate must not wipe the other.
    function test_M03_UndelegateDoesNotWipeOtherHolderStake() public {
        vm.startPrank(alice);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, alice);
        chamber.delegate(EVICTED_TOKEN, ALICE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(carol);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, carol);
        chamber.delegate(EVICTED_TOKEN, CAROL_AMOUNT);
        vm.stopPrank();

        vm.startPrank(filler);
        token.approve(chamberAddress, 100000e18);
        chamber.deposit(100000e18, filler);
        for (uint256 i = 1; i <= 49; i++) {
            chamber.delegate(i, 100);
        }
        vm.stopPrank();

        // Node 55 has 90; evict with 91 so only that tail is removed
        _evictTail(91);

        assertTrue(_containsDelegation(alice, EVICTED_TOKEN, ALICE_AMOUNT));
        assertTrue(_containsDelegation(carol, EVICTED_TOKEN, CAROL_AMOUNT));

        vm.prank(alice);
        chamber.undelegate(EVICTED_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getHolderDelegation(alice, EVICTED_TOKEN), 0);
        assertEq(chamber.getTotalHolderDelegations(alice), 0);
        (uint256[] memory aliceIds,) = chamber.getDelegations(alice);
        assertEq(aliceIds.length, 0);

        assertEq(chamber.getHolderDelegation(carol, EVICTED_TOKEN), CAROL_AMOUNT, "carol stake must remain");
        assertEq(chamber.getTotalHolderDelegations(carol), CAROL_AMOUNT);
        assertTrue(_containsDelegation(carol, EVICTED_TOKEN, CAROL_AMOUNT));

        uint256 carolShares = chamber.balanceOf(carol);
        vm.prank(carol);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.redeem(carolShares, carol, carol);

        vm.prank(carol);
        chamber.undelegate(EVICTED_TOKEN, CAROL_AMOUNT);
        vm.prank(carol);
        chamber.redeem(carolShares, carol, carol);
        assertEq(chamber.balanceOf(carol), 0);
    }

    /// @notice Mixed on-board and evicted delegations are both returned.
    function test_M03_GetDelegationsIncludesOnBoardAndEvicted() public {
        nft.mintWithTokenId(alice, 201);

        vm.startPrank(alice);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, alice);
        chamber.delegate(EVICTED_TOKEN, ALICE_AMOUNT);
        chamber.delegate(201, 200);
        vm.stopPrank();

        vm.startPrank(filler);
        token.approve(chamberAddress, 100000e18);
        chamber.deposit(100000e18, filler);
        // 2 alice nodes + 48 filler nodes = MAX_NODES; 55 remains tail
        for (uint256 i = 1; i <= 48; i++) {
            chamber.delegate(i, 52);
        }
        vm.stopPrank();

        _evictTail(51);

        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(alice);
        assertEq(tokenIds.length, 2);
        assertTrue(_containsDelegation(alice, EVICTED_TOKEN, ALICE_AMOUNT));
        assertTrue(_containsDelegation(alice, 201, 200));
        assertEq(amounts[0] + amounts[1], ALICE_AMOUNT + 200);
    }
}
