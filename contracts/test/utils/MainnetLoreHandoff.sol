// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";
import {BoardLib} from "src/libraries/BoardLib.sol";
import {WalletLib} from "src/libraries/WalletLib.sol";

/// @notice Minimal Ownable surface of mainnet LORE (single-step; no `pendingOwner`).
interface ILoreOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/**
 * @title MainnetLoreHandoff
 * @notice Shared mainnet constants + Factory/Chamber create path for the M1 fork rehearsal.
 * @dev Extends `script/DeployFactory.s.sol`: `new Chamber()` then `new Factory(impl, admin)` then
 *      `Factory.createChamber`. Tests auto-link `BoardLib` + `WalletLib`. `forge script` dry-run
 *      cannot `new Chamber()` (unlinked) — use {deployFactoryAndChamberLinked}.
 *
 *      The Ownable account that should receive LORE is the **Chamber proxy** (`createChamber`
 *      return value). Wallet execution uses `address(this)` as `msg.sender` on the target.
 *
 *      `createChamber` uses CREATE (not CREATE2). No salt.
 */
library MainnetLoreHandoff {
    using stdJson for string;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Checksums match `script/Chamber.s.sol` (chainid == 1) and the repo README.
    address internal constant LORE = 0x7756D245527F5f8925A537be509BF54feb2FdC99;
    address internal constant MEMBERSHIP_NFT = 0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15;
    address internal constant TEAM_SAFE = 0x5d45A213B2B6259F0b3c116a8907B56AB5E22095;

    /// @dev Same seats / share token labels as `script/Chamber.s.sol` mainnet branch.
    uint256 internal constant SEATS = 5;
    string internal constant NAME = "Chamber LORE";
    string internal constant SYMBOL = "cLORE";

    /// @dev solc placeholders for `src/libraries/{Board,Wallet}Lib.sol:{Board,Wallet}Lib`.
    string internal constant BOARD_LIB_PLACEHOLDER = "__$562d0ceeeab35c7b4159c1d109bae4c407$__";
    string internal constant WALLET_LIB_PLACEHOLDER = "__$a34514150719d1f4c4dbc9690f221c78b7$__";

    struct Deployment {
        Factory factory;
        address chamberImplementation;
        address boardLib;
        address walletLib;
        address payable chamber;
    }

    /// @notice Test / broadcast path: Foundry auto-deploys and links BoardLib + WalletLib.
    function deployFactoryAndChamber(address factoryAdmin) internal returns (Deployment memory d) {
        Chamber implementation = new Chamber();
        d.chamberImplementation = address(implementation);
        d.factory = new Factory(address(implementation), factoryAdmin);
        d.chamber = payable(d.factory.createChamber(LORE, MEMBERSHIP_NFT, SEATS, NAME, SYMBOL));
    }

    /**
     * @notice Script dry-run path: deploy libs, link Chamber artifact, then Factory + create.
     * @dev `vm.deployCode("Chamber")` reverts when unlinked. Production `forge script --broadcast`
     *      (`DeployFactory.s.sol`) auto-deploys libs; this mirrors that pairing for a fork dry-run.
     */
    function deployFactoryAndChamberLinked(address factoryAdmin) internal returns (Deployment memory d) {
        d.boardLib = address(new BoardLib());
        d.walletLib = address(new WalletLib());
        d.chamberImplementation = _deployLinkedChamber(d.boardLib, d.walletLib);
        d.factory = new Factory(d.chamberImplementation, factoryAdmin);
        d.chamber = payable(d.factory.createChamber(LORE, MEMBERSHIP_NFT, SEATS, NAME, SYMBOL));
    }

    function _deployLinkedChamber(address boardLib, address walletLib) internal returns (address impl) {
        string memory artifact = vm.readFile("out/Chamber.sol/Chamber.json");
        string memory hexObj = artifact.readString(".bytecode.object");
        hexObj = _replaceAll(hexObj, BOARD_LIB_PLACEHOLDER, _addrHex(boardLib));
        hexObj = _replaceAll(hexObj, WALLET_LIB_PLACEHOLDER, _addrHex(walletLib));
        bytes memory bytecode = vm.parseBytes(hexObj);
        assembly {
            impl := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        if (impl == address(0) || impl.code.length == 0) {
            revert("linked Chamber deploy failed");
        }
    }

    function _addrHex(address account) internal pure returns (string memory) {
        bytes16 hexits = "0123456789abcdef";
        bytes20 data = bytes20(account);
        bytes memory out = new bytes(40);
        for (uint256 i; i < 20; ++i) {
            out[2 * i] = hexits[uint8(data[i] >> 4)];
            out[2 * i + 1] = hexits[uint8(data[i] & 0x0f)];
        }
        return string(out);
    }

    /// @dev In-place replace; needle and replacement must be the same length (40-char placeholders).
    function _replaceAll(string memory subject, string memory needle, string memory replacement)
        internal
        pure
        returns (string memory)
    {
        bytes memory s = bytes(subject);
        bytes memory n = bytes(needle);
        bytes memory r = bytes(replacement);
        if (n.length != r.length) revert("placeholder length mismatch");
        if (n.length == 0) revert("empty placeholder");

        uint256 replaced;
        for (uint256 i; i + n.length <= s.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < n.length; ++j) {
                if (s[i + j] != n[j]) {
                    match_ = false;
                    break;
                }
            }
            if (!match_) continue;
            for (uint256 j; j < r.length; ++j) {
                s[i + j] = r[j];
            }
            unchecked {
                i += n.length - 1;
                ++replaced;
            }
        }
        if (replaced == 0) revert("Chamber bytecode missing library placeholder");
        return string(s);
    }
}
