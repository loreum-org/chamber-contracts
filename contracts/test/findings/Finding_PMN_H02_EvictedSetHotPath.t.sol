// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title PMN-H02: evictedTokenIds must not sit on the delegate/undelegate hot path
 * @notice After many unique tail evictions the global eviction index grows. Holders whose
 *         enumerable set already matches `totalHolderDelegations` must still undelegate
 *         and withdraw. This test does not include calldata recipes or an attack procedure.
 */
contract FindingPmnH02EvictedSetHotPathTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    address public alice = makeAddr("alice");
    address public filler = makeAddr("filler");

    uint256 internal constant ALICE_TOKEN = 1;
    uint256 internal constant ALICE_AMOUNT = 1_000 ether;
    uint256 internal constant EXTRA_EVICTIONS = 80;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), 5, "vERC20", "VLT", address(0x9));

        nft.mintWithTokenId(alice, ALICE_TOKEN);
        token.mint(alice, ALICE_AMOUNT);
        vm.startPrank(alice);
        token.approve(address(chamber), ALICE_AMOUNT);
        chamber.deposit(ALICE_AMOUNT, alice);
        chamber.delegate(ALICE_TOKEN, ALICE_AMOUNT);
        vm.stopPrank();
    }

    function test_PMN_H02_ConsistentHolderUndelegatesAfterManyEvictions() public {
        _fillBoardAndEvictUniqueTails(EXTRA_EVICTIONS);

        uint256 aliceShares = chamber.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        chamber.redeem(aliceShares, alice, alice);

        vm.prank(alice);
        chamber.undelegate(ALICE_TOKEN, ALICE_AMOUNT);

        assertEq(chamber.getTotalHolderDelegations(alice), 0);
        (uint256[] memory tokenIds,) = chamber.getDelegations(alice);
        assertEq(tokenIds.length, 0);

        vm.prank(alice);
        chamber.redeem(aliceShares, alice, alice);
        assertEq(chamber.balanceOf(alice), 0);
        assertGt(token.balanceOf(alice), 0);
    }

    function test_PMN_H02_DelegateGasDoesNotScaleWithEvictionIndex() public {
        token.mint(alice, 2 ether);
        vm.startPrank(alice);
        token.approve(address(chamber), 2 ether);
        chamber.deposit(2 ether, alice);
        vm.stopPrank();

        // Same live board size (50) in both samples. Only the eviction index grows.
        _fillBoardAndEvictUniqueTails(0);
        vm.prank(alice);
        uint256 gasAfterFew = _gasOfDelegate(1 ether);

        _evictUniqueTails(EXTRA_EVICTIONS, 51, 11);
        vm.prank(alice);
        uint256 gasAfterMany = _gasOfDelegate(1 ether);

        // Hot path must stay O(holder set). A complete eviction walk would grow with EXTRA_EVICTIONS.
        assertLt(gasAfterMany, gasAfterFew + 80_000, "delegate gas must not track evictedTokenIds length");
    }

    function _gasOfDelegate(uint256 amount) internal returns (uint256 gasUsed) {
        uint256 start = gasleft();
        chamber.delegate(ALICE_TOKEN, amount);
        gasUsed = start - gasleft();
    }

    function _fillBoardAndEvictUniqueTails(uint256 extraEvictions) internal {
        uint256 fillAmount = 10;
        uint256 needed = 49 + extraEvictions;
        uint256 depositAmount = fillAmount * needed + extraEvictions * extraEvictions + 1;

        token.mint(filler, depositAmount);
        vm.startPrank(filler);
        token.approve(address(chamber), depositAmount);
        chamber.deposit(depositAmount, filler);

        // Ranks 2..50 sit below alice (1_000 ether) and fill MAX_NODES.
        for (uint256 i = 2; i <= 50; i++) {
            nft.mintWithTokenId(filler, i);
            chamber.delegate(i, fillAmount);
        }
        assertEq(chamber.getSize(), 50);
        vm.stopPrank();

        _evictUniqueTails(extraEvictions, 51, fillAmount + 1);

        assertEq(chamber.getSize(), 50);
        (uint256 aliceNode,,,) = chamber.getMember(ALICE_TOKEN);
        assertEq(aliceNode, ALICE_TOKEN, "alice must remain on the live board");
    }

    function _evictUniqueTails(uint256 extraEvictions, uint256 firstTokenId, uint256 firstAmount) internal {
        if (extraEvictions == 0) return;

        uint256 depositAmount = extraEvictions * (firstAmount + extraEvictions);
        token.mint(filler, depositAmount);
        vm.startPrank(filler);
        token.approve(address(chamber), depositAmount);
        chamber.deposit(depositAmount, filler);
        for (uint256 i = 0; i < extraEvictions; i++) {
            uint256 tokenId = firstTokenId + i;
            nft.mintWithTokenId(filler, tokenId);
            chamber.delegate(tokenId, firstAmount + i);
        }
        vm.stopPrank();
    }
}
