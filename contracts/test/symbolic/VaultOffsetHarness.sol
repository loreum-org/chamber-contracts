// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

/**
 * @title VaultOffsetHarness
 * @notice Non-upgradeable ERC-4626 with Chamber's decimals offset and deposit delta check.
 * @dev Halmos cannot `new Chamber()` (Foundry emits `vm.deployCode`). This harness is
 *      the empty-vault / single-depositor stand-in for `Chamber._decimalsOffset` (3)
 *      and `Chamber._deposit` `AssetAmountMismatch`.
 */
contract VaultOffsetHarness is ERC20, ERC4626, Pausable {
    constructor(IERC20 asset_) ERC20("vERC20", "VTK") ERC4626(asset_) {}

    function pause() external {
        if (msg.sender != address(this)) revert IChamber.NotAuthorized();
        _pause();
    }

    function decimals() public view override(ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }

    function maxDeposit(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxRedeem(owner);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        IERC20 vaultAsset = IERC20(asset());
        uint256 balanceBefore = vaultAsset.balanceOf(address(this));
        super._deposit(caller, receiver, assets, shares);
        uint256 balanceAfter = vaultAsset.balanceOf(address(this));
        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != assets) {
            revert IChamber.AssetAmountMismatch();
        }
    }
}
