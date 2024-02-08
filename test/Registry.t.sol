// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { MultiProxy } from "../src/MultiProxy.sol";
import { Chamber } from "../src/Chamber.sol";
import { Registry } from "../src/Registry.sol";

import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";

import { IChamberProxy } from "../src/interfaces/IChamberProxy.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { DeployRegistry } from "../test/utils/DeployRegistry.sol";

contract RegistryTest is Test {
    MockERC20 mERC20;
    MockNFT mNFT;

    address registryProxyAddr;
    address chamberProxyAddr;
    
    IChamberProxy multiProxy;
    IChamberProxy chamberProxy;

    IChamber chamber;
    IRegistry registry;

    function setUp() public {

        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mNFT = new MockNFT("MockNFT", "mNFT", address(this));

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(mNFT), address(mERC20));

        multiProxy = IChamberProxy(registryProxyAddr);
        chamberProxy = IChamberProxy(chamberProxyAddr);

        chamber = IChamber(chamberProxyAddr);
        registry = IRegistry(registryProxyAddr);
    }

    function test_Registry_create() public {
        address newChamber = registry.deploy(address(mERC20), address(mNFT));
        (address _chamber, address _gov, address _member) = registry.chambers(1);
        assertEq(_chamber, newChamber);
        assertEq(_gov, address(mERC20));
        assertEq(_member, address(mNFT));
    }

    function test_Registry_getChambers() public {
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        address newChamber6 = registry.deploy(address(mERC20), address(mNFT));
        address newChamber7 = registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        registry.deploy(address(mERC20), address(mNFT));
        
        // test the skip and limit
        IRegistry.ChamberData[] memory chambers = registry.getChambers(2, 6);
        assertEq(chambers.length, 2);
        assertEq(chambers[0].chamber, address(newChamber6));
        assertEq(chambers[1].chamber, address(newChamber7));
    }

    function test_Registry_version() public {
        Chamber newChamber = new Chamber();
        registry.setChamberVersion(address(newChamber));
        assertEq(registry.chamberVersion(), address(newChamber));

        // non owner should not be able to set version
        vm.prank(address(1));
        vm.expectRevert();
        registry.setChamberVersion(address(chamber));
    }

    function test_Registry_proxy() public {
        Registry newRegistryImpl = new Registry();
        multiProxy.upgradeTo(address(newRegistryImpl));
        assertEq(multiProxy.getImplementation(), address(newRegistryImpl));
    }

    function test_Registry_initialize() public {
        Chamber chamberImpl = new Chamber();
        Registry registryImpl = new Registry();
        vm.expectRevert();
        registryImpl.initialize(address(chamberImpl), address(1));
        address _owner = address(1);
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberImpl), _owner);
        multiProxy = new MultiProxy(address(registryImpl), data, _owner);
        assertEq(multiProxy.getImplementation(), address(registryImpl));
        assertEq(multiProxy.getAdmin(), _owner);
    }
}