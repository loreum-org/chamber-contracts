// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IWallet} from "src/interfaces/IWallet.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title M-04: Wallet execution quorum snapshot
 * @notice A transaction submitted under a higher quorum must not become
 *         executable solely because seats (and live `getQuorum()`) later decrease.
 * @dev Confirmations are not revalidated against the current director set (H-01).
 *      Cancel still uses live quorum (M-06).
 */
contract FindingM04QuorumSnapshotTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    address public admin = address(0x9);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public user4 = address(0x4);
    address public user5 = address(0x5);

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), 5, "vERC20", "Vault Token", admin);

        _setupDirector(user1, 1, 1 ether);
        _setupDirector(user2, 2, 1 ether);
        _setupDirector(user3, 3, 1 ether);
        _setupDirector(user4, 4, 1 ether);
        _setupDirector(user5, 5, 1 ether);
        vm.roll(block.number + 1);

        // 5 filled seats → reachable quorum = 1 + (5 * 51) / 100 = 3 (PMN-M01)
        assertEq(chamber.getSeats(), 5);
        assertEq(chamber.getQuorum(), 3);
    }

    function test_SeatDecreaseDoesNotMakeUnderQuorumTxExecutable() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x1234), 0, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        (, uint8 confirmations,,,) = chamber.getTransaction(0);
        assertEq(confirmations, 2, "two confirmations, below submit-time quorum of 3");
        assertEq(chamber.getTransactionRequiredQuorum(0), 3);

        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, 0, "");

        _decreaseSeatsTo(3);

        assertEq(chamber.getSeats(), 3);
        assertEq(chamber.getQuorum(), 2, "live quorum dropped");
        assertEq(chamber.getTransactionRequiredQuorum(0), 3, "submit snapshot unchanged");

        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, 0, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        bytes[] memory batchData = new bytes[](1);
        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeBatchTransactions(1, ids, batchData);
    }

    function test_TxBecomesExecutableAfterReachingSnapshottedQuorum() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x1234), 0, "");
        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        _decreaseSeatsTo(3);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed);
    }

    function test_TxSubmittedAfterSeatDecreaseUsesLiveQuorum() public {
        _decreaseSeatsTo(3);
        assertEq(chamber.getQuorum(), 2);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x1234), 0, "");
        assertEq(chamber.getTransactionRequiredQuorum(0), 2);

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed);
    }

    function test_GetTransactionRequiredQuorum_UnknownNonceReverts() public {
        vm.expectRevert(IWallet.TransactionDoesNotExist.selector);
        chamber.getTransactionRequiredQuorum(0);
    }

    function _decreaseSeatsTo(uint256 newSeats) internal {
        vm.prank(user1);
        chamber.updateSeats(1, newSeats);
        vm.prank(user2);
        chamber.updateSeats(2, newSeats);
        vm.prank(user3);
        chamber.updateSeats(3, newSeats);

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(user1);
        chamber.executeSeatsUpdate(1);
    }

    function _setupDirector(address user, uint256 tokenId, uint256 amount) internal {
        token.mint(user, amount);
        nft.mintWithTokenId(user, tokenId);

        vm.startPrank(user);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, 1);
        vm.stopPrank();
    }
}
