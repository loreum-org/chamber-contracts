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
 * @dev Factory is the only Ethereum create path (PMN-M03 A). {Registry}`createChamber`
 *      reverts. Construction still: current impl, `initialize`, transfer `ProxyAdmin`
 *      to the chamber. Does **not** store an enumerable world list, asset index, or
 *      parent/child tables. Discover chambers via `ChamberCreated` logs (indexer or
 *      `getLogs`).
 *
 *      `setImplementation` is owner-gated, requires contract code, and probes the
 *      existing Chamber `VERSION()` getter (not a new selector). It applies to future
 *      deploys only. Existing chambers upgrade through their own `ProxyAdmin`. Ownable
 *      (not `AccessControlDefaultAdminRules`) is enough for this non-upgradeable factory.
 */
contract Factory is Ownable, IFactory {
    /// @notice Chamber implementation used for the next `createChamber`
    address private _implementation;

    /// @dev `Chamber.VERSION()` getter. Real implementation selector, not an added probe API.
    bytes4 private constant _VERSION_SELECTOR = bytes4(keccak256("VERSION()"));

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when seats value is invalid (0 or > 20)
    error InvalidSeats();

    /// @notice Thrown when `setImplementation` / constructor is given an EOA or empty code
    error NotContract();

    /// @notice Thrown when the address has code but `VERSION()` does not return `bytes32`
    error NotChamberImplementation();

    /**
     * @param implementation_ Chamber implementation for new proxies (non-zero contract with `VERSION()`)
     * @param admin Owner that may call `setImplementation` (non-zero; Ownable reverts otherwise)
     */
    constructor(address implementation_, address admin) Ownable(admin) {
        _implementation = _requireValidImplementation(implementation_);
    }

    /// @inheritdoc IFactory
    function implementation() external view returns (address) {
        return _implementation;
    }

    /**
     * @inheritdoc IFactory
     * @dev Same-address updates are a no-op (no event), matching {Registry}`setChamberImplementation`.
     *      Rejects EOAs / empty code, then probes `VERSION()`. `onlyOwner` runs first.
     */
    function setImplementation(address newImplementation) external onlyOwner {
        address next = _requireValidImplementation(newImplementation);
        address previous = _implementation;
        if (previous == next) {
            return;
        }
        _implementation = next;
        emit ChamberImplementationUpdated(previous, next);
    }

    /**
     * @notice Requires a deployed Chamber implementation (code + `VERSION()` getter).
     * @dev `VERSION()` is `bytes32 public constant` on {Chamber}. Success + 32-byte return
     *      is enough; the version string is not pinned so upgrades can bump it.
     */
    function _requireValidImplementation(address impl) internal view returns (address) {
        if (impl == address(0)) revert ZeroAddress();
        if (impl.code.length == 0) revert NotContract();
        (bool ok, bytes memory ret) = impl.staticcall(abi.encodeWithSelector(_VERSION_SELECTOR));
        if (!ok || ret.length != 32) revert NotChamberImplementation();
        return impl;
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
