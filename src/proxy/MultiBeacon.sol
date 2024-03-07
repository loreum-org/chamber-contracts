// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IMultiBeacon } from "src/interfaces/IMultiBeacon.sol";
import { UpgradeableBeacon } from "lib/openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @title MultiBeacon
/// @dev A contract that acts as a proxy beacon for upgrading implementations and transferring ownership.
contract MultiBeacon is IMultiBeacon, UpgradeableBeacon {

    /// @notice Constructor function for the MultiBeacon contract.
    /// @param _newImplementation The address of the new implementation contract.
    /// @param _newOwner The address of the new owner of the MultiBeacon contract.
    constructor(address _newImplementation, address _newOwner) UpgradeableBeacon(_newImplementation) {
        super.transferOwnership(_newOwner);
    }

    /// @inheritdoc IMultiBeacon
    function getImplementation() public view returns(address) {
        return super.implementation();
    }

    /// @inheritdoc IMultiBeacon
    function getOwner() public view returns(address) {
        return super.owner();
    }

    /// @inheritdoc IMultiBeacon
    function changeOwner(address _newOwner)public onlyOwner {
        super.transferOwnership(_newOwner);
    }

    /// @inheritdoc IMultiBeacon
    function upgradeImplementaion(address _newImplementation) public {
        super.upgradeTo(_newImplementation);
    }
}