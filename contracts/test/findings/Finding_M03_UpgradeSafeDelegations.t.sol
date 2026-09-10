// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev Current Chamber plus storage helpers to simulate a live impl upgrade:
///      leftover `holderDelegation` / `totalHolderDelegations` with an empty enumerable set.
contract ChamberDelegationHarness is Chamber {
    using EnumerableSet for EnumerableSet.UintSet;

    function exposedClearHolderSet(address holder) external {
        EnumerableSet.UintSet storage s = _getChamberStorage().holderDelegatedTokenIds[holder];
        uint256[] memory vals = s.values();
        for (uint256 i = 0; i < vals.length; i++) {
            s.remove(vals[i]);
        }
    }

    /// @dev Writes leftover mapping amounts without touching the enumerable set.
    function exposedWriteHolderDelegation(address holder, uint256 tokenId, uint256 amount) external {
        ChamberStorage storage $ = _getChamberStorage();
        uint256 current = $.holderDelegation[holder][tokenId];
        if (amount >= current) {
            $.totalHolderDelegations[holder] += (amount - current);
        } else {
            $.totalHolderDelegations[holder] -= (current - amount);
        }
        $.holderDelegation[holder][tokenId] = amount;
    }

    function exposedBoardDelegate(uint256 tokenId, uint256 amount) external {
        _delegate(tokenId, amount, this.nft());
    }

    function exposedSetLength(address holder) external view returns (uint256) {
        return _getChamberStorage().holderDelegatedTokenIds[holder].length();
    }
}

/**
 * @title M-03 upgrade safety: leftover mappings stay discoverable after empty-set upgrade
 */
contract UpgradeSafeDelegationsTest is Test {
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public carol = makeAddr("carol");
    address public bob = makeAddr("bob");
    address public filler = makeAddr("filler");

    ChamberDelegationHarness public harness;
    IChamber public chamber;
    address public chamberAddress;

    uint256 internal constant LEFTOVER_TOKEN = 55;
    uint256 internal constant ALICE_AMOUNT = 50;
    uint256 internal constant CAROL_AMOUNT = 40;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");

        ChamberDelegationHarness impl = new ChamberDelegationHarness();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            admin,
            abi.encodeWithSelector(Chamber.initialize.selector, address(token), address(nft), 20, "Chamber Token", "CHMB")
        );

        chamberAddress = address(proxy);
        harness = ChamberDelegationHarness(payable(chamberAddress));
        chamber = IChamber(chamberAddress);

        token.mint(alice, 1000e18);
        token.mint(carol, 1000e18);
        token.mint(bob, 1000e18);
        token.mint(filler, 100000e18);

        nft.mintWithTokenId(alice, LEFTOVER_TOKEN);
        nft.mintWithTokenId(bob, 200);
        for (uint256 i = 1; i <= 49; i++) {
            nft.mintWithTokenId(filler, i);
        }
    }

    function _deposit(address user, uint256 assets) internal {
        vm.startPrank(user);
        token.approve(chamberAddress, assets);
        chamber.deposit(assets, user);
        vm.stopPrank();
    }

    /// @dev Pre-upgrade layout: mapping amounts + board node, enumerable set left empty.
    function _seedLegacyDelegation(address holder, uint256 tokenId, uint256 amount) internal {
        harness.exposedWriteHolderDelegation(holder, tokenId, amount);
        harness.exposedBoardDelegate(tokenId, amount);
        assertEq(harness.exposedSetLength(holder), 0, "set must stay empty (pre-upgrade)");
    }

    function _fillHighNodes(uint256 count, uint256 amount) internal {
        _deposit(filler, 100000e18);
        vm.startPrank(filler);
        for (uint256 i = 1; i <= count; i++) {
            chamber.delegate(i, amount);
        }
        vm.stopPrank();
    }

    function _evictLeftover(uint256 newAmount) internal {
        _deposit(bob, 1000e18);
        vm.prank(bob);
        chamber.delegate(200, newAmount);
        (uint256 tokenId,,,) = chamber.getMember(LEFTOVER_TOKEN);
        assertEq(tokenId, 0, "leftover token must be evicted");
    }

    function _upgradeToProduction() internal {
        Chamber prod = new Chamber();
        address proxyAdmin = chamber.getProxyAdmin();
        vm.prank(admin);
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(chamberAddress), address(prod), "");
    }

    function _contains(address holder, uint256 expectedTokenId, uint256 expectedAmount) internal view returns (bool) {
        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(holder);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == expectedTokenId && amounts[i] == expectedAmount) return true;
        }
        return false;
    }

    function test_Upgrade_EmptyMappingsStayEmpty() public view {
        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(alice);
        assertEq(tokenIds.length, 0);
        assertEq(amounts.length, 0);
        assertEq(chamber.getTotalHolderDelegations(alice), 0);
    }

    function test_Upgrade_EmptySet_GetDelegationsReturnsOnBoardLeftover() public {
        _deposit(alice, 1000e18);
        _seedLegacyDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getHolderDelegation(alice, LEFTOVER_TOKEN), ALICE_AMOUNT);
        assertEq(chamber.getTotalHolderDelegations(alice), ALICE_AMOUNT);
        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT));
    }

    function test_Upgrade_EmptySet_GetDelegationsReturnsEvictedLeftover() public {
        _deposit(alice, 1000e18);
        _seedLegacyDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);
        _fillHighNodes(49, 52);
        _evictLeftover(51);

        assertEq(harness.exposedSetLength(alice), 0, "eviction must not invent set entries");
        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT), "evicted leftover must stay listed");
    }

    function test_Upgrade_EmptySet_UndelegateThenWithdraw() public {
        _deposit(alice, 1000e18);
        _seedLegacyDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);
        _fillHighNodes(49, 52);
        _evictLeftover(51);

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.redeem(aliceShares, alice, alice);

        vm.prank(alice);
        chamber.undelegate(LEFTOVER_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getHolderDelegation(alice, LEFTOVER_TOKEN), 0);
        assertEq(chamber.getTotalHolderDelegations(alice), 0);
        (uint256[] memory tokenIds,) = chamber.getDelegations(alice);
        assertEq(tokenIds.length, 0);

        vm.prank(alice);
        chamber.redeem(aliceShares, alice, alice);
        assertEq(chamber.balanceOf(alice), 0);
        assertGt(token.balanceOf(alice), 0);
    }

    function test_Upgrade_EmptySet_UndelegateThenTransfer() public {
        _deposit(alice, 1000e18);
        _seedLegacyDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);
        _fillHighNodes(49, 52);
        _evictLeftover(51);

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.transfer(carol, aliceShares);

        vm.prank(alice);
        chamber.undelegate(LEFTOVER_TOKEN, ALICE_AMOUNT);

        vm.prank(alice);
        assertTrue(chamber.transfer(carol, aliceShares));
        assertEq(chamber.balanceOf(alice), 0);
        assertEq(chamber.balanceOf(carol), aliceShares);
    }

    function test_Upgrade_EmptySet_DoesNotWipeOtherHolder() public {
        _deposit(alice, 1000e18);
        _deposit(carol, 1000e18);
        harness.exposedWriteHolderDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);
        harness.exposedWriteHolderDelegation(carol, LEFTOVER_TOKEN, CAROL_AMOUNT);
        harness.exposedBoardDelegate(LEFTOVER_TOKEN, ALICE_AMOUNT + CAROL_AMOUNT);
        assertEq(harness.exposedSetLength(alice), 0);
        assertEq(harness.exposedSetLength(carol), 0);

        _fillHighNodes(49, 100);
        _evictLeftover(91);

        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT));
        assertTrue(_contains(carol, LEFTOVER_TOKEN, CAROL_AMOUNT));

        vm.prank(alice);
        chamber.undelegate(LEFTOVER_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getHolderDelegation(alice, LEFTOVER_TOKEN), 0);
        assertEq(chamber.getTotalHolderDelegations(alice), 0);
        (uint256[] memory aliceIds,) = chamber.getDelegations(alice);
        assertEq(aliceIds.length, 0);

        assertEq(chamber.getHolderDelegation(carol, LEFTOVER_TOKEN), CAROL_AMOUNT);
        assertEq(chamber.getTotalHolderDelegations(carol), CAROL_AMOUNT);
        assertTrue(_contains(carol, LEFTOVER_TOKEN, CAROL_AMOUNT));

        uint256 carolShares = chamber.balanceOf(carol);
        vm.prank(carol);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.redeem(carolShares, carol, carol);

        vm.prank(carol);
        chamber.undelegate(LEFTOVER_TOKEN, CAROL_AMOUNT);
        vm.prank(carol);
        chamber.redeem(carolShares, carol, carol);
        assertEq(chamber.balanceOf(carol), 0);
    }

    function test_Upgrade_ProductionImpl_LeftoverDiscoverableAfterUpgrade() public {
        _deposit(alice, 1000e18);
        _seedLegacyDelegation(alice, LEFTOVER_TOKEN, ALICE_AMOUNT);
        assertEq(harness.exposedSetLength(alice), 0);

        _upgradeToProduction();

        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT), "production impl must union leftover mappings");
        assertEq(chamber.getTotalHolderDelegations(alice), ALICE_AMOUNT);

        _fillHighNodes(49, 52);
        _evictLeftover(51);

        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT), "evicted leftover still listed after upgrade");

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        chamber.undelegate(LEFTOVER_TOKEN, ALICE_AMOUNT);
        vm.prank(alice);
        chamber.redeem(aliceShares, alice, alice);
        assertEq(chamber.balanceOf(alice), 0);
    }

    function test_Upgrade_ClearSetAfterDelegate_ThenUpgrade() public {
        _deposit(alice, 1000e18);
        vm.prank(alice);
        chamber.delegate(LEFTOVER_TOKEN, ALICE_AMOUNT);
        assertGt(harness.exposedSetLength(alice), 0);

        harness.exposedClearHolderSet(alice);
        assertEq(harness.exposedSetLength(alice), 0);
        assertEq(chamber.getHolderDelegation(alice, LEFTOVER_TOKEN), ALICE_AMOUNT);

        _upgradeToProduction();

        assertTrue(_contains(alice, LEFTOVER_TOKEN, ALICE_AMOUNT));

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        chamber.undelegate(LEFTOVER_TOKEN, ALICE_AMOUNT);
        vm.prank(alice);
        bool sent = chamber.transfer(carol, aliceShares);
        assertTrue(sent);
    }
}
