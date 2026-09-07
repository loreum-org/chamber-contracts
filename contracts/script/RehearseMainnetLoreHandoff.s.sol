// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ILoreOwnable, MainnetLoreHandoff} from "test/utils/MainnetLoreHandoff.sol";

/**
 * @title RehearseMainnetLoreHandoff
 * @notice Fork-only dry run of M1: Factory + Chamber on Ethereum mainnet, then Safe → Chamber
 *         `LORE.transferOwnership`. Same create args as `script/Chamber.s.sol` (chainid 1).
 *
 * Run from `contracts/` (do **not** pass `--broadcast`):
 *
 *   export MAINNET_RPC_URL=...          # or ETH_RPC_URL
 *   forge script script/RehearseMainnetLoreHandoff.s.sol:RehearseMainnetLoreHandoff \
 *     --fork-url $MAINNET_RPC_URL -vvv
 *
 * Success: logs Factory / impl / Chamber, and `LORE.owner() == chamber`.
 * See `docs/mainnet-lore-handoff-rehearsal.md`.
 */
contract RehearseMainnetLoreHandoff is Script {
    function run() external {
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast) || vm.isContext(VmSafe.ForgeContext.ScriptResume)) {
            revert("fork-only rehearsal: omit --broadcast (never send this to live mainnet)");
        }

        if (block.chainid != 1) {
            string memory rpc = _rpcUrl();
            if (bytes(rpc).length == 0) {
                revert("set MAINNET_RPC_URL or ETH_RPC_URL, or pass --fork-url");
            }
            vm.createSelectFork(rpc);
        }
        if (block.chainid != 1) revert("not an Ethereum mainnet fork");

        ILoreOwnable lore = ILoreOwnable(MainnetLoreHandoff.LORE);
        console.log("LORE                   ", MainnetLoreHandoff.LORE);
        console.log("Membership NFT         ", MainnetLoreHandoff.MEMBERSHIP_NFT);
        console.log("Team Safe              ", MainnetLoreHandoff.TEAM_SAFE);
        console.log("LORE.owner() before    ", lore.owner());
        if (lore.owner() != MainnetLoreHandoff.TEAM_SAFE) revert("unexpected LORE owner");

        MainnetLoreHandoff.Deployment memory d =
            MainnetLoreHandoff.deployFactoryAndChamber(MainnetLoreHandoff.TEAM_SAFE);

        vm.deal(MainnetLoreHandoff.TEAM_SAFE, 1 ether);
        vm.prank(MainnetLoreHandoff.TEAM_SAFE);
        lore.transferOwnership(d.chamber);

        if (lore.owner() != d.chamber) revert("LORE.owner() did not flip to Chamber");

        console.log("========================================");
        console.log("RehearseMainnetLoreHandoff");
        console.log("========================================");
        console.log("Factory                ", address(d.factory));
        console.log("Chamber implementation ", d.chamberImplementation);
        console.log("Chamber (LORE owner)   ", d.chamber);
        console.log("LORE.owner() after     ", lore.owner());
        console.log("========================================");
    }

    function _rpcUrl() internal view returns (string memory) {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length != 0) return rpc;
        return vm.envOr("ETH_RPC_URL", string(""));
    }
}
