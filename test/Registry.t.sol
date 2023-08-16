// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test (foundry-rs) imports.
import "../lib/forge-std/src/Test.sol";

// Loreum core contracts.
import { Registry } from "../src/Registry.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { IChamber } from "../src/IChamber.sol";
import { IRegistry } from "../src/IRegistry.sol";

contract RegistryTest is Test {
    MockERC20 mERC20;
    MockNFT mNFT;
    Registry registry;
    address chamber;

    function setUp() public {
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mNFT = new MockNFT("MockNFT", "mNFT", address(this));
        registry = new Registry(1);
    }

    function test_registry_create() public {
        chamber = registry.create(address(mERC20), address(mNFT), 10, 5);

        (address _chamber, address _gov, address _member, uint16 version) = registry.chambers(chamber);
        assertEq(_chamber, address(chamber));
        assertEq(_gov, address(mERC20));
        assertEq(_member, address(mNFT));
        assertEq(version, 1);
    }
}