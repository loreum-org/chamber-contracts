// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Registry } from "../../src/Registry.sol";
import { Chamber } from "../../src/Chamber.sol";

import { IChamber } from "../../src/interfaces/IChamber.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";
import { IProxy } from "../../src/interfaces/IProxy.sol";

import { DeployRegistry } from "../utils/DeployRegistry.sol";

import { MockERC20 } from "../../lib/contract-utils/src/MockERC20.sol";
import { LoreumNFT } from "../../lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "../../lib/loreum-token/src/LoreumToken.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

contract ChamberSecTest is Test {

    MockERC20 USD;
    LoreumToken LORE;
    LoreumNFT Explorers;
    IChamber chamber;
    address registryProxyAddr;
    address chamberProxyAddr;

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

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(Explorers), address(LORE));
        chamber = IChamber(chamberProxyAddr);

        USD = new MockERC20("US Dollar", "USD", address(chamber));

        vm.label(bones, "Bones");
        vm.label(coconut, "Coconut");
        vm.label(hurricane, "Hurricane");
        vm.label(jack, "Jack");
        vm.label(danny, "Danny");
        vm.label(shifty, "Shifty");
        vm.label(blackbeard, "Blackbeard");

    }

    // Test if a wallet can demote a leader
    // by promoteing another leader and demote victim leader
    function test_Chamber_sec_demotionTheft() public {

        IProxy(registryProxyAddr).getImplementation();

        vm.startPrank(bones);
        deal(address(LORE), bones, 1_000_000);
        LORE.approve(address(chamber), 1_000_000);

        // promote tokenId 1
        chamber.promote(5,1);

        // promote another fnt to increase total amount delegated
        chamber.promote(7, 10);

        vm.stopPrank();

        // another user promotes tokenId 1
        vm.startPrank(hurricane);
        deal(address(LORE), hurricane, 1_000_000);
        LORE.approve(address(chamber), 1_000_000);
        chamber.promote(7, 1);
        vm.stopPrank();

        // bones should not be able to demote tokenId 1
        vm.startPrank(bones);
        vm.expectRevert();
        chamber.demote(12, 1);
        vm.stopPrank();
    }
}