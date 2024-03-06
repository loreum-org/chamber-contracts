// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IGuardManager - A contract interface managing transaction guards which perform pre and post-checks on transactions.
interface IGuardManager {
    /// @notice Emitted when the Transaction Guard is changed.
    event ChangedGuard(address indexed guard);

    /// @notice Set Transaction Guard `guard` for the chamber. Make sure you trust the guard.
    /// @param guard The address of the guard to be used or the 0 address to disable the guard
    function setGuard(address guard) external;
}