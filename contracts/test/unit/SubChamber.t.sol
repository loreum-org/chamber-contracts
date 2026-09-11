// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployRegistry} from "test/utils/DeployRegistry.sol";

/// @notice Parent/child index is historical leftover. Registry create is disabled (PMN-M03 A).
contract SubChamberTest is Test {
    Registry public registry;
    MockERC20 public rootAsset;
    MockERC721 public nft;
    address public admin = makeAddr("admin");

    function setUp() public {
        rootAsset = new MockERC20("Root Asset", "ROOT", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        registry = DeployRegistry.deploy(admin);
    }

    function test_SubChamber_Hierarchy() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(rootAsset), address(nft), 5, "Root Vault Token", "govROOT");

        assertEq(registry.getChamberCount(), 0);
        assertEq(registry.getChildChamberCount(address(rootAsset)), 0);
        assertEq(registry.getParentChamber(address(rootAsset)), address(0));
    }

    function test_DeepHierarchy() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(rootAsset), address(nft), 5, "L0", "L0");

        assertEq(registry.getAllChambers().length, 0);
        assertEq(registry.getChildChambers(address(rootAsset)).length, 0);
    }
}
