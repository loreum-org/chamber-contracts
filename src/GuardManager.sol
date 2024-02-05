// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IGuardManager.sol";
import "./SelfAuthorized.sol";

interface Guard is IERC165{
    /// @notice Checks the transaction details.
    /// @dev The function needs to implement transaction validation logic.
    /// @param to The addresses to which the transaction is intended.
    /// @param value The values of the transaction in Wei.
    /// @param data The transaction data.
    /// @param voters The voters eligible to vote .
    /// @param state The State of a proposal.
    /// @param signature The signatures of the transaction.
    /// @param executor The address of the message sender.
    /// @param proposalId The unique identifier of the approved proposal
    /// @param tokenId    The ID of the NFT that tokens will be promoted against
    function checkTransaction(
        address[] memory to,
        uint256[] memory value,
        bytes[] memory data,
        uint256[5] memory voters,
        IChamber.State state,
        bytes memory signature,
        address executor,
        uint256 proposalId,
        uint256 tokenId
    )external;
    
    /// @notice Checks after execution of transaction.
    /// @dev The function needs to implement a check after the execution of the transaction.
    /// @param txHash The hash of the transaction.
    /// @param success The status of the transaction execution.
    function checkAfterExecution(bytes32 txHash, bool success) external;
}

abstract contract BaseGuard is Guard {
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool){
        return 
        interfaceId == type(Guard).interfaceId || // 0x945b8148
        interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}

/// @title Guard Manager - A contract managing transaction guards which perform pre and post-checks on transactions.
contract GuardManager is SelfAuthorized, IGuardManager{
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