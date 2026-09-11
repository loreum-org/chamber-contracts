// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

contract BoardDoSTest is Test {
    Registry public registry;
    Chamber public implementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public attacker = makeAddr("attacker");
    address public victim = makeAddr("victim");
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        implementation = new Chamber();
        chamberAddress = address(
            DeployChamber.deployViaFactory(
                address(token),
                address(nft),
                20, // Max seats usually, but board size limit is 100 nodes
                "Chamber Token",
                "CHMB",
                admin
            )
        );
        chamber = IChamber(chamberAddress);

        // Attacker gets some tokens
        token.mint(attacker, 1000e18); // Enough for 100 small delegations
        // Victim gets MORE tokens
        token.mint(victim, 1000000e18);
    }

    function test_Exploit_BoardDoS() public {
        vm.startPrank(attacker);
        token.approve(chamberAddress, 1000e18);
        chamber.deposit(1000e18, attacker);

        // Fill up the board with 50 nodes of 1 wei each (MAX_NODES)
        for (uint256 i = 1; i <= 50; i++) {
            nft.mintWithTokenId(attacker, i);
            chamber.delegate(i, 1);
        }
        vm.stopPrank();

        // Verify board is full
        assertEq(chamber.getSize(), 50, "Board should be full");

        // Victim tries to join with a massive stake
        vm.startPrank(victim);
        token.approve(chamberAddress, 1000000e18);
        chamber.deposit(1000000e18, victim);
        nft.mintWithTokenId(victim, 51);

        // This should SUCCEED now because we evict the lowest node
        chamber.delegate(51, 1000000e18);
        vm.stopPrank();

        // Verify victim is on the board
        (uint256[] memory topIds, uint256[] memory topAmounts) = chamber.getTop(1);
        assertEq(topIds[0], 51, "Victim should be top 1");
        assertEq(topAmounts[0], 1000000e18, "Victim amount should be correct");

        // Verify size is still 100
        assertEq(chamber.getSize(), 50, "Board size should stay at max");
    }
}
