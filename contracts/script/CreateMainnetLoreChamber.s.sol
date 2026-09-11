// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "src/Factory.sol";
import {MainnetLoreHandoff} from "test/utils/MainnetLoreHandoff.sol";
import {MainnetDeployGuard} from "script/MainnetDeployGuard.sol";

/**
 * @title CreateMainnetLoreChamber
 * @notice Human-run `Factory.createChamber` for live LORE + membership NFT.
 *         Factory uses CREATE (no salt): Chamber address is unknown until this tx.
 *         Does **not** call `LORE.transferOwnership` (Safe / human-only).
 *
 * Requires `FACTORY` (the chain-id-1 Factory from the DeployMainnetFactory receipt).
 * Broadcast gated on `MAINNET_DEPLOY_UNBLOCKED=1`. See `docs/mainnet-verified-deploy.md`.
 */
contract CreateMainnetLoreChamber is Script {
    function run() external {
        MainnetDeployGuard.revertIfBroadcastBlocked();
        _selectMainnet();
        MainnetDeployGuard.requireEthereumMainnet();

        address factoryAddr = vm.envAddress("FACTORY");
        if (factoryAddr == address(0)) revert("FACTORY required");
        MainnetDeployGuard.refuseSepoliaFactory(factoryAddr);

        Factory factory = Factory(factoryAddr);
        if (factory.implementation() == address(0)) revert("Factory.implementation() is zero");

        vm.startBroadcast();
        address payable chamber = payable(
            factory.createChamber(
                MainnetLoreHandoff.LORE,
                MainnetLoreHandoff.MEMBERSHIP_NFT,
                MainnetLoreHandoff.SEATS,
                MainnetLoreHandoff.NAME,
                MainnetLoreHandoff.SYMBOL
            )
        );
        vm.stopBroadcast();

        console.log("========================================");
        console.log("CreateMainnetLoreChamber");
        console.log("========================================");
        console.log("Factory                ", factoryAddr);
        console.log("Chamber implementation ", factory.implementation());
        console.log("Chamber (proxy)        ", chamber);
        console.log("erc20 (LORE)           ", MainnetLoreHandoff.LORE);
        console.log("erc721 (membership)    ", MainnetLoreHandoff.MEMBERSHIP_NFT);
        console.log("seats                  ", MainnetLoreHandoff.SEATS);
        console.log("name                   ", MainnetLoreHandoff.NAME);
        console.log("symbol                 ", MainnetLoreHandoff.SYMBOL);
        console.log("========================================");
        console.log("Paste Chamber (proxy) into deployments/mainnet.txt from this receipt.");
        console.log("Safe transferOwnership of LORE is human-only. This script does not call it.");
    }

    function _selectMainnet() internal {
        if (block.chainid == 1) return;
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("ETH_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            revert("set MAINNET_RPC_URL or ETH_RPC_URL, or pass --fork-url / --rpc-url for chain id 1");
        }
        vm.createSelectFork(rpc);
    }
}
