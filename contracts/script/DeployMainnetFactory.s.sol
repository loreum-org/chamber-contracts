// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MainnetLoreHandoff} from "test/utils/MainnetLoreHandoff.sol";
import {MainnetDeployGuard} from "script/MainnetDeployGuard.sol";

/**
 * @title DeployMainnetFactory
 * @notice Human-run Ethereum mainnet Factory + Chamber implementation (libs linked).
 *         Does **not** call `createChamber` or `LORE.transferOwnership`.
 *
 * Dry-run (no broadcast) from `contracts/`:
 *
 *   export MAINNET_RPC_URL=...
 *   forge script script/DeployMainnetFactory.s.sol:DeployMainnetFactory \
 *     --fork-url "$MAINNET_RPC_URL" -vvv
 *
 * Live broadcast is gated on `MAINNET_DEPLOY_UNBLOCKED=1` after #208 is accepted
 * or fixed. See `docs/mainnet-verified-deploy.md`. Dry-run addresses are not live.
 */
contract DeployMainnetFactory is Script {
    function run() external {
        MainnetDeployGuard.revertIfBroadcastBlocked();
        _selectMainnet();
        MainnetDeployGuard.requireEthereumMainnet();

        address admin = MainnetLoreHandoff.TEAM_SAFE;
        try vm.envAddress("ADMIN") returns (address envAdmin) {
            admin = envAdmin;
        } catch {}

        vm.startBroadcast();
        MainnetLoreHandoff.Deployment memory d = MainnetLoreHandoff.deployFactoryLinked(admin);
        vm.stopBroadcast();

        console.log("========================================");
        console.log("DeployMainnetFactory");
        console.log("========================================");
        console.log("ADMIN                  ", admin);
        console.log("BoardLib               ", d.boardLib);
        console.log("WalletLib              ", d.walletLib);
        console.log("Factory                ", address(d.factory));
        console.log("Chamber implementation ", d.chamberImplementation);
        console.log("Chamber (proxy)        ", d.chamber, "  (zero until createChamber)");
        console.log("========================================");
        console.log("createChamber: erc20=LORE erc721=membership seats=5 name='Chamber LORE' symbol=cLORE");
        console.log("Next: FACTORY=<addr> forge script script/CreateMainnetLoreChamber.s.sol:CreateMainnetLoreChamber");
        console.log("Safe transferOwnership is human-only. This script does not call it.");
        console.log("Paste addresses into deployments/mainnet.txt ONLY from a chain-id-1 broadcast receipt.");
        console.log("Do not copy Sepolia Factory 0x43aA92c8A26392f21F63cdA88B6BaB5031C40550.");
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
