// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import { MultiProxy } from "../../src/MultiProxy.sol";    
import { Beacon } from "../../src/Beacon.sol";
import { Chamber } from "../../src/Chamber.sol";
import { Registry } from "../../src/Registry.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";

contract DeployRegistry {

    Chamber chamberImpl;
    Beacon chamberBeacon;
    Registry registryImpl;
    Beacon registryBeacon;
    MultiProxy multiProxy;

    function deploy(address _owner) public returns (address) {
        chamberImpl = new Chamber();
        chamberBeacon = new Beacon(address(chamberImpl), _owner);

        registryImpl = new Registry();
        registryBeacon = new Beacon(address(registryImpl), _owner);

        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberBeacon), _owner);
        MultiProxy registry = new MultiProxy(address(registryBeacon), data, _owner);

        return address(registry);
    }

    function getImplementations() public view returns (address, address){
        return (address(chamberImpl), address(registryImpl));
    }
}