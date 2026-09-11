// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

contract DoubleDelegationTest is Test {
    Registry public registry;
    Chamber public implementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public attacker = makeAddr("attacker");
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        implementation = new Chamber();
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 5, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        token.mint(attacker, 100e18);
        nft.mintWithTokenId(attacker, 1);
        nft.mintWithTokenId(attacker, 2);
    }

    function test_Exploit_DoubleDelegation() public {
        vm.startPrank(attacker);
        token.approve(chamberAddress, 100e18);
        chamber.deposit(100e18, attacker);

        // Attacker delegates full share balance to ID 1
        uint256 shares = chamber.balanceOf(attacker);
        chamber.delegate(1, shares);

        // Delegate the same amount to ID 2 (using the SAME tokens)
        // This should fail because total delegation would exceed balance
        vm.expectRevert(IChamber.InsufficientChamberBalance.selector);
        chamber.delegate(2, shares);
        vm.stopPrank();

        // Verify total delegation is correct
        uint256 totalDelegated = chamber.getTotalHolderDelegations(attacker);
        uint256 balance = chamber.balanceOf(attacker);

        assertEq(totalDelegated, shares, "Delegated amount should NOT be inflated");
        assertEq(balance, shares, "Balance should remain equal to shares");
    }
}
