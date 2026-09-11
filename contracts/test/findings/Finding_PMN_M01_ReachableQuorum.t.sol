// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {Factory} from "src/Factory.sol";
import {Registry} from "src/Registry.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
import {DeployRegistry} from "test/utils/DeployRegistry.sol";

/**
 * @title PMN-M01: quorum uses reachable authorized directors (Solution A + C)
 * @notice Empty seats and burned tokenIds do not inflate the confirm/execute denominator.
 *         `recoverSeats` can lower configured seats when filled directors are below the
 *         configured-seat quorum. Create-time `seats == 0` is rejected; IERC721 supply is
 *         not a standard onchain signal (B supply bound skipped).
 */
contract FindingPMNM01ReachableQuorumTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    Factory public factory;
    Registry public registry;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public spendTarget = address(0x4);

    uint256 public constant SEATS = 3;
    uint256 public constant SEATING_DELAY = 1;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), SEATS, "vERC20", "VLT", address(0x9));

        Chamber implementation = new Chamber();
        factory = new Factory(address(implementation), address(0xA));
        registry = DeployRegistry.deploy(address(0xA));
    }

    function test_PMNM01_configuredQuorumMatchesFormula() public {
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        _seat(user3, 3, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        assertEq(chamber.getSeats(), 3);
        assertEq(chamber.getReachableDirectorCount(), 3);
        uint256 expected = 1 + (uint256(3) * 51) / 100;
        assertEq(chamber.getQuorum(), expected);
        assertEq(chamber.getQuorum(), 2);
    }

    function test_PMNM01_caseA_emptySeatsDoNotSetDenominator() public {
        _seat(user1, 1, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        assertEq(chamber.getSeats(), 3, "configured seats stay 3");
        assertEq(chamber.getReachableDirectorCount(), 1, "only one authorized director");
        assertEq(chamber.getQuorum(), 1 + (uint256(1) * 51) / 100, "quorum uses reachable, not empty slots");
        assertEq(chamber.getQuorum(), 1);

        uint256 configuredQuorum = 1 + (SEATS * 51) / 100;
        assertEq(configuredQuorum, 2, "configured-seat formula would have required 2");

        deal(address(chamber), 1 ether);
        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 1 ether, "");

        uint256 before = spendTarget.balance;
        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");
        assertEq(spendTarget.balance, before + 1 ether, "the live set can meet reachable quorum");
    }

    function test_PMNM01_caseA_burnedTokenLeavesDenominator() public {
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        _seat(user3, 3, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        assertEq(chamber.getQuorum(), 2, "three reachable directors");

        nft.burn(2);
        nft.burn(3);

        assertEq(chamber.getSeats(), 3, "configured seats unchanged");
        assertEq(chamber.getReachableDirectorCount(), 1, "burned ownerOf slots drop from denominator");
        assertEq(chamber.getQuorum(), 1, "reachable quorum, not the old configured 2");
        assertFalse(chamber.isTokenAuthorized(2, user2), "burned token cannot authorize");
        assertFalse(chamber.isTokenAuthorized(3, user3));

        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 0, "");
        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");
        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed, "remaining authorized director meets reachable quorum");
    }

    function test_PMNM01_caseB_createRejectsSeatsAboveSupply() public {
        // IERC721 has no standard totalSupply. Factory/Registry create before membership
        // mint (FactoryBootstrap). A seats-vs-supply bound is not knowable onchain without
        // an invented oracle — B's supply check is skipped. seats == 0 remains the
        // knowable create-time reject.
        vm.expectRevert(Factory.InvalidSeats.selector);
        factory.createChamber(address(token), address(nft), 0, "Zero", "Z");

        vm.expectRevert(Registry.InvalidSeats.selector);
        registry.createChamber(address(token), address(nft), 0, "Zero", "Z");

        address created = factory.createChamber(address(token), address(nft), 5, "EmptyNft", "E");
        assertEq(IChamber(created).getSeats(), 5, "create with unfilled membership still succeeds");
        assertEq(IChamber(created).getReachableDirectorCount(), 0);
        assertEq(IChamber(created).getQuorum(), 1, "empty board does not use configured seats as n");
    }

    function test_PMNM01_caseC_recoveryLowersSeats() public {
        _seat(user1, 1, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        assertEq(chamber.getSeats(), 3);
        assertEq(chamber.getReachableDirectorCount(), 1);
        uint256 configuredQuorum = 1 + (chamber.getSeats() * 51) / 100;
        assertEq(configuredQuorum, 2);
        assertLt(chamber.getReachableDirectorCount(), configuredQuorum);

        vm.expectEmit(true, false, false, true, address(chamber));
        emit IChamber.SeatsRecovered(1, 3, 1);
        vm.prank(user1);
        chamber.recoverSeats(1, 1);

        assertEq(chamber.getSeats(), 1, "recoverSeats lowered configured seats");
        assertEq(chamber.getQuorum(), 1, "remaining director meets quorum");

        deal(address(chamber), 1 ether);
        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 1 ether, "");
        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");
        assertEq(spendTarget.balance, 1 ether, "ordinary wallet spend still uses confirm/execute");

        bytes memory recoveryCall = abi.encodeCall(IChamber.recoverSeats, (1, 1));
        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitTransaction(1, address(chamber), 0, recoveryCall);

        Chamber filled = DeployChamber.deploy(address(token), address(nft), SEATS, "Full", "F", address(0xB));
        chamber = filled;
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        _seat(user3, 3, 100 ether);
        vm.roll(block.number + SEATING_DELAY + 1);
        assertEq(filled.getReachableDirectorCount(), 3);
        assertGe(filled.getReachableDirectorCount(), 1 + (filled.getSeats() * 51) / 100);
        assertTrue(block.number >= filled.getSeatedAt(1), "filled board directors are mature");

        vm.prank(user1);
        vm.expectRevert(IChamber.SeatRecoveryUnavailable.selector);
        filled.recoverSeats(1, 1);
    }

    function _seat(address user, uint256 tokenId, uint256 amount) internal {
        try nft.ownerOf(tokenId) returns (address owner) {
            if (owner != user) revert("token already minted to another owner");
        } catch {
            nft.mintWithTokenId(user, tokenId);
        }

        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, amount);
        vm.stopPrank();
    }
}
