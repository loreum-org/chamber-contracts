// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamberProxy } from "./interfaces/IChamberProxy.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MultiProxy is IChamberProxy, ERC1967Proxy {

    modifier onlyAdmin() {
        if(msg.sender != super._getAdmin()) revert notAdmin();
        _;
    }

    constructor(address _logic, bytes memory _data, address _admin) ERC1967Proxy(_logic, _data) {
        super._changeAdmin(_admin);
    }

    function getImplementation() public view returns (address) {
        return super._implementation();
    }

    function getAdmin() public view returns (address) {
        return super._getAdmin();
    }

    function changeAdmin(address newAdmin) public onlyAdmin {
        super._changeAdmin(newAdmin);
    }

    function upgradeTo(address newImplementation) public onlyAdmin {
        super._upgradeTo(newImplementation);
    }
}