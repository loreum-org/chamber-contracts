// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Script } from "lib/forge-std/src/Script.sol";
import { Registry } from "src/Registry.sol";
import { Chamber } from "src/Chamber.sol";
import { LoreumBeacon } from "src/proxy/LoreumBeacon.sol";
import { LoreumProxy } from "src/proxy/LoreumProxy.sol";
import { console2 } from "lib/forge-std/src/console2.sol";
import { TransparentUpgradeableProxy } from "src/Common.sol";

contract DeployLoreum is Script {

    function run() external {

        vm.startBroadcast();
        address chamberImpl = 0x0634d2d9d60fB527681821bbB224Dd0EaF8b69Fd;
        address teamMultiSig = 0x5d45A213B2B6259F0b3c116a8907B56AB5E22095;

        LoreumBeacon chamberBeacon = new LoreumBeacon(chamberImpl, teamMultiSig);
        
        console2.log("Chamber Implementation address: ", address(chamberImpl));
        console2.log("Chamber LoreumBeacon address: ", address(chamberBeacon));

        address registryImpl = 0xc2CBefB9593eA19d636C04b2B91fc78369eB3C26;

        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberBeacon), teamMultiSig);
        TransparentUpgradeableProxy registry = new TransparentUpgradeableProxy(registryImpl, teamMultiSig, data);
        vm.stopBroadcast();

        console2.log("Registry Implementation address: ", address(registryImpl));
        console2.log("Registry Proxy address: ", address(registry));
    }
}
