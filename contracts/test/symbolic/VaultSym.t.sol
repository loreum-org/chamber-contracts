// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {VaultOffsetHarness} from "test/symbolic/VaultOffsetHarness.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

/// @notice Symbolic verification of Chamber ERC4626 vault invariants via Halmos
/// @dev Uses VaultOffsetHarness (Chamber._decimalsOffset = 3). Halmos cannot `new Chamber()`.
contract VaultSymTest is Test, SymTest {
    VaultOffsetHarness internal vault;
    MockERC20 internal token;

    address internal constant USER = address(0xBEEF);

    /// @dev Virtual share multiplier from Chamber._decimalsOffset() = 3
    uint256 internal constant SHARE_MULTIPLIER = 1000;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        vault = new VaultOffsetHarness(token);
    }

    /// @dev On an empty vault, previewDeposit scales assets by the decimals offset
    function symbolicPreviewDepositOnEmptyVault() public {
        uint256 amount = svm.createUint(96, "amount");
        vm.assume(amount > 0);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.previewDeposit(amount), amount * SHARE_MULTIPLIER);
    }

    /// @dev On an empty vault, deposit mints shares equal to assets times the decimals offset
    function symbolicEmptyVaultShareMultiplier() public {
        uint256 amount = svm.createUint(96, "amount");
        vm.assume(amount > 0);

        token.mint(USER, amount);
        vm.startPrank(USER);
        token.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, USER);
        vm.stopPrank();

        assertEq(shares, amount * SHARE_MULTIPLIER);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(USER), shares);
        assertEq(IERC20(address(token)).balanceOf(address(vault)), amount);
    }

    /// @dev Pause zeroes ERC-4626 max* and blocks deposit
    function symbolicPauseBlocksDeposit() public {
        uint256 amount = svm.createUint(64, "amount");
        vm.assume(amount > 0);

        vm.prank(address(vault));
        vault.pause();

        assertEq(vault.maxDeposit(USER), 0);
        assertEq(vault.maxMint(USER), 0);
        assertEq(vault.maxWithdraw(USER), 0);
        assertEq(vault.maxRedeem(USER), 0);

        token.mint(USER, amount);
        vm.startPrank(USER);
        token.approve(address(vault), amount);
        (bool success,) = address(vault).call(abi.encodeCall(vault.deposit, (amount, USER)));
        vm.stopPrank();
        assertFalse(success);
        assertEq(IERC20(address(token)).balanceOf(address(vault)), 0);
    }
}
