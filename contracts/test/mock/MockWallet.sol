// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Wallet} from "src/Wallet.sol";

contract MockWallet is Wallet {
    uint256 public pings;

    /// @notice Target for Wallet self-call liveness tests (L-04)
    function ping() external {
        pings += 1;
    }

    function submitTransaction(uint256 tokenId, address to, uint256 value, bytes memory data) public {
        _submitTransaction(tokenId, to, value, data);
    }

    function submitTransaction(uint256 tokenId, address to, uint256 value, bytes memory data, uint256 deadline)
        public
    {
        _submitTransaction(tokenId, to, value, data, deadline);
    }

    function confirmTransaction(uint256 tokenId, uint256 transactionId) public {
        _confirmTransaction(tokenId, transactionId);
    }

    function executeTransaction(uint256 tokenId, uint256 transactionId, bytes calldata data) public {
        _executeTransaction(tokenId, transactionId, data);
    }

    function revokeConfirmation(uint256 tokenId, uint256 transactionId) public {
        _revokeConfirmation(tokenId, transactionId);
    }

    function recordCancelVote(uint256 tokenId, uint256 nonce) public {
        _recordCancelVote(tokenId, nonce);
    }

    function cancelTransaction(uint256 nonce) public {
        _cancelTransaction(nonce);
    }

    /// @dev Test hook: simulate a pre-upgrade pending nonce whose deadline mapping is unset (`0`).
    function forceTransactionDeadline(uint256 nonce, uint256 deadline) public {
        _getWalletStorage().transactionDeadline[nonce] = deadline;
    }
}
