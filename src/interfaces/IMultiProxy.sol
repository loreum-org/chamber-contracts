// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IMultiProxy {
    function getImplementation() external view returns (address);

    function getBeacon() external returns (address);

}