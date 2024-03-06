// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

interface IMultiBeacon{
    function getImplementation() external returns(address);

    function getOwner() external returns(address);

    function changeOwner(address newOwner) external;

    function upgradeImplementaion(address newImplementation) external;
}