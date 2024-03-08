// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "lib/forge-std/src/Script.sol";
import { Registry } from "src/Registry.sol";
import { console2 } from "lib/forge-std/src/console2.sol";


contract DeployRegistry is Script {

    function run() external {
        vm.startBroadcast();
        Registry registryImpl = new Registry();
        vm.stopBroadcast();
        console2.log("Registry Implementation: ", address(registryImpl));
    }
}
