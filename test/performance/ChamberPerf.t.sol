// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Registry } from "../../src/Registry.sol";
import { Chamber } from "../../src/Chamber.sol";
import { IChamber } from "../../src/interfaces/IChamber.sol";

import { MockERC20 } from "../../lib/contract-utils/src/MockERC20.sol";
import { LoreumNFT } from "../../lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "../../lib/loreum-token/src/LoreumToken.sol";

contract ChamberPerfTest is Test {

    MockERC20 USD;
    LoreumToken LORE;
    LoreumNFT Explorers;
    IChamber chamber;

    address bones = address(1);
    address coconut = address(2);
    address hurricane = address(3);
    address jack = address(4);
    address danny = address(5);
    address shifty = address(6);
    address blackbeard = address(7);

    address[7] lorians = [bones,coconut,hurricane,jack,danny,shifty,blackbeard];

    function setUp() public {
        LORE = new LoreumToken(address(100), 1000000 ether, 10000000 ether);
        Explorers = new LoreumNFT(
            "Loreum Explorers",
            "LOREUM",
            "ipfs://QmcTBMUiaDQTCt3KT3JLadwKMcBGKTYtiuhopTUafo1h9L/",
            0.05 ether,
            500,
            10000,
            100,
            address(100)
        );

        Registry registry = new Registry(address(new Chamber()));
        address newChamber = registry.deploy(address(Explorers), address(LORE));
        chamber = IChamber(newChamber);
        USD = new MockERC20("US Dollar", "USD", address(chamber));

        vm.label(bones, "Bones");
        vm.label(coconut, "Coconut");
        vm.label(hurricane, "Hurricane");
        vm.label(jack, "Jack");
        vm.label(danny, "Danny");
        vm.label(shifty, "Shifty");
        vm.label(blackbeard, "Blackbeard");

    }

    // Test the performance of the promote function
    function test_Chamber_perf_promote_one(uint8 tokenId, uint256 amount) public {

        vm.assume(amount > 0);
        vm.assume(tokenId > 0);
        vm.startPrank(bones);
        deal(address(LORE), bones, amount);
        LORE.approve(address(chamber), amount);
        chamber.promote(amount, tokenId);
    }

    // Test the performance of the promote function with 10000 calls
    function test_Chamber_perf_promote_many(uint256 amount) public {

        vm.assume(amount > 0);

        uint8 runs = 50;
        for (uint8 i = 1; i <= runs; i++) {
            vm.startPrank(bones);
            deal(address(LORE), bones, amount);
            LORE.approve(address(chamber), amount);
            chamber.promote(amount, i);
        }
    }

}