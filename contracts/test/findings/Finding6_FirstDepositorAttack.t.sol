// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/**
 * @title Finding 6: ERC4626 First Depositor / Donation Attack [HIGH] — FIXED
 * @notice Verifies that _decimalsOffset() = 3 prevents the inflation attack.
 *         With 1000 virtual shares, the donation attack becomes economically infeasible.
 */
contract FirstDepositorAttackTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public attacker = makeAddr("attacker");
    address public victim = makeAddr("victim");
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 3, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        token.mint(attacker, 10001);
        token.mint(victim, 5000);
    }

    /**
     * @notice FIXED: With _decimalsOffset() = 3, the victim now receives
     *         a meaningful number of shares after the attacker's donation.
     */
    function test_Fixed_FirstDepositorInflationPrevented() public {
        // Step 1: Attacker deposits 1 wei
        vm.startPrank(attacker);
        token.approve(chamberAddress, type(uint256).max);
        chamber.deposit(1, attacker);

        uint256 attackerShares = chamber.balanceOf(attacker);
        // With offset=3, attacker gets 1 * 1000 = 1000 shares (virtual shares)
        assertEq(attackerShares, 1000, "Attacker gets 1000 shares (virtual offset)");

        // Step 2: Attacker donates 10000 wei directly to the vault
        token.transfer(chamberAddress, 10000);
        vm.stopPrank();

        // Step 3: Victim deposits 5000 tokens
        vm.startPrank(victim);
        token.approve(chamberAddress, 5000);
        chamber.deposit(5000, victim);
        vm.stopPrank();

        uint256 victimShares = chamber.balanceOf(victim);

        // With virtual shares, victim now gets meaningful shares
        // shares = 5000 * (1000 + 1000) / (10001 + 1) = 5000 * 2000 / 10002 = 999
        assertGt(victimShares, 0, "Victim gets shares - attack prevented!");
        console.log("Victim shares:", victimShares);

        // Step 4: Verify the attacker can't steal the victim's deposit
        vm.startPrank(attacker);
        uint256 attackerAssets = chamber.previewRedeem(attackerShares);
        vm.stopPrank();

        // Attacker deposited 10001 total, can only redeem roughly their share
        assertLt(attackerAssets, 15001, "Attacker cannot drain entire vault");
        console.log("Attacker can redeem:", attackerAssets);
    }

    /**
     * @notice Verify normal deposit/withdraw flow works correctly with virtual offset.
     */
    function test_Fixed_NormalDepositWithdrawWorks() public {
        token.mint(victim, 100e18);

        vm.startPrank(victim);
        token.approve(chamberAddress, 100e18);
        chamber.deposit(100e18, victim);

        uint256 shares = chamber.balanceOf(victim);
        assertGt(shares, 0, "Victim gets shares");

        // Withdraw should return approximately the same amount
        uint256 maxWithdraw = chamber.maxWithdraw(victim);
        chamber.withdraw(maxWithdraw, victim, victim);
        vm.stopPrank();

        // Should get back approximately what was deposited (minus rounding)
        uint256 finalBalance = token.balanceOf(victim);
        assertGe(finalBalance, 99e18, "Got back approximately deposited amount");
    }
}
