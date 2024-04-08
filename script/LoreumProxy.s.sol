// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Script } from "lib/forge-std/src/Script.sol";
import { Registry } from "src/Registry.sol";
import { Chamber } from "src/Chamber.sol";
import { LoreumBeacon } from "src/proxy/LoreumBeacon.sol";
import { LoreumProxy } from "src/proxy/LoreumProxy.sol";
import { console2 } from "lib/forge-std/src/console2.sol";

contract DeployaLoreumProxy is Script {

    function run() external {

        vm.startBroadcast();
        Chamber chamberImpl = new Chamber();
        LoreumBeacon chamberBeacon = new LoreumBeacon(address(chamberImpl),msg.sender);
        vm.stopBroadcast();
        
        console2.log("Chamber Implementation address: ", address(chamberImpl));
        console2.log("Chamber LoreumBeacon address: ", address(chamberBeacon));

        vm.startBroadcast();
        Registry registryImpl = new Registry();
        LoreumBeacon registryBeacon = new LoreumBeacon(address(registryImpl),msg.sender);
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberBeacon), msg.sender);
        LoreumProxy registry = new LoreumProxy(address(registryBeacon), data, msg.sender);
        vm.stopBroadcast();

        console2.log("Registry Implementation address: ", address(registryImpl));
        console2.log("Registry Beacon address: ", address(registryBeacon));
        console2.log("Registry Proxy address: ", address(registry));
    }
}
