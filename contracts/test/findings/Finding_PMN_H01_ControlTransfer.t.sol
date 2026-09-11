// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IERC1271} from "lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/// @dev Contract NFT owner used to register a session key (same pattern as Chamber.t.sol).
contract MockERC1271Wallet {
    address public authorizedAddress;

    constructor(address _authorized) {
        authorizedAddress = _authorized;
    }

    function isValidSignature(bytes32, bytes memory signature) external view returns (bytes4) {
        if (signature.length == 32) {
            address decoded = abi.decode(signature, (address));
            if (decoded == authorizedAddress) {
                return IERC1271.isValidSignature.selector;
            }
        }
        return bytes4(0xffffffff);
    }

    function execute(address target, bytes calldata data) external {
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

/**
 * @title PMN-H01: seating delay must bind NFT control transfer (Solution A)
 * @notice `SEATING_DELAY` applies when a tokenId newly enters the top-seat set (H-02)
 *         and when `ownerOf` of an already-seated tokenId changes. Session keys stay
 *         stale on transfer. Confirm/cancel bits recorded under the previous owner
 *         do not count for quorum/execute.
 */
contract FindingPMNH01ControlTransferTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public userB = address(0xB);

    uint256 public constant SEATS = 3;
    uint256 public constant SEATING_DELAY = 1;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), SEATS, "vERC20", "VLT", address(0x9));

        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        vm.roll(block.number + SEATING_DELAY);
    }

    /// @notice H-02 regression: a tokenId that newly enters the top-seat set waits the delay.
    function test_PMNH01_newTopSeatStillWaitsDelay() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        _seat(user3, 3, 50 ether);

        assertEq(chamber.getSeatedAt(3), block.number + SEATING_DELAY, "new top-seat token activates next block");

        vm.prank(user3);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.submitTransaction(3, address(0x3), 0, "");

        vm.prank(user3);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.confirmTransaction(3, 0);

        vm.prank(user3);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.executeTransaction(3, 0, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);
        assertTrue(chamber.getConfirmation(2, 0), "existing seated director can still confirm");
    }

    /// @notice Keep current session-key behavior: transfer clears the previous operator.
    function test_PMNH01_sessionKeyClearsOnTransfer() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));

        nft.mintWithTokenId(address(wallet), 4);
        token.mint(user1, 50 ether);
        vm.startPrank(user1);
        token.approve(address(chamber), 50 ether);
        chamber.deposit(50 ether, user1);
        chamber.delegate(4, 50 ether);
        vm.stopPrank();
        vm.roll(block.number + SEATING_DELAY);

        wallet.execute(
            address(chamber),
            abi.encodeCall(
                chamber.setDirectorOperator,
                (4, sessionKey, block.timestamp + 30 days, chamber.SESSION_SCOPE_UNSCOPED())
            )
        );
        assertEq(chamber.getDirectorOperator(4), sessionKey);
        assertTrue(chamber.isTokenAuthorized(4, sessionKey));

        MockERC1271Wallet newWallet = new MockERC1271Wallet(address(0xBEEF));
        vm.prank(address(wallet));
        nft.transferFrom(address(wallet), address(newWallet), 4);

        assertEq(chamber.getDirectorOperator(4), address(0), "session key is stale after transfer");
        assertFalse(chamber.isTokenAuthorized(4, sessionKey));
        assertTrue(chamber.isTokenAuthorized(4, address(newWallet)), "only the new owner is authorized");

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(4, address(0x3), 0, "");

        uint32 unscoped = type(uint32).max;
        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(4, address(0xFEE1), block.timestamp + 30 days, unscoped);

        address newKey = address(0xA11);
        newWallet.execute(
            address(chamber),
            abi.encodeCall(
                chamber.setDirectorOperator, (4, newKey, block.timestamp + 30 days, chamber.SESSION_SCOPE_UNSCOPED())
            )
        );
        assertEq(chamber.getDirectorOperator(4), newKey, "only the new owner can register a session key");
    }

    /// @notice Solution A: transferring a mature seated token resets the seating clock.
    function test_PMNH01_controlTransfer_caseA_resetsClock() public {
        uint256 seatedAtBefore = chamber.getSeatedAt(1);
        assertTrue(block.number >= seatedAtBefore, "precondition: token 1 is mature");

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        nft.transferFrom(user1, userB, 1);

        uint256 seatedAtAfter = chamber.getSeatedAt(1);
        assertGt(seatedAtAfter, seatedAtBefore, "getSeatedAt moves forward on control transfer");
        assertEq(seatedAtAfter, block.number + SEATING_DELAY);

        chamber.syncSeating(1);
        assertEq(chamber.getSeatedAt(1), block.number + SEATING_DELAY, "sync persists the new clock");

        vm.prank(userB);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(userB);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.confirmTransaction(1, 0);

        vm.prank(userB);
        vm.expectRevert(IChamber.DirectorNotSeated.selector);
        chamber.executeTransaction(1, 0, "");

        vm.roll(block.number + SEATING_DELAY);
        assertTrue(block.number >= chamber.getSeatedAt(1));

        vm.prank(userB);
        chamber.submitTransaction(1, address(0x3), 0, "");
        assertEq(chamber.getTransactionCount(), 2, "new controller can submit after the reset delay");
    }

    /// @notice Solution A: prior-owner confirm bits do not count for the new controller.
    function test_PMNH01_controlTransfer_caseA_dropsPriorFlags() public {
        deal(address(chamber), 1 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x4), 1 ether, "");
        vm.prank(user2);
        chamber.confirmTransaction(2, 0);
        assertTrue(chamber.getConfirmation(1, 0), "A confirmed before transfer");
        assertTrue(chamber.getConfirmation(2, 0));

        vm.prank(user1);
        nft.transferFrom(user1, userB, 1);

        chamber.syncSeating(1);
        vm.roll(block.number + SEATING_DELAY);
        assertTrue(block.number >= chamber.getSeatedAt(1), "B has waited the new delay");

        vm.prank(userB);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, 0, "");

        vm.prank(user2);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(2, 0, "");

        (bool executed,,,,) = chamber.getTransaction(0);
        assertFalse(executed, "A's confirm must not satisfy quorum after control transfer");
    }

    function _seat(address user, uint256 tokenId, uint256 amount) internal {
        try nft.ownerOf(tokenId) returns (address owner) {
            if (owner != user) revert("token already minted to another owner");
        } catch {
            nft.mintWithTokenId(user, tokenId);
        }

        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, amount);
        vm.stopPrank();
    }
}
