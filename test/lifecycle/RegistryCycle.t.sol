// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "lib/forge-std/src/Test.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { DeployRegistry } from "test/utils/DeployRegistry.sol";
import { LoreumNFT } from "lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "lib/loreum-token/src/LoreumToken.sol";

contract RegistryCycle is Test {

    LoreumToken LORE;
    LoreumNFT Explorers;
    address chamberProxyAddr;
    address registryProxyAddr;

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
    }

    function test_registry_ownership() public {

        
    }

}