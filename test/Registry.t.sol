// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "lib/forge-std/src/Test.sol";

import { MultiProxy } from "src/proxy/MultiProxy.sol";
import { MultiBeacon } from "src/proxy/MultiBeacon.sol";
import { Chamber } from "src/Chamber.sol";
import { Registry } from "src/Registry.sol";

import { MockNFT } from "lib/contract-utils/src/MockNFT.sol";
import { MockERC20 } from "lib/contract-utils/src/MockERC20.sol";

import { IMultiProxy } from "src/interfaces/IMultiProxy.sol";
import { IMultiBeacon } from "src/interfaces/IMultiBeacon.sol";
import { IChamber } from "src/interfaces/IChamber.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { DeployRegistry } from "test/utils/DeployRegistry.sol";

contract RegistryTest is Test {
    MockERC20 mERC20;
    MockNFT mNFT;

    address registryProxyAddr;
    address chamberProxyAddr;
    
    address chamberV1Impl;
    address registryV1Impl;

    IMultiProxy registryProxy;
    IMultiProxy chamberProxy;

    IMultiBeacon registryBeacon;
    IMultiBeacon chamberBeacon;

    IChamber chamber;
    IRegistry registry;

    function setUp() public {

        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mNFT = new MockNFT("MockNFT", "mNFT", address(this));

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(mNFT), address(mERC20));

        (chamberV1Impl, registryV1Impl) = registryDeployer.getImplementations();

        registryProxy = IMultiProxy(registryProxyAddr);
        chamberProxy = IMultiProxy(chamberProxyAddr);

        registryBeacon = IMultiBeacon(registryProxy.getBeacon());
        chamberBeacon = IMultiBeacon(chamberProxy.getBeacon());

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

    function test_Registry_Beacon() public {
        Chamber newChamber = new Chamber();
        registry.setChamberBeacon(address(newChamber));
        assertEq(registry.chamberBeacon(), address(newChamber));

        // non owner should not be able to set version
        vm.prank(address(1));
        vm.expectRevert();
        registry.setChamberBeacon(address(chamber));
    }

    function test_Registry_proxy() public {
        Registry newRegistryImpl = new Registry();
        registryBeacon.upgradeImplementaion(address(newRegistryImpl));
        assertEq(registryProxy.getImplementation(), address(newRegistryImpl));
    }

    function test_Registry_initialize() public {
        Chamber chamberImpl = new Chamber();
        MultiBeacon chamberImplBeacon = new MultiBeacon(address(chamberImpl), msg.sender);
        Registry registryImpl = new Registry();
        MultiBeacon registryImplBeacon = new MultiBeacon(address(registryImpl), msg.sender);

        vm.expectRevert();
        registryImpl.initialize(address(chamberImplBeacon), address(1));

        address _owner = address(1);
        bytes memory data = abi.encodeWithSelector(Registry.initialize.selector, address(chamberImplBeacon), _owner);
        registryProxy = new MultiProxy(address(registryImplBeacon), data, _owner);
        assertEq(registryProxy.getImplementation(), address(registryImpl));
    }
}