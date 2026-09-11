// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";

/// @dev #142: factory create leaves an empty board; creator seats after NFT + delegate + SEATING_DELAY.
contract FactoryBootstrapTest is Test {
    uint256 internal constant SEATS = 5;
    uint256 internal constant SEATING_DELAY = 1;

    Factory public factory;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public creator = makeAddr("creator");

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        Chamber implementation = new Chamber();
        factory = new Factory(address(implementation), admin);
    }

    function test_Factory_CreateChamber_EmptyBoardUntilCreatorSeats() public {
        vm.prank(creator);
        address chamberAddr = factory.createChamber(address(token), address(nft), SEATS, "Bootstrap", "BOOT");
        Chamber chamber = Chamber(payable(chamberAddr));

        assertEq(chamber.getDirectors().length, 0, "deploy must not seat anyone");
        (uint256[] memory topIds,) = chamber.getTop(SEATS);
        assertEq(topIds.length, 0, "board starts empty");
        assertEq(chamber.getQuorum(), 1, "empty board: reachable n=0 -> 1 + 0");

        uint256 tokenId = nft.mint(creator);
        assertEq(nft.ownerOf(tokenId), creator, "creator holds membership NFT");

        vm.prank(creator);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(tokenId, address(token), 0, "");

        token.mint(creator, 100e18);
        vm.startPrank(creator);
        token.approve(chamberAddr, 100e18);
        chamber.deposit(100e18, creator);
        chamber.delegate(tokenId, 100e18);
        vm.stopPrank();

        address[] memory directors = chamber.getDirectors();
        assertEq(directors.length, 1);
        assertEq(directors[0], creator);
        assertEq(chamber.getSeatedAt(tokenId), block.number + SEATING_DELAY, "H-02 seating delay");

        vm.prank(creator);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.submitTransaction(tokenId, address(token), 0, "");

        vm.roll(block.number + SEATING_DELAY);

        vm.prank(creator);
        chamber.submitTransaction(tokenId, address(token), 0, "");
        assertEq(chamber.getTransactionCount(), 1, "seated director can submit");
        assertEq(chamber.getQuorum(), 1, "one reachable director -> quorum 1 (PMN-M01)");
    }
}
