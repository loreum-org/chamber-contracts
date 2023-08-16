// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";

contract DeployRegistry is Script {
    function run() external {


        vm.startBroadcast();

        new Registry(1);

        vm.stopBroadcast();
    }
}
