// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IChamber.sol";
import "../Chamber.sol";
import "../GuardManager.sol";

contract ReentrencyTransactionGuard is BaseGuard{
    bytes32 internal constant GUARD_STORAGE_SLOT = keccak256("reentrentry_guard.guard.struct");

    event RND();

    struct GuardValue{
        bool active;
    }

    fallback() external{}

    function getGuard() internal pure returns(GuardValue storage guard){
        bytes32 slot = GUARD_STORAGE_SLOT;
        assembly {
            guard.slot := slot
        }
    }

    function checkTransaction(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        uint8[5] memory,
        IChamber.State,
        bytes memory,
        address,
        uint8,
        uint8 
    )external{
        GuardValue storage guard = getGuard();
        require(!guard.active, "Reentrency detected");
        emit RND();
        guard.active = true;
    }

    function checkAfterExecution(bytes32, bool)external override{
        getGuard().active = false;
    }
}