// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


import { LoreumProxy } from "src/proxy/LoreumProxy.sol";    
import { LoreumBeacon } from "src/proxy/LoreumBeacon.sol";
import { Chamber } from "src/Chamber.sol";
import { Registry } from "src/Registry.sol";

contract DeployRegistry {

    Chamber chamberImpl;
    LoreumBeacon chamberBeacon;
    Registry registryImpl;
    LoreumBeacon registryBeacon;
    LoreumProxy loreumProxy;

    function deploy(address _owner) public returns (address) {
        chamberImpl = new Chamber();
        chamberBeacon = new LoreumBeacon(address(chamberImpl), _owner);

        registryImpl = new Registry();
        registryBeacon = new LoreumBeacon(address(registryImpl), _owner);

        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberBeacon), _owner);
        LoreumProxy registry = new LoreumProxy(address(registryBeacon), data, _owner);

        return address(registry);
    }

    function getImplementations() public view returns (address, address){
        return (address(chamberImpl), address(registryImpl));
    }
}