// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {MockWallet} from "test/mock/MockWallet.sol";
import {WalletTypes} from "src/types/WalletTypes.sol";

/// @notice Symbolic verification of Wallet queue storage and lifecycle via Halmos
/// @dev Auth (`isDirector` / session keys) lives on Chamber; see ChamberSymTest.
contract WalletSymTest is Test, SymTest {
    MockWallet internal wallet;

    address internal constant TARGET = address(0x100);

    function setUp() public {
        wallet = new MockWallet();
    }

    /// @dev Submitted transaction stores keccak256(calldata) as dataHash
    function symbolicSubmitPreservesDataHash() public {
        uint256 tokenId = svm.createUint256("tokenId");
        uint256 value = svm.createUint256("value");
        bytes memory data = svm.createBytes(64, "calldata");
        vm.assume(tokenId > 0);

        wallet.submitTransaction(tokenId, TARGET, value, data);

        (,,,, bytes32 dataHash) = wallet.getTransaction(0);
        assertEq(dataHash, keccak256(data));
        assertEq(wallet.getTransactionCount(), 1);
    }

    /// @dev Submit auto-confirms the submitting tokenId and records the default deadline
    function symbolicSubmitAutoConfirmsAndSetsDeadline() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        vm.assume(tokenId > 0);

        uint256 submittedAt = block.timestamp;
        wallet.submitTransaction(tokenId, TARGET, 0, "");

        (bool executed, uint8 confirmations, address target,,) = wallet.getTransaction(0);
        assertFalse(executed);
        assertEq(confirmations, 1);
        assertEq(target, TARGET);
        assertTrue(wallet.getConfirmation(tokenId, 0));
        assertEq(wallet.getTransactionDeadline(0), submittedAt + WalletTypes.DEFAULT_TRANSACTION_MAX_AGE);
        assertFalse(wallet.isTransactionExpired(0));
        assertFalse(wallet.getCancelled(0));
    }

    /// @dev A second token can confirm; revoke restores the pre-confirm count
    function symbolicConfirmThenRevokeConservesCount() public {
        uint256 submitter = svm.createUint(16, "submitter");
        uint256 confirmer = svm.createUint(16, "confirmer");
        vm.assume(submitter > 0 && confirmer > 0 && submitter != confirmer);

        wallet.submitTransaction(submitter, TARGET, 0, "");
        wallet.confirmTransaction(confirmer, 0);

        (, uint8 afterConfirm,,,) = wallet.getTransaction(0);
        assertEq(afterConfirm, 2);
        assertTrue(wallet.getConfirmation(confirmer, 0));

        wallet.revokeConfirmation(confirmer, 0);

        (, uint8 afterRevoke,,,) = wallet.getTransaction(0);
        assertEq(afterRevoke, 1);
        assertFalse(wallet.getConfirmation(confirmer, 0));
        assertTrue(wallet.getConfirmation(submitter, 0));
    }

    /// @dev Mismatched calldata at execution time must revert
    function symbolicExecuteRejectsWrongCalldata() public {
        uint256 tokenId = svm.createUint256("tokenId");
        bytes memory data = svm.createBytes(32, "data");
        bytes memory wrongData = svm.createBytes(32, "wrongData");
        vm.assume(tokenId > 0);
        vm.assume(keccak256(data) != keccak256(wrongData));

        wallet.submitTransaction(tokenId, TARGET, 0, data);

        (bool success,) = address(wallet).call(abi.encodeCall(MockWallet.executeTransaction, (tokenId, 0, wrongData)));
        assertFalse(success);
    }

    /// @dev Cancelled nonces cannot execute
    function symbolicCancelBlocksExecute() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        bytes memory data = svm.createBytes(32, "data");
        vm.assume(tokenId > 0);

        wallet.submitTransaction(tokenId, TARGET, 0, data);
        wallet.recordCancelVote(tokenId, 0);
        wallet.cancelTransaction(0);

        assertTrue(wallet.getCancelled(0));
        assertTrue(wallet.getCancelConfirmation(tokenId, 0));

        (bool success,) = address(wallet).call(abi.encodeCall(MockWallet.executeTransaction, (tokenId, 0, data)));
        assertFalse(success);

        (bool executed,,,,) = wallet.getTransaction(0);
        assertFalse(executed);
    }

    /// @dev After a non-zero deadline, execute reverts and the nonce stays unexecuted
    function symbolicExpiredRejectsExecute() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        bytes memory data = svm.createBytes(32, "data");
        uint256 ttl = svm.createUint(16, "ttl");
        vm.assume(tokenId > 0);
        vm.assume(ttl > 0 && ttl < WalletTypes.DEFAULT_TRANSACTION_MAX_AGE);

        uint256 deadline = block.timestamp + ttl;
        wallet.submitTransaction(tokenId, TARGET, 0, data, deadline);

        vm.warp(deadline + 1);
        assertTrue(wallet.isTransactionExpired(0));

        (bool success,) = address(wallet).call(abi.encodeCall(MockWallet.executeTransaction, (tokenId, 0, data)));
        assertFalse(success);
        (bool executed,,,,) = wallet.getTransaction(0);
        assertFalse(executed);
    }
}
