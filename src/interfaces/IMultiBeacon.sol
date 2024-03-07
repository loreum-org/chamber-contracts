// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

interface IMultiBeacon{

    /// @notice Returns the current implementation address.
    /// @return address of the current implementation.
    function getImplementation() external returns(address);

    /// @notice Returns the current owner address.
    /// @return address of the current owner.
    function getOwner() external returns(address);

    /// @notice Changes the owner of the contract.
    /// @param _newOwner The address of the new owner.
    function changeOwner(address _newOwner) external;

    /// @notice Upgrades the implementation to a new address.
    /// @param _newImplementation The address of the new implementation.
    function upgradeImplementaion(address _newImplementation) external;
}