// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

interface IBeacon{
    function getImplementation() external returns(address);

    function getOwner() external returns(address);

    function changeOwner(address newOwner) external;

    function upgradeImplementaion(address newImplementation) external;
}