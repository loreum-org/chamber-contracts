// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test (foundry-rs) imports.
import "../../lib/forge-std/src/Test.sol";

// Loreum core contracts.
import { Chamber } from "../../src/Chamber.sol";
import { IChamber } from "../../src/IChamber.sol";

import { LoreumNFT } from "../../lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "../../lib/loreum-token/src/LoreumToken.sol";

contract ProposalTest is Test {

    LoreumToken LORE;
    LoreumNFT NFT;
    Chamber chamber;

    function setUp() public {
        LORE = new LoreumToken(address(100), 1000000 ether, 10000000 ether);
        NFT = new LoreumNFT(
            "Loreum Explorers",
            "LOREUM",
            "ipfs://QmcTBMUiaDQTCt3KT3JLadwKMcBGKTYtiuhopTUafo1h9L/",
            0.05 ether,
            500,
            10000,
            100,
            address(100)
        );

        chamber = new Chamber(address(NFT), address(LORE), 1, 1);
        vm.deal(address(chamber), 100 ether);
    }

    function test_Chamber_create() public {
    }

}