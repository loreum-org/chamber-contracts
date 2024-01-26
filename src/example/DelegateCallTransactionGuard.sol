// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "../interfaces/IChamber.sol";
import "../Chamber.sol";
import "../GuardManager.sol";

contract DelegateCallTransactionGuard is BaseGuard {
    address[] public allowedTargets;

    constructor (address[] memory targets){
        require(targets.length > 0, "At least one allowed target is required");
        allowedTargets = targets;
    }

    fallback() external{}

    function checkTransaction(
        address[] memory to,
        uint256[] memory,
        bytes[] memory,
        uint8[5] memory ,
        IChamber.State,
        bytes memory ,
        address,
        uint8,
        uint8
    ) external view{
        require(isAllowedTarget(to), "This call is restricted");
    }
    function checkAfterExecution(bytes32, bool)external view override{}

    function isAllowedTarget(address[] memory target) internal view returns (bool) {
        for (uint256 i = 0; i < allowedTargets.length; i++) {
            if (target[i] != allowedTargets[i]) {
                return false;
            }
        }
        return true;
    }
}