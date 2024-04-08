// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ILoreumBeacon } from "src/interfaces/ILoreumBeacon.sol";
import { UpgradeableBeacon } from "lib/openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @title LoreumBeacon
/// @dev A contract that acts as a proxy beacon for upgrading implementations and transferring ownership.
contract LoreumBeacon is ILoreumBeacon, UpgradeableBeacon {

    /// @notice Constructor function for the LoreumBeacon contract.
    /// @param _newImplementation The address of the new implementation contract.
    /// @param _newOwner The address of the new owner of the LoreumBeacon contract.
    constructor(address _newImplementation, address _newOwner) UpgradeableBeacon(_newImplementation) {
        super.transferOwnership(_newOwner);
    }

    /// @inheritdoc ILoreumBeacon
    function getImplementation() public view returns(address) {
        return super.implementation();
    }

    /// @inheritdoc ILoreumBeacon
    function getOwner() public view returns(address) {
        return super.owner();
    }

    /// @inheritdoc ILoreumBeacon
    function changeOwner(address _newOwner)public onlyOwner {
        super.transferOwnership(_newOwner);
    }

    /// @inheritdoc ILoreumBeacon
    function upgradeImplementaion(address _newImplementation) public {
        super.upgradeTo(_newImplementation);
    }
}