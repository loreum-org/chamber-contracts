// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IFactory
 * @author xhad, Loreum DAO LLC
 * @notice Permissionless Chamber deploy path. Emits `ChamberCreated` for indexers / `getLogs`.
 * @dev Does not store an enumerable world directory. Parent/child tables stay on the
 *      deprecated {IRegistry} index for already-registered chambers.
 */
interface IFactory {
    /**
     * @notice Emitted when a new chamber proxy is deployed
     * @param chamber The new chamber proxy
     * @param asset Underlying ERC-20 (vault asset)
     * @param nft Membership ERC-721
     * @param seats Initial board seat count
     * @param name Share token name passed to `Chamber.initialize`
     * @param symbol Share token symbol passed to `Chamber.initialize`
     * @param creator `msg.sender` that called `createChamber`
     */
    event ChamberCreated(
        address indexed chamber,
        address indexed asset,
        address indexed nft,
        uint256 seats,
        string name,
        string symbol,
        address creator
    );

    /// @notice Emitted when the owner updates the Chamber implementation pointer used for future deploys
    event ChamberImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);

    /**
     * @notice Deploys a Chamber `TransparentUpgradeableProxy` and transfers its `ProxyAdmin` to the chamber.
     * @param erc20Token Standard ERC-20 vault asset
     * @param erc721Token Membership ERC-721
     * @param seats Initial board seats (1–20)
     * @param name Share token name
     * @param symbol Share token symbol
     * @return chamber The new chamber proxy
     */
    function createChamber(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol
    ) external returns (address payable chamber);

    /**
     * @notice Updates the Chamber implementation used for *future* `createChamber` calls only.
     * @dev Does not upgrade existing chamber proxies. Requires contract code and the
     *      existing Chamber `VERSION()` getter (PMN-M03 B).
     * @param newImplementation Chamber implementation (non-zero, has code, `VERSION()` returns bytes32)
     */
    function setImplementation(address newImplementation) external;

    /// @notice Chamber implementation used for the next `createChamber`
    function implementation() external view returns (address);
}
