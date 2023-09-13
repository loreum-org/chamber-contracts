// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Chamber } from "../src/Chamber.sol";
import { Registry } from "../src/Registry.sol";

import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";

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
        registry = new Registry(address(chamber));
    }

    function test_registry_create() public {
        address newChamber = registry.deploy(address(mERC20), address(mNFT));
        (address _chamber, address _gov, address _member) = registry.chambers(0);
        assertEq(_chamber, newChamber);
        assertEq(_gov, address(mERC20));
        assertEq(_member, address(mNFT));
    }

    function test_registry_getChambers() public {
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        address newChamber5 = registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));

        IRegistry.ChamberData[] memory chambers = registry.getChambers(5, 5);
        assertEq(chambers.length, 5);
        assertEq(chambers[0].chamber, address(newChamber5));
    }

    function test_registry_version() public {
        assertEq(registry.chamberVersion(), address(chamber));
        Chamber newChamber = new Chamber();
        registry.setChamberVersion(address(newChamber));
        assertEq(registry.chamberVersion(), address(newChamber));

        // non owner should not be able to set version
        vm.prank(address(1));
        vm.expectRevert();
        registry.setChamberVersion(address(chamber));
    }

}