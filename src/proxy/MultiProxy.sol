// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IMultiProxy } from "../interfaces/IMultiProxy.sol";
import { BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

contract MultiProxy is IMultiProxy, BeaconProxy {

    constructor(address _beacon, bytes memory _data, address _admin) BeaconProxy(_beacon, _data) {
        super._changeAdmin(_admin);
    }

    function getBeacon() public view returns (address) {
        return super._beacon();
    }

    function getImplementation() public view returns (address) {
        return super._implementation();
    }
}