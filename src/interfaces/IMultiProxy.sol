// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMultiProxy {

    function getImplementation() external view returns (address);

    function getAdmin() external view returns (address);

    function changeAdmin(address newAdmin) external;

    function upgradeTo(address newImplementation) external;

    error notAdmin();
}