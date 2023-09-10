// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";
import "forge-std/console2.sol";

contract DeployRegistry is Script {

    function run() external {

        vm.startBroadcast();
        Chamber chamber = new Chamber();
        vm.stopBroadcast();
        console2.log("Chamber address: ", address(chamber));

        vm.startBroadcast();
        Registry registry = new Registry(address(chamber));
        vm.stopBroadcast();
        console2.log("Registry address: ", address(registry));
    }
}
