// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import { RegistryProxy } from "../../src/RegistryProxy.sol";    
import { Chamber } from "../../src/Chamber.sol";
import { Registry } from "../../src/Registry.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";

contract DeployRegistry {

    Chamber chamberImpl;
    Registry registryImpl;
    RegistryProxy proxy;

    function deploy(address _owner) public returns (address) {
        chamberImpl = new Chamber();
        registryImpl = new Registry();
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberImpl), _owner);
        RegistryProxy registry = new RegistryProxy(address(registryImpl), data, _owner);
        return address(registry);
    }
}