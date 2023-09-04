// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";
import { DeployProxy } from "./utils/DeployProxy.sol";

contract DeployRegistry is Script {

    function run() external {
        vm.startBroadcast();
        bytes memory proxyData = abi.encodeWithSignature("initialize()");
        Registry registry = new Registry();
        DeployProxy registryProxy = new DeployProxy();
        Registry(registryProxy.deploy(address(registry), proxyData));
        vm.stopBroadcast();
    }
}
