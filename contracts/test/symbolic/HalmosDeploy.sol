// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {Chamber} from "src/Chamber.sol";
import {Registry} from "src/Registry.sol";

/**
 * @title HalmosDeploy
 * @notice Deploy Chamber/Registry implementations that Halmos can initialize.
 * @dev Halmos 0.3.3 cannot execute OpenZeppelin `TransparentUpgradeableProxy`
 *      construction: the proxy constructor hits `vm.deployCode(string)`, which
 *      is an unsupported cheatcode. These helpers zero the OZ 5 `Initializable`
 *      ERC-7201 slot so `initialize` can run on a freshly constructed
 *      implementation. That is **not** the production deploy path (Factory /
 *      Registry still use a proxy + ProxyAdmin). Upgrade / `getProxyAdmin`
 *      behavior is therefore out of scope for tests that use this helper.
 */
library HalmosDeploy {
    address private constant VM_ADDR = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDR);

    /// @dev `keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))`
    bytes32 internal constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function enableInitializer(address target) internal {
        vm.store(target, INITIALIZABLE_STORAGE, bytes32(0));
    }

    function chamber(address erc20, address erc721, uint256 seats, string memory name, string memory symbol)
        internal
        returns (Chamber c)
    {
        c = new Chamber();
        enableInitializer(address(c));
        c.initialize(erc20, erc721, seats, name, symbol);
    }

    function registry(address chamberImplementation, address admin) internal returns (Registry r) {
        r = new Registry();
        enableInitializer(address(r));
        r.initialize(chamberImplementation, admin);
    }
}
