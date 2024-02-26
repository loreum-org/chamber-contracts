// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IMultiBeacon } from "../interfaces/IMultiBeacon.sol";
import { UpgradeableBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract MultiBeacon is IMultiBeacon, UpgradeableBeacon {

    constructor(address _newImplementation, address _newOwner) UpgradeableBeacon(_newImplementation) {
        super.transferOwnership(_newOwner);
    }

    function getImplementation() public view returns(address){
        return super.implementation();
    }
    
    function getOwner() public view returns(address){
        return super.owner();
    }

    function changeOwner(address _newOwner)public onlyOwner{
        super.transferOwnership(_newOwner);
    }

    function upgradeImplementaion(address _newImplementation) public {
        super.upgradeTo(_newImplementation);
    }
}