// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";
import { Beacon } from "../src/Beacon.sol";
import { MultiProxy } from "../src/MultiProxy.sol";
import "forge-std/console2.sol";

contract DeployMultiProxy is Script {

    function run() external {

        vm.startBroadcast();
        Chamber chamberImpl = new Chamber();
        Beacon chamberBeacon = new Beacon(address(chamberImpl),msg.sender);
        vm.stopBroadcast();
        
        console2.log("Chamber Implementation address: ", address(chamberImpl));
        console2.log("Chamber Beacon address: ", address(chamberBeacon));

        vm.startBroadcast();
        Registry registryImpl = new Registry();
        Beacon registryBeacon = new Beacon(address(registryImpl),msg.sender);
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberBeacon), msg.sender);
        MultiProxy registry = new MultiProxy(address(registryBeacon), data, msg.sender);
        vm.stopBroadcast();

        console2.log("Registry Implementation address: ", address(registryImpl));
        console2.log("Registry Beacon address: ", address(registryBeacon));
        console2.log("Registry Proxy address: ", address(registry));
    }
}
