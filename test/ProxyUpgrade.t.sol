// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";

import { IChamber } from "../src/interfaces/IChamber.sol";
import { IProxyChamber } from "../src/interfaces/IProxyChamber.sol";

import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { ERC1967Proxy } from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyUpgradeTest is Test {

    Registry registry;
    IProxyChamber proxyChamber;
    MockERC20 mERC20;
    MockNFT mERC721;
    Chamber chamberImpl;

    function setUp() public {
            
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mERC721 = new MockNFT("MockNFT", "mNFT", address(this));

        chamberImpl = new Chamber();
        registry = new Registry(address(chamberImpl));
        proxyChamber = IProxyChamber(registry.deploy(address(mERC721), address(mERC20)));
    }

    function test_proxy_upgrade() public {
        proxyChamber.getImplementation();
        mERC20.approve(address(proxyChamber), 1000);
        IChamber(address(proxyChamber)).promote(1, 1);
        (uint8[5] memory leaders, uint256[5] memory amounts) = IChamber(address(proxyChamber)).getLeaderboard();
        Chamber chamberV2 = new Chamber();

        proxyChamber.upgradeTo(address(chamberV2));
        (uint8[5] memory newLeaders, uint256[5] memory newAmounts) = IChamber(address(proxyChamber)).getLeaderboard();
        assertEq(newLeaders[0], leaders[0]);
        assertEq(newAmounts[0], amounts[0]); 
        assertEq(proxyChamber.getImplementation(), address(chamberV2));
        IChamber(address(proxyChamber)).getLeaderboard();
    }

    function test_proxy_upgrade_access() public {
        Chamber chamberV2 = new Chamber();
        
        vm.expectRevert();
        proxyChamber.changeAdmin(address(0));

        vm.startPrank(address(1));
        vm.expectRevert();
        proxyChamber.changeAdmin(address(1));
        vm.stopPrank();

        proxyChamber.changeAdmin(address(1));
        assertEq(proxyChamber.getAdmin(), address(1));
        
        vm.expectRevert();
        proxyChamber.upgradeTo(address(chamberV2));
        proxyChamber.getImplementation();

        Chamber chamberV3 = new Chamber();
        vm.prank(address(1));
        proxyChamber.upgradeTo(address(chamberV3));
        assertEq(proxyChamber.getImplementation(), address(chamberV3));
    }
}