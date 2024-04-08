// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILoreumProxy {

    /// @dev Retrieves the address of the beacon contract.
    /// @return address of the beacon contract.    
    function getImplementation() external view returns (address);

    /// @notice Retrieves the address of the implementation contract.
    /// @return address of the implementation contract.
    function getBeacon() external returns (address);

}