// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IBoard} from "src/interfaces/IBoard.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IERC1271} from "lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";

/// @dev Contract NFT owner that can register a session key (same pattern as Chamber.t.sol).
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

/// @dev Owner with no Chamber-calling surface. Used only to hold a membership NFT.
contract InertOwner {}

/**
 * @title PMN-M02: burned or inert seated NFTs keep rank and spend flags
 * @notice Solution A: execute skips confirm/cancel bits when `ownerOf` fails, or when
 *         the owner has no revoke path and there is no live session key.
 *         Solution B: `cleanupInertSeat` drops a burned tokenId from the top set;
 *         later `refreshSeating` does not restore it while inert.
 */
contract FindingPMNM02InertSeatedNftTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public spendTarget = address(0x4);

    uint256 public constant SEATS = 3;
    uint256 public constant SEATING_DELAY = 1;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), SEATS, "vERC20", "VLT", address(0x9));
        deal(address(chamber), 1 ether);
    }

    /// @notice A mature seated owner confirms; that flag counts before burn.
    function test_PMNM02_liveOwnerFlagStillCounts() public {
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 1 ether, "");
        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        assertTrue(chamber.getConfirmation(1, 0));
        assertTrue(chamber.getConfirmation(2, 0));

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");
        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed, "live owner confirm bits still satisfy quorum");
        assertEq(spendTarget.balance, 1 ether);
    }

    /// @notice After burn, execute must not count that confirm bit.
    function test_PMNM02_caseA_burnedOwnerOfSkipsFlag() public {
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 1 ether, "");
        vm.prank(user2);
        chamber.confirmTransaction(2, 0);
        assertTrue(chamber.getConfirmation(2, 0), "stored bit remains after burn");

        nft.burn(2);
        vm.expectRevert();
        nft.ownerOf(2);

        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, 0, "");

        (bool executed,,,,) = chamber.getTransaction(0);
        assertFalse(executed, "burned ownerOf confirm bit is skipped");
    }

    /// @notice Contract owner with no Chamber-calling surface and no live session key.
    ///         Assert the live tally only.
    function test_PMNM02_caseA_uncallableOwnerFlagSkipped() public {
        InertOwner inert = new InertOwner();
        _seat(user1, 1, 100 ether);
        _seat(address(inert), 2, 100 ether);
        _seat(user3, 3, 50 ether);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(user1);
        chamber.submitTransaction(1, spendTarget, 1 ether, "");
        vm.prank(address(inert));
        chamber.confirmTransaction(2, 0);

        assertTrue(chamber.getConfirmation(2, 0), "stored bit is still set");
        (, uint8 stored,,,) = chamber.getTransaction(0);
        assertEq(stored, 2, "wallet stored count still includes the inert bit");

        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, 0, "");

        (bool executed,,,,) = chamber.getTransaction(0);
        assertFalse(executed, "uncallable owner bit is omitted from the live tally");
    }

    /// @notice After burn, `cleanupInertSeat` removes the tokenId from the top set.
    ///         A later board mutation (`refreshSeating`) does not put it back while inert.
    function test_PMNM02_caseB_cleanupDropsRank() public {
        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 80 ether);
        _seat(user3, 3, 60 ether);
        vm.roll(block.number + SEATING_DELAY);

        assertTrue(_inTop(1), "precondition: token 1 is in the top set");

        nft.burn(1);
        assertTrue(_inTop(1), "burn alone leaves the node until cleanup");

        vm.expectRevert(IBoard.SeatNotInert.selector);
        chamber.cleanupInertSeat(2);

        vm.expectEmit(true, false, false, true, address(chamber));
        emit IChamber.InertSeatCleaned(1);
        chamber.cleanupInertSeat(1);

        assertFalse(_inTop(1), "cleanupInertSeat drops the burned tokenId");

        vm.startPrank(user2);
        chamber.undelegate(2, 1);
        chamber.delegate(2, 1);
        vm.stopPrank();

        assertFalse(_inTop(1), "refreshSeating does not restore an inert tokenId");
        assertTrue(_inTop(2));
        assertTrue(_inTop(3));
    }

    /// @notice A burn that clears the session key must not leave rank.
    function test_PMNM02_caseB_sessionKeyDoesNotKeepBurnedRank() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));

        _seat(user1, 1, 100 ether);
        _seat(address(wallet), 4, 90 ether);
        _seat(user2, 2, 80 ether);
        vm.roll(block.number + SEATING_DELAY);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (4, sessionKey)));
        assertEq(chamber.getDirectorOperator(4), sessionKey);
        assertTrue(chamber.isTokenAuthorized(4, sessionKey));
        assertTrue(_inTop(4));

        nft.burn(4);
        assertEq(chamber.getDirectorOperator(4), address(0), "session key is stale after burn");
        assertFalse(chamber.isTokenAuthorized(4, sessionKey));

        chamber.cleanupInertSeat(4);
        assertFalse(_inTop(4), "burned tokenId does not keep rank after session key clears");

        vm.startPrank(user1);
        chamber.undelegate(1, 1);
        chamber.delegate(1, 1);
        vm.stopPrank();

        assertFalse(_inTop(4), "refreshSeating does not restore rank while burned");
    }

    function _inTop(uint256 tokenId) internal view returns (bool) {
        (uint256[] memory ids,) = chamber.getTop(chamber.getSeats());
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == tokenId) return true;
        }
        return false;
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
