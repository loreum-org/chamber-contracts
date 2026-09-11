// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    TransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {IChamber} from "./interfaces/IChamber.sol";
import {IFactory} from "./interfaces/IFactory.sol";

/**
 * @title Factory
 * @author xhad, Loreum DAO LLC
 * @notice Thin, non-proxy deployer for Chamber `TransparentUpgradeableProxy` instances.
 * @dev Mirrors {Registry}`createChamber` proxy construction (current impl, initialize,
 *      transfer `ProxyAdmin` to the chamber) but does **not** store an enumerable world
 *      list, asset index, or parent/child tables. Discover chambers via `ChamberCreated`
 *      logs (indexer or `getLogs`).
 *
 *      `setImplementation` is owner-gated and applies to future deploys only. Existing
 *      chambers upgrade through their own `ProxyAdmin`. Ownable (not
 *      `AccessControlDefaultAdminRules`) is enough for this non-upgradeable factory.
 */
contract Factory is Ownable, IFactory {
    /// @notice Chamber implementation used for the next `createChamber`
    address private _implementation;

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when seats value is invalid (0 or > 20)
    error InvalidSeats();

    /**
     * @param implementation_ Chamber implementation for new proxies (non-zero)
     * @param admin Owner that may call `setImplementation` (non-zero; Ownable reverts otherwise)
     */
    constructor(address implementation_, address admin) Ownable(admin) {
        if (implementation_ == address(0)) revert ZeroAddress();
        _implementation = implementation_;
    }

    /// @inheritdoc IFactory
    function implementation() external view returns (address) {
        return _implementation;
    }

    /**
     * @inheritdoc IFactory
     * @dev Same-address updates are a no-op (no event), matching {Registry}`setChamberImplementation`.
     */
    function setImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address previous = _implementation;
        if (previous == newImplementation) {
            return;
        }
        _implementation = newImplementation;
        emit ChamberImplementationUpdated(previous, newImplementation);
    }

    /**
     * @inheritdoc IFactory
     * @dev `erc20Token` must be a standard ERC-20. There is no factory allowlist; Chamber
     *      deposit/mint revert with `AssetAmountMismatch` if the vault receives less (or more)
     *      than the requested amount (fee-on-transfer). Rebasing/elastic tokens are unsupported
     *      and are not fully detectable at deposit time.
     */
    function createChamber(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol
    ) external returns (address payable chamber) {
        if (erc20Token == address(0) || erc721Token == address(0)) revert ZeroAddress();
        // `seats == 0` is the knowable create-time bound (PMN-M01 B). IERC721 has no standard
        // `totalSupply`; chambers are created before membership mint, so a supply cap is not
        // knowable onchain without an invented oracle.
        if (seats == 0 || seats > 20) revert InvalidSeats();
        if (_implementation == address(0)) revert ZeroAddress();

        bytes memory initData =
            abi.encodeWithSelector(IChamber.initialize.selector, erc20Token, erc721Token, seats, name, symbol);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(_implementation, address(this), initData);

        chamber = payable(address(proxy));

        _transferChamberAdmin(chamber);

        emit ChamberCreated(chamber, erc20Token, erc721Token, seats, name, symbol, msg.sender);
    }

    /**
     * @notice Transfers ProxyAdmin ownership to the chamber itself
     * @param chamber The chamber proxy address
     */
    function _transferChamberAdmin(address chamber) internal {
        address proxyAdminAddress = IChamber(chamber).getProxyAdmin();
        if (proxyAdminAddress == address(0)) revert ZeroAddress();

        ProxyAdmin proxyAdminInstance = ProxyAdmin(proxyAdminAddress);
        proxyAdminInstance.transferOwnership(chamber);
    }
}
