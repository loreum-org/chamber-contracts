// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IGuardManager } from "../interfaces/IGuardManager.sol";
import { SelfAuthorized } from "../proxy/SelfAuthorized.sol";
import { IGuard } from "../interfaces/IGuard.sol";

/// @title Guard Manager - A contract managing transaction guards which perform pre and post-checks on transactions.
contract GuardManager is SelfAuthorized, IGuardManager {
    // keccak256("guard_manager.guard.address")
    bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    
    /// @inheritdoc IGuardManager
    function setGuard(address guard) external authorized{
        bytes32 slot = GUARD_STORAGE_SLOT;
        // solhint-disable no-inline-assembly
        assembly {
            sstore(slot, guard)
        }
        emit ChangedGuard(guard);
    }

    /// @return guard The address of the guard
    function getGuard() internal view returns (address guard){
        bytes32 slot = GUARD_STORAGE_SLOT;
        // solhint-disable no-inline-assembly
        assembly {
            guard := sload(slot)
        }
    }
}