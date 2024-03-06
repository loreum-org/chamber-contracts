// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { IChamber } from "./IChamber.sol";

interface IGuard is IERC165 {
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