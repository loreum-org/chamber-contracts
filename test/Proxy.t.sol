// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";

import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { IMultiBeacon } from "../src/interfaces/IMultiBeacon.sol";
import { IMultiProxy } from "../src/interfaces/IMultiProxy.sol";
import { DeployRegistry } from "../test/utils/DeployRegistry.sol";

import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { ERC1967Proxy } from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyUpgradeTest is Test{

    MockERC20 mERC20;
    MockNFT mERC721;
    
    IRegistry registry;
    IChamber chamber;

    IMultiBeacon chamberBeacon;
    IMultiBeacon registryBeacon;

    IMultiProxy registryProxy;
    IMultiProxy chamberProxy;

    address chamberProxyAddr;
    address registryProxyAddr;

    address chamberV1Impl;
    address registryV1Impl;

    function setUp() public {
            
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mERC721 = new MockNFT("MockNFT", "mNFT", address(this));

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));

        (chamberV1Impl, registryV1Impl) = registryDeployer.getImplementations();
        
        chamberProxy = IMultiProxy(chamberProxyAddr);
        registryProxy = IMultiProxy(registryProxyAddr);

        registryBeacon = IMultiBeacon(registryProxy.getBeacon());
        chamberBeacon = IMultiBeacon(chamberProxy.getBeacon());

        chamber = IChamber(chamberProxyAddr);
        registry = IRegistry(registryProxyAddr);
    }

    function test_Proxy_upgrade() public {
        chamberProxy.getImplementation();
        mERC20.approve(address(chamberProxy), 1000);
        chamber.promote(1, 1);
        (uint256[] memory leaders, uint256[] memory amounts) = chamber.getLeaderboard();
        Chamber chamberV2 = new Chamber();

        chamberBeacon.upgradeImplementaion(address(chamberV2));
        (uint256[] memory newLeaders, uint256[] memory newAmounts) = chamber.getLeaderboard();
        assertEq(newLeaders[0], leaders[0]);
        assertEq(newAmounts[0], amounts[0]); 
        assertEq(chamberProxy.getImplementation(), address(chamberV2));
        IChamber(address(chamberProxy)).getLeaderboard();
    }

    function test_Proxy_access() public {
        Chamber chamberV2 = new Chamber();
        
        vm.expectRevert();
        chamberBeacon.changeOwner(address(0));

        vm.startPrank(address(1));
        vm.expectRevert();
        chamberBeacon.changeOwner(address(1));
        vm.stopPrank();

        chamberBeacon.changeOwner(address(1));
        assertEq(chamberBeacon.getOwner(), address(1));
        
        vm.expectRevert();
        chamberBeacon.upgradeImplementaion(address(chamberV2));
        chamberProxy.getImplementation();

        Chamber chamberV3 = new Chamber();
        vm.prank(address(1));
        chamberBeacon.upgradeImplementaion(address(chamberV3));
        assertEq(chamberProxy.getImplementation(), address(chamberV3));
    } 

    function test_AllProxyUpgrade() public {

        address chamber2ProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));
        address chamber3ProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));
        address chamber4ProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));
        address chamber5ProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));

        IMultiProxy chamber2Proxy = IMultiProxy(chamber2ProxyAddr);
        IMultiProxy chamber3Proxy = IMultiProxy(chamber3ProxyAddr);
        IMultiProxy chamber4Proxy = IMultiProxy(chamber4ProxyAddr);
        IMultiProxy chamber5Proxy = IMultiProxy(chamber5ProxyAddr);

        assertEq(chamberV1Impl, address(chamberProxy.getImplementation()));
        assertEq(chamberV1Impl, address(chamber2Proxy.getImplementation()));
        assertEq(chamberV1Impl, address(chamber3Proxy.getImplementation()));
        assertEq(chamberV1Impl, address(chamber4Proxy.getImplementation()));
        assertEq(chamberV1Impl, address(chamber5Proxy.getImplementation()));

        Chamber chamberV2Impl = new Chamber();

        chamberBeacon.upgradeImplementaion(address(chamberV2Impl));
        
       assertEq(address(chamberV2Impl), address(chamberProxy.getImplementation()));
       assertEq(address(chamberV2Impl), address(chamber2Proxy.getImplementation()));
       assertEq(address(chamberV2Impl), address(chamber3Proxy.getImplementation()));
       assertEq(address(chamberV2Impl), address(chamber4Proxy.getImplementation()));
       assertEq(address(chamberV2Impl), address(chamber5Proxy.getImplementation()));
    }
}