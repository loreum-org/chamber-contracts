// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    AccessControlUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {
    TransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {IChamber} from "./interfaces/IChamber.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";

/**
 * @title Registry
 * @author xhad, Loreum DAO LLC
 * @notice DEPRECATED as a world directory and create path. Historical index of chambers
 *         deployed through this contract, plus the original `createChamber` entrypoint.
 * @dev Prefer {Factory} for new deploys. Existing chambers stay valid. This contract is
 *      not migrated and must not be in-place-upgraded as part of the Factory cut.
 *      Enumerable getters (`getAllChambers`, `getChambersByAsset`, parent/child tables)
 *      remain for already-indexed addresses only.
 *
 *      Uses OpenZeppelin `TransparentUpgradeableProxy`; registry is proxy admin until
 *      `ProxyAdmin` ownership is transferred to each chamber.
 *
 *      Roles use OpenZeppelin 5.1.0 `AccessControlUpgradeable` (ERC-7201 namespace
 *      `openzeppelin.storage.AccessControl`). Registry application state is separately
 *      namespaced at `erc7201:loreum.ChamberRegistry`.
 *
 *      Upgrade constraint: a live Registry proxy initialized against non-upgradeable
 *      `AccessControl` stores `_roles` at sequential slot 0. This implementation reads
 *      roles from the ERC-7201 namespace, so those proxies must not be upgraded in-place
 *      without an explicit role migration. Prefer a new Registry proxy (fresh
 *      `initialize`) over copying slot-0 mappings. Chamber instances stay isolated:
 *      each owns its own `ProxyAdmin` after `createChamber`.
 *
 *      `AccessControlDefaultAdminRules` was not adopted: it changes
 *      `grantRole`/`revokeRole` for `DEFAULT_ADMIN_ROLE`, needs a product delay, and
 *      does not change TransparentUpgradeableProxy admin (still a separate EOA-owned
 *      `ProxyAdmin`).
 */
contract Registry is AccessControlUpgradeable, IRegistry {
    /// @notice Role for managing the registry configuration
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Maximum addresses a single registry getter may return
    /// @dev Unbounded copies of `chambers` / by-asset / child / asset indexes can OOG.
    ///      Paginated getters are the supported API; convenience getters return this first page.
    uint256 public constant MAX_PAGE_SIZE = 256;

    /**
     * @notice ERC-7201 namespaced storage layout for Registry
     * @dev Address fields (20 bytes each) cannot be packed together in the same 32-byte slot.
     *      Mappings and dynamic arrays each occupy a full slot regardless of value type.
     * @custom:storage-location erc7201:loreum.ChamberRegistry
     */
    struct RegistryStorage {
        address implementation;
        address proxyAdmin;
        address[] chambers;
        address[] assets;
        mapping(address => bool) isChamber;
        mapping(address => bool) isAsset;
        mapping(address => address[]) chambersByAsset;
        mapping(address => address) parentChamber;
        mapping(address => address[]) childChambers;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("erc7201:loreum.ChamberRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _REGISTRY_STORAGE_SLOT =
        0xf6315592a63ddf317bd8b41aa1ba894c04251b3cfbd8a95258342cd83f2a4600;

    function _getRegistryStorage() internal pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := _REGISTRY_STORAGE_SLOT
        }
    }

    /// EXPLICIT GETTERS for formerly-public state variables ///

    /// @notice The implementation contract for Chamber proxies
    function implementation() external view returns (address) {
        return _getRegistryStorage().implementation;
    }

    /**
     * @notice Address stored from `initialize(_implementation, admin)`: `admin` receives `DEFAULT_ADMIN_ROLE` / `ADMIN_ROLE`.
     * @dev Not the onchain `ProxyAdmin` contract address returned by `Chamber.getProxyAdmin`; naming is historical.
     */
    function proxyAdmin() external view returns (address) {
        return _getRegistryStorage().proxyAdmin;
    }

    /**
     * @notice Emitted when a new chamber is deployed
     * @param chamber The new chamber proxy (`payable`)
     * @param seats Initial board seat count
     * @param name Share token name passed to `Chamber.initialize`
     * @param symbol Share token symbol passed to `Chamber.initialize`
     * @param erc20Token Underlying ERC-20 (vault asset)
     * @param erc721Token Membership ERC-721
     */
    event ChamberCreated(
        address indexed chamber, uint256 seats, string name, string symbol, address erc20Token, address erc721Token
    );

    /// @notice Emitted when `ADMIN_ROLE` updates the Chamber implementation pointer used for `createChamber`
    event ChamberImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when seats value is invalid (0 or > 20)
    error InvalidSeats();

    /// @notice Disables initializers in the implementation contract
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Registry contract
     * @param _implementation The address of the Chamber implementation contract for proxies
     * @param admin The address that will have admin role and proxy admin
     */
    function initialize(address _implementation, address admin) external initializer {
        if (admin == address(0) || _implementation == address(0)) {
            revert ZeroAddress();
        }
        __AccessControl_init();
        RegistryStorage storage $ = _getRegistryStorage();
        $.implementation = _implementation;
        $.proxyAdmin = admin;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Updates the Chamber implementation address used for future `createChamber` deploys
     * @dev Does not upgrade existing chamber proxies; each chamber upgrades via its own `ProxyAdmin`.
     * @param newImplementation The new Chamber implementation contract (non-zero)
     */
    function setChamberImplementation(address newImplementation) external onlyRole(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
        RegistryStorage storage $ = _getRegistryStorage();
        address previous = $.implementation;
        if (previous == newImplementation) {
            return;
        }
        $.implementation = newImplementation;
        emit ChamberImplementationUpdated(previous, newImplementation);
    }

    /**
     * @notice Deploys a new Chamber instance using TransparentUpgradeableProxy
     * @dev `erc20Token` must be a standard ERC-20. There is no factory allowlist; Chamber
     *      deposit/mint revert with `AssetAmountMismatch` if the vault receives less (or more)
     *      than the requested amount (fee-on-transfer). Rebasing/elastic tokens are unsupported
     *      and are not fully detectable at deposit time.
     * @param erc20Token Standard ERC-20 vault asset (not fee-on-transfer or rebasing)
     * @param erc721Token The ERC721 token to be used for membership
     * @param seats The initial number of board seats
     * @param name The name of the chamber's ERC20 token
     * @param symbol The symbol of the chamber's ERC20 token
     * @return chamber The address of the newly deployed chamber proxy
     */
    function createChamber(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol
    ) external returns (address payable chamber) {
        RegistryStorage storage $ = _getRegistryStorage();

        if (erc20Token == address(0) || erc721Token == address(0)) revert ZeroAddress();
        // `seats == 0` is the knowable create-time bound (PMN-M01 B). IERC721 has no standard
        // `totalSupply`; chambers are created before membership mint, so a supply cap is not
        // knowable onchain without an invented oracle.
        if (seats == 0 || seats > 20) revert InvalidSeats();
        if ($.implementation == address(0)) revert ZeroAddress();

        bytes memory initData =
            abi.encodeWithSelector(IChamber.initialize.selector, erc20Token, erc721Token, seats, name, symbol);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy($.implementation, address(this), initData);

        chamber = payable(address(proxy));

        _transferChamberAdmin(chamber);

        $.chambers.push(chamber);
        $.isChamber[chamber] = true;

        if (!$.isAsset[erc20Token]) {
            $.isAsset[erc20Token] = true;
            $.assets.push(erc20Token);
        }
        $.chambersByAsset[erc20Token].push(chamber);

        if ($.isChamber[erc20Token]) {
            $.parentChamber[chamber] = erc20Token;
            $.childChambers[erc20Token].push(chamber);
        }

        emit ChamberCreated(chamber, seats, name, symbol, erc20Token, erc721Token);
    }

    /**
     * @notice Returns the first page of deployed chambers
     * @dev Capped at `MAX_PAGE_SIZE`. Use `getChambers(limit, skip)` to page the full index.
     * @return Array of chamber addresses
     */
    function getAllChambers() external view returns (address[] memory) {
        return _page(_getRegistryStorage().chambers, MAX_PAGE_SIZE, 0);
    }

    /**
     * @notice Returns the total number of deployed chambers
     * @return The number of chambers
     */
    function getChamberCount() external view returns (uint256) {
        return _getRegistryStorage().chambers.length;
    }

    /**
     * @notice Returns a subset of chambers for pagination
     * @param limit The maximum number of chambers to return (clamped to `MAX_PAGE_SIZE`)
     * @param skip The number of chambers to skip
     * @return Array of chamber addresses
     */
    function getChambers(uint256 limit, uint256 skip) external view returns (address[] memory) {
        return _page(_getRegistryStorage().chambers, limit, skip);
    }

    /**
     * @notice Checks if an address is a deployed chamber
     * @param chamber The address to check
     * @return bool True if the address is a deployed chamber
     */
    function isChamber(address chamber) external view returns (bool) {
        return _getRegistryStorage().isChamber[chamber];
    }

    /**
     * @notice Returns the first page of chambers for a given asset
     * @dev Capped at `MAX_PAGE_SIZE`. Use `getChambersByAsset(asset, limit, skip)` to page.
     * @param asset The asset address
     * @return Array of chamber addresses
     */
    function getChambersByAsset(address asset) external view returns (address[] memory) {
        return _page(_getRegistryStorage().chambersByAsset[asset], MAX_PAGE_SIZE, 0);
    }

    /**
     * @notice Returns a paginated list of chambers for a given asset
     * @param asset The asset address
     * @param limit The maximum number of chambers to return (clamped to `MAX_PAGE_SIZE`)
     * @param skip The number of chambers to skip
     * @return Array of chamber addresses
     */
    function getChambersByAsset(address asset, uint256 limit, uint256 skip) external view returns (address[] memory) {
        return _page(_getRegistryStorage().chambersByAsset[asset], limit, skip);
    }

    /**
     * @notice Returns the number of chambers indexed for a given asset
     * @param asset The asset address
     * @return The number of chambers using `asset`
     */
    function getChambersByAssetCount(address asset) external view returns (uint256) {
        return _getRegistryStorage().chambersByAsset[asset].length;
    }

    /**
     * @notice Returns the first page of unique assets (Organizations)
     * @dev Capped at `MAX_PAGE_SIZE`. Use `getAssets(limit, skip)` to page.
     * @return Array of asset addresses
     */
    function getAssets() external view returns (address[] memory) {
        return _page(_getRegistryStorage().assets, MAX_PAGE_SIZE, 0);
    }

    /**
     * @notice Returns a paginated list of unique assets
     * @param limit The maximum number of assets to return (clamped to `MAX_PAGE_SIZE`)
     * @param skip The number of assets to skip
     * @return Array of asset addresses
     */
    function getAssets(uint256 limit, uint256 skip) external view returns (address[] memory) {
        return _page(_getRegistryStorage().assets, limit, skip);
    }

    /**
     * @notice Returns the number of unique assets indexed by the registry
     * @return The number of assets
     */
    function getAssetCount() external view returns (uint256) {
        return _getRegistryStorage().assets.length;
    }

    /**
     * @notice Returns the parent chamber address for a given chamber
     * @param chamber The chamber address
     * @return The parent chamber address, or address(0) if it's a root chamber
     */
    function getParentChamber(address chamber) external view returns (address) {
        return _getRegistryStorage().parentChamber[chamber];
    }

    /**
     * @notice Returns the first page of child chambers for a given parent chamber
     * @dev Capped at `MAX_PAGE_SIZE`. Child links are permissionless index metadata
     *      (anyone may create a chamber whose asset is an existing chamber share token).
     *      Use `getChildChambers(chamber, limit, skip)` to page the full index.
     * @param chamber The parent chamber address
     * @return Array of child chamber addresses
     */
    function getChildChambers(address chamber) external view returns (address[] memory) {
        return _page(_getRegistryStorage().childChambers[chamber], MAX_PAGE_SIZE, 0);
    }

    /**
     * @notice Returns a paginated list of child chambers for a given parent chamber
     * @param chamber The parent chamber address
     * @param limit The maximum number of children to return (clamped to `MAX_PAGE_SIZE`)
     * @param skip The number of children to skip
     * @return Array of child chamber addresses
     */
    function getChildChambers(address chamber, uint256 limit, uint256 skip) external view returns (address[] memory) {
        return _page(_getRegistryStorage().childChambers[chamber], limit, skip);
    }

    /**
     * @notice Returns the number of child chambers indexed under a parent
     * @param chamber The parent chamber address
     * @return The number of child index entries
     */
    function getChildChamberCount(address chamber) external view returns (uint256) {
        return _getRegistryStorage().childChambers[chamber].length;
    }

    /**
     * @notice Copies a bounded slice from a storage address array
     * @dev `limit` of 0 returns an empty page. Limits above `MAX_PAGE_SIZE` are clamped.
     * @param items Source storage array
     * @param limit Requested page size
     * @param skip Number of entries to skip
     * @return result Memory copy of the selected slice
     */
    function _page(address[] storage items, uint256 limit, uint256 skip)
        internal
        view
        returns (address[] memory result)
    {
        uint256 total = items.length;
        if (skip >= total || limit == 0) {
            return new address[](0);
        }

        if (limit > MAX_PAGE_SIZE) {
            limit = MAX_PAGE_SIZE;
        }

        uint256 remaining = total - skip;
        uint256 count = remaining < limit ? remaining : limit;
        result = new address[](count);

        for (uint256 i = 0; i < count;) {
            result[i] = items[skip + i];
            unchecked {
                ++i;
            }
        }
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
