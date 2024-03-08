// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1967Proxy } from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy {

    ERC1967Proxy public proxy;
    // use abi.encodeWithSignature for data
    function deploy(address implementation, bytes memory data ) public returns (address) {
        proxy = new ERC1967Proxy(implementation, data);
        return address(proxy);
    }

    function deploy2(bytes memory bytecode, bytes32 salt) public returns (address) {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        return addr;
    }
}
