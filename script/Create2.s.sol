// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Script } from "lib/forge-std/src/Script.sol";
import { Registry } from "src/Registry.sol";
import { Chamber } from "src/Chamber.sol";
import { MultiBeacon } from "src/proxy/MultiBeacon.sol";
import { MultiProxy } from "src/proxy/MultiProxy.sol";
import { DeployProxy } from "script/utils/DeployProxy.sol";
import { console2 } from "lib/forge-std/src/console2.sol";

contract DeployCreate2 is Script {

    DeployProxy deployProxy = new DeployProxy();

    function run() external {

        // Deploy Chamber
        vm.startBroadcast();
        bytes32 chamberBeaconSalt = keccak256(abi.encodePacked(vm.envString("CHAMBER_BEACON_SALT")));
        Chamber chamberImpl = new Chamber();
        bytes memory chamberBeaconByteCode = abi.encodePacked(type(MultiBeacon).creationCode, abi.encode(address(chamberImpl), msg.sender));
        address chamberBeacon = deployProxy.deploy2(chamberBeaconByteCode, chamberBeaconSalt);

        console2.log("Chamber Implementation address: ", address(chamberImpl));
        console2.log("Chamber MultiBeacon address: ", chamberBeacon);

        bytes32 registryBeaconSalt = keccak256(abi.encodePacked(vm.envString("REGISTRY_BEACON_SALT")));
        Registry registryImpl = new Registry();
        bytes memory registryBeaconByteCode = abi.encodePacked(type(MultiBeacon).creationCode, abi.encode(address(registryImpl), msg.sender));
        address registryBeacon = deployProxy.deploy2(registryBeaconByteCode, registryBeaconSalt);
        vm.stopBroadcast();

        console2.log("Registry Implementation address: ", address(registryImpl));
        console2.log("Registry MultiBeacon address: ", registryBeacon);
    }
}
