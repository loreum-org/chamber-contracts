// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";
import { ChamberProxy } from "../src/ChamberProxy.sol";
import "forge-std/console2.sol";

contract DeployRegistryProxy is Script {

    function run() external {

        vm.startBroadcast();
        Chamber chamberImpl = new Chamber();
        vm.stopBroadcast();
        console2.log("Chamber Implementation address: ", address(chamberImpl));

        vm.startBroadcast();

        Registry registryImpl = new Registry();
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberImpl), msg.sender);
        ChamberProxy registry = new ChamberProxy(address(registryImpl), data, msg.sender);
        vm.stopBroadcast();
        console2.log("Registry Proxy address: ", address(registry));
    }
}
