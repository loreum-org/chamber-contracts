// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";

import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { IProxy } from "../src/interfaces/IProxy.sol";
import { DeployRegistry } from "../test/utils/DeployRegistry.sol";

import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { ERC1967Proxy } from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyUpgradeTest is Test {

    MockERC20 mERC20;
    MockNFT mERC721;
    
    IRegistry registry;
    IChamber chamber;

    IProxy registryProxy;
    IProxy chamberProxy;

    address chamberProxyAddr;
    address registryProxyAddr;

    function setUp() public {
            
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mERC721 = new MockNFT("MockNFT", "mNFT", address(this));

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(mERC721), address(mERC20));
        
        chamberProxy = IProxy(chamberProxyAddr);
        registryProxy = IProxy(registryProxyAddr);

        chamber = IChamber(chamberProxyAddr);
        registry = IRegistry(registryProxyAddr);
    }

    function test_Proxy_upgrade() public {
        chamberProxy.getImplementation();
        mERC20.approve(address(chamberProxy), 1000);
        chamber.promote(1, 1);
        (uint8[5] memory leaders, uint256[5] memory amounts) = chamber.getLeaderboard();
        Chamber chamberV2 = new Chamber();

        chamberProxy.upgradeTo(address(chamberV2));
        (uint8[5] memory newLeaders, uint256[5] memory newAmounts) = chamber.getLeaderboard();
        assertEq(newLeaders[0], leaders[0]);
        assertEq(newAmounts[0], amounts[0]); 
        assertEq(chamberProxy.getImplementation(), address(chamberV2));
        IChamber(address(chamberProxy)).getLeaderboard();
    }

    function test_Proxy_access() public {
        Chamber chamberV2 = new Chamber();
        
        vm.expectRevert();
        chamberProxy.changeAdmin(address(0));

        vm.startPrank(address(1));
        vm.expectRevert();
        chamberProxy.changeAdmin(address(1));
        vm.stopPrank();

        chamberProxy.changeAdmin(address(1));
        assertEq(chamberProxy.getAdmin(), address(1));
        
        vm.expectRevert();
        chamberProxy.upgradeTo(address(chamberV2));
        chamberProxy.getImplementation();

        Chamber chamberV3 = new Chamber();
        vm.prank(address(1));
        chamberProxy.upgradeTo(address(chamberV3));
        assertEq(chamberProxy.getImplementation(), address(chamberV3));
    } 
}