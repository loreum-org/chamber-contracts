// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";

/// @notice Minimal Ownable surface of mainnet LORE (single-step; no `pendingOwner`).
interface ILoreOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/**
 * @title MainnetLoreHandoff
 * @notice Shared mainnet constants + Factory/Chamber create path for the M1 fork rehearsal.
 * @dev Extends the Sepolia / Anvil deploy path (`script/DeployFactory.s.sol`):
 *      `new Chamber()` (Foundry auto-links `BoardLib` + `WalletLib`) then `new Factory(impl, admin)`
 *      then `Factory.createChamber(erc20, erc721, seats, name, symbol)`.
 *
 *      The Ownable account that should receive LORE is the **Chamber proxy** (`createChamber` return
 *      value). Wallet execution (`WalletLib.executeTransaction`) uses `address(this)` as `msg.sender`
 *      on the target, so `LORE.owner() == chamber` is the address that can later call `onlyOwner`.
 *
 *      `createChamber` uses CREATE (not CREATE2). The chamber address is
 *      `computeCreateAddress(factory, factoryNonce)` for that one proxy CREATE — no salt.
 */
library MainnetLoreHandoff {
    /// @dev Checksums match `script/Chamber.s.sol` (chainid == 1) and the repo README.
    address internal constant LORE = 0x7756D245527F5f8925A537be509BF54feb2FdC99;
    address internal constant MEMBERSHIP_NFT = 0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15;
    address internal constant TEAM_SAFE = 0x5d45A213B2B6259F0b3c116a8907B56AB5E22095;

    /// @dev Same seats / share token labels as `script/Chamber.s.sol` mainnet branch.
    uint256 internal constant SEATS = 5;
    string internal constant NAME = "Chamber LORE";
    string internal constant SYMBOL = "cLORE";

    struct Deployment {
        Factory factory;
        address chamberImplementation;
        address payable chamber;
    }

    /**
     * @notice Deploy Chamber implementation + Factory, then create a Chamber on the current chain.
     * @param factoryAdmin Factory Ownable admin (`setImplementation`). Sepolia used the team Safe.
     */
    function deployFactoryAndChamber(address factoryAdmin) internal returns (Deployment memory d) {
        Chamber implementation = new Chamber();
        d.chamberImplementation = address(implementation);
        d.factory = new Factory(address(implementation), factoryAdmin);
        d.chamber = payable(d.factory.createChamber(LORE, MEMBERSHIP_NFT, SEATS, NAME, SYMBOL));
    }
}
