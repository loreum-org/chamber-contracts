// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy {

    ERC1967Proxy public proxy;
    // use abi.encodeWithSignature for data
    function deploy(address implementation, bytes memory data ) public returns (address) {
        proxy = new ERC1967Proxy(implementation, data);
        return address(proxy);
    }
}
