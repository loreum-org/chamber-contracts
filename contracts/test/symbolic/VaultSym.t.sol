// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {HalmosDeploy} from "test/symbolic/HalmosDeploy.sol";

/// @notice Symbolic verification of Chamber ERC4626 vault invariants via Halmos
/// @dev Avoids convertToAssets / previewRedeem paths that introduce nonlinear division and timeout solvers.
///      Initializes the implementation (HalmosDeploy); no proxy.
contract VaultSymTest is Test, SymTest {
    Chamber internal chamber;
    MockERC20 internal token;
    MockERC721 internal nft;

    address internal constant USER = address(0xBEEF);

    /// @dev Virtual share multiplier from Chamber._decimalsOffset() = 3
    uint256 internal constant SHARE_MULTIPLIER = 1000;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = HalmosDeploy.chamber(address(token), address(nft), 5, "vERC20", "Vault Token");
    }

    /// @dev On an empty vault, previewDeposit scales assets by the decimals offset
    function symbolicPreviewDepositOnEmptyVault() public {
        uint256 amount = svm.createUint(96, "amount");
        vm.assume(amount > 0);

        assertEq(chamber.totalAssets(), 0);
        assertEq(chamber.previewDeposit(amount), amount * SHARE_MULTIPLIER);
    }

    /// @dev On an empty vault, deposit mints shares equal to assets times the decimals offset
    function symbolicEmptyVaultShareMultiplier() public {
        uint256 amount = svm.createUint(96, "amount");
        vm.assume(amount > 0);

        token.mint(USER, amount);
        vm.startPrank(USER);
        token.approve(address(chamber), amount);
        uint256 shares = chamber.deposit(amount, USER);
        vm.stopPrank();

        assertEq(shares, amount * SHARE_MULTIPLIER);
        assertEq(chamber.totalAssets(), amount);
        assertEq(chamber.balanceOf(USER), shares);
        assertEq(IERC20(address(token)).balanceOf(address(chamber)), amount);
    }

    /// @dev Single-depositor deposit then full redeem returns the same asset amount (offset cancels)
    function symbolicSingleDepositorRedeemConservation() public {
        uint256 amount = svm.createUint(96, "amount");
        vm.assume(amount > 0);

        token.mint(USER, amount);
        vm.startPrank(USER);
        token.approve(address(chamber), amount);
        uint256 shares = chamber.deposit(amount, USER);
        uint256 assetsOut = chamber.redeem(shares, USER, USER);
        vm.stopPrank();

        assertEq(assetsOut, amount);
        assertEq(chamber.totalAssets(), 0);
        assertEq(chamber.balanceOf(USER), 0);
        assertEq(IERC20(address(token)).balanceOf(USER), amount);
        assertEq(IERC20(address(token)).balanceOf(address(chamber)), 0);
    }

    /// @dev Pause zeroes ERC-4626 max* and blocks deposit
    function symbolicPauseBlocksDeposit() public {
        uint256 amount = svm.createUint(64, "amount");
        vm.assume(amount > 0);

        vm.prank(address(chamber));
        chamber.pause();

        assertEq(chamber.maxDeposit(USER), 0);
        assertEq(chamber.maxMint(USER), 0);
        assertEq(chamber.maxWithdraw(USER), 0);
        assertEq(chamber.maxRedeem(USER), 0);

        token.mint(USER, amount);
        vm.startPrank(USER);
        token.approve(address(chamber), amount);
        (bool success,) = address(chamber).call(abi.encodeCall(chamber.deposit, (amount, USER)));
        vm.stopPrank();
        assertFalse(success);
        assertEq(IERC20(address(token)).balanceOf(address(chamber)), 0);
    }
}
