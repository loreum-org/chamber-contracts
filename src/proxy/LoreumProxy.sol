// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.24;

import { ILoreumProxy } from "src/interfaces/ILoreumProxy.sol";
import { BeaconProxy} from "lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

/// @title LoreumProxy
/// @dev A proxy contract that allows changing the admin and retrieving the beacon and implementation addresses.
contract LoreumProxy is ILoreumProxy, BeaconProxy {

    /// @notice Constructor function for the LoreumProxy contract.
    /// @param _beacon The address of the beacon contract.
    /// @param _data The initialization data for the beacon proxy contract.
    /// @param _admin The address of the admin for the beacon proxy contract.
    constructor(address _beacon, bytes memory _data, address _admin) BeaconProxy(_beacon, _data) {
        super._changeAdmin(_admin);
    }

    /// @inheritdoc ILoreumProxy
    function getBeacon() public view returns (address) {
        return super._beacon();
    }

    /// @inheritdoc ILoreumProxy
    function getImplementation() public view returns (address) {
        return super._implementation();
    }
}