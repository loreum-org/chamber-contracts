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
 * @title Finding 9: Wallet State Visibility During External Call [MEDIUM] — FIXED
 * @notice Verifies that nonReentrant on submitTransaction/confirmTransaction
 *         prevents reentrant calls during transaction execution.
 */

/// @notice Malicious contract that re-enters Chamber during transaction execution
contract ReentrantTarget {
    Chamber public chamber;
    uint256 public tokenId;
    bool public attacked;
    bool public submitReverted;

    constructor(address _chamber, uint256 _tokenId) {
        chamber = Chamber(payable(_chamber));
        tokenId = _tokenId;
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;

            // Try to re-enter submitTransaction during execution
            // This should now revert due to nonReentrant
            try chamber.submitTransaction(tokenId, address(0xdead), 0, "") {
                submitReverted = false;
            } catch {
                submitReverted = true;
            }
        }
    }
}

contract WalletReentrancyTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public chamberAddress;
    IChamber public chamber;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 3, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);

        _setupDirector(user1, 1, 100e18);
        _setupDirector(user2, 2, 100e18);
        _setupDirector(user3, 3, 100e18);
        vm.roll(block.number + 1);
    }

    /**
     * @notice FIXED: Reentrant submitTransaction is now blocked by nonReentrant.
     */
    function test_Fixed_ReentrantSubmitBlocked() public {
        // Deploy malicious target
        ReentrantTarget target = new ReentrantTarget(chamberAddress, 1);

        // Transfer NFT 1 to target so it could act as director
        vm.prank(user1);
        nft.transferFrom(user1, address(target), 1);

        deal(chamberAddress, 1 ether);

        // Submit and gather quorum
        vm.prank(user2);
        chamber.submitTransaction(2, address(target), 0.1 ether, "");

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        // Execute — target's receive() will fire and try to reenter
        vm.prank(user2);
        chamber.executeTransaction(2, 0, "");

        // Verify callback fired but reentrant call was blocked
        assertTrue(target.attacked(), "Callback was triggered");
        assertTrue(target.submitReverted(), "FIXED: Reentrant submitTransaction was blocked by nonReentrant");

        // Only 1 transaction exists (the original one, not the reentrant one)
        assertEq(chamber.getTransactionCount(), 1, "No reentrant transaction was submitted");
        console.log("FIXED: Reentrant submitTransaction blocked by nonReentrant modifier");
    }

    function _setupDirector(address user, uint256 tokenId, uint256 amount) internal {
        token.mint(user, amount);
        nft.mintWithTokenId(user, tokenId);

        vm.startPrank(user);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, 1);
        vm.stopPrank();
    }
}
