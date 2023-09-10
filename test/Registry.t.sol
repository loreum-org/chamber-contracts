// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";

import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";

contract RegistryTest is Test {
    MockERC20 mERC20;
    MockNFT mNFT;
    Registry registry;
    Chamber chamber;

    function setUp() public {
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mNFT = new MockNFT("MockNFT", "mNFT", address(this));
        chamber = new Chamber();
        chamber.version();
        
        registry = new Registry(address(chamber));
    }

    function test_registry_create() public {
        address newChamber = registry.deploy(address(mERC20), address(mNFT));

        (address _chamber, address _gov, address _member, string memory version) = registry.chambers(newChamber);
        assertEq(_chamber, newChamber);
        assertEq(_gov, address(mERC20));
        assertEq(_member, address(mNFT));
        assertEq(version, IChamber(newChamber).version());
    }
}