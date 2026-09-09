// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VmSafe} from "forge-std/Vm.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title MainnetDeployGuard
 * @notice Shared gates for the human-run mainnet Factory / createChamber scripts.
 * @dev Broadcast stays blocked unless `MAINNET_DEPLOY_UNBLOCKED=1` after #208 is
 *      accepted or fixed (and #209–#212 reviewed). Never calls Safe / transferOwnership.
 */
library MainnetDeployGuard {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Sepolia Factory — reference only. Must not be used as a chain-id-1 address.
    address internal constant SEPOLIA_FACTORY = 0x43aA92c8A26392f21F63cdA88B6BaB5031C40550;

    function revertIfBroadcastBlocked() internal view {
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast) || vm.isContext(VmSafe.ForgeContext.ScriptResume)) {
            if (!vm.envOr("MAINNET_DEPLOY_UNBLOCKED", false)) {
                revert(
                    "mainnet deploy blocked on #208 (and #209-#212) until accepted or fixed; set MAINNET_DEPLOY_UNBLOCKED=1 only after that. Never pass --broadcast to the rehearsal."
                );
            }
        }
    }

    function requireEthereumMainnet() internal view {
        if (block.chainid != 1) revert("not Ethereum mainnet (use --rpc-url / --fork-url for chain id 1)");
    }

    function refuseSepoliaFactory(address factory) internal pure {
        if (factory == SEPOLIA_FACTORY) revert("refusing Sepolia Factory on chain id 1");
    }
}
