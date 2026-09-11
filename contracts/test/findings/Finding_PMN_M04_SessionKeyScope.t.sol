// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IERC1271} from "lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
import {BoardTypes} from "src/types/BoardTypes.sol";

/// @dev Contract NFT owner used to register a session key (same pattern as Chamber.t.sol).
contract MockERC1271Wallet {
    uint256 public signatureCalls;
    address public authorizedAddress;

    constructor(address _authorized) {
        authorizedAddress = _authorized;
    }

    function isValidSignature(bytes32, bytes memory signature) external returns (bytes4) {
        signatureCalls += 1;
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
 * @title PMN-M04: session keys are unscoped, non-expiring, full-seat equivalents
 * @notice Solutions A (expiry), B (explicit scope), and C (`SEATING_DELAY` before
 *         confirm/execute). Not D. ERC-1271 stays unconsulted. No exploit PoCs.
 */
contract FindingPMNM04SessionKeyScopeTest is Test {
    Chamber public chamber;
    MockERC20 public token;
    MockERC721 public nft;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public sessionKey = address(0xB0B);

    MockERC1271Wallet public wallet;

    uint256 public constant SEATS = 3;
    uint256 public constant TOKEN_WALLET = 3;
    uint256 public constant SEATING_DELAY = BoardTypes.SEATING_DELAY;
    uint32 internal constant UNSCOPED = type(uint32).max;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), SEATS, "vERC20", "VLT", address(0x9));
        wallet = new MockERC1271Wallet(address(0xDEAD));

        _seat(user1, 1, 100 ether);
        _seat(user2, 2, 100 ether);
        _seat(address(wallet), TOKEN_WALLET, 100 ether);
        vm.roll(block.number + SEATING_DELAY);
    }

    /// @notice Only the NFT owner sets the key. The key cannot replace itself.
    ///         Clear to `address(0)` means the old key is not a director.
    function test_PMNM04_ownerOnlySetsAndClears() public {
        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(TOKEN_WALLET, sessionKey, block.timestamp + 30 days, UNSCOPED);

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(TOKEN_WALLET, address(0xFEE1), block.timestamp + 30 days, UNSCOPED);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey, "key cannot replace itself");

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (TOKEN_WALLET, address(0), 0, 0)));
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(TOKEN_WALLET, address(0x3), 0, "");
    }

    /// @notice Transfer stales the key in the same transaction. The new owner starts with no operator.
    function test_PMNM04_transferClearsKey() public {
        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey);

        MockERC1271Wallet newWallet = new MockERC1271Wallet(address(0xBEEF));
        vm.prank(address(wallet));
        nft.transferFrom(address(wallet), address(newWallet), TOKEN_WALLET);

        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0), "session key is stale after transfer");
        assertFalse(chamber.isTokenAuthorized(TOKEN_WALLET, sessionKey));
        assertTrue(chamber.isTokenAuthorized(TOKEN_WALLET, address(newWallet)), "new owner starts with no operator");
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(TOKEN_WALLET, address(0x3), 0, "");
    }

    /// @notice An EOA-owned token cannot register a session key. ERC-1271 is not called.
    function test_PMNM04_eoaOwnedNftHasNoSessionPath() public {
        uint256 eoaToken = 10;
        nft.mintWithTokenId(user1, eoaToken);

        uint256 callsBefore = wallet.signatureCalls();
        vm.prank(user1);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(eoaToken, sessionKey, block.timestamp + 30 days, UNSCOPED);

        assertEq(wallet.signatureCalls(), callsBefore, "ERC-1271 is not consulted on EOA set");
        assertEq(chamber.getDirectorOperator(eoaToken), address(0));

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        vm.prank(address(wallet));
        nft.transferFrom(address(wallet), user1, TOKEN_WALLET);

        vm.expectCall(address(wallet), abi.encodeWithSelector(IERC1271.isValidSignature.selector), 0);
        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(TOKEN_WALLET, address(0x3), 0, "");
        assertEq(wallet.signatureCalls(), callsBefore, "ERC-1271 is not consulted after transfer to EOA");
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0), "leftover mapping ignored on EOA owner");
    }

    /// @notice After the recorded expiry, the key cannot submit, confirm, execute, or update seats.
    ///         The owner can set a new expiry. Expiry zero is rejected at set (not no-expiry).
    function test_PMNM04_caseA_expiredKeyCannotAct() public {
        uint256 expiry = block.timestamp + 1 days;
        _setKey(sessionKey, expiry, UNSCOPED);
        (,, uint256 storedExpiry,,) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(storedExpiry, expiry, "every set stores an expiry");

        vm.expectRevert(IChamber.InvalidSessionExpiry.selector);
        _setKey(sessionKey, 0, UNSCOPED);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.warp(expiry + 1);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0), "expired key is not live");
        assertFalse(chamber.isTokenAuthorized(TOKEN_WALLET, sessionKey));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(TOKEN_WALLET, address(0x3), 0, "");

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.confirmTransaction(TOKEN_WALLET, 0);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeTransaction(TOKEN_WALLET, 0, "");

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.updateSeats(TOKEN_WALLET, 4);

        uint256 refreshed = block.timestamp + 7 days;
        _setKey(sessionKey, refreshed, UNSCOPED);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey, "owner can refresh expiry");
        (,, uint256 newExpiry,,) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(newExpiry, refreshed);
    }

    /// @notice A scoped key registered for confirm-only cannot execute or update seats.
    ///         Unscoped is an explicit owner choice (`SESSION_SCOPE_UNSCOPED`), not scope `0`.
    function test_PMNM04_caseB_scopeBlocksUndeclaredAction() public {
        vm.expectRevert(IChamber.InvalidSessionScope.selector);
        _setKey(sessionKey, block.timestamp + 30 days, 0);

        uint32 confirmOnly = chamber.SESSION_SCOPE_CONFIRM();
        _setKey(sessionKey, block.timestamp + 30 days, confirmOnly);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(sessionKey);
        chamber.confirmTransaction(TOKEN_WALLET, 0);
        assertTrue(chamber.getConfirmation(TOKEN_WALLET, 0), "confirm-only may confirm");

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeTransaction(TOKEN_WALLET, 0, "");

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.updateSeats(TOKEN_WALLET, 4);

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        (,,, uint32 scope,) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(scope, chamber.SESSION_SCOPE_UNSCOPED(), "unscoped is an explicit owner choice");
        assertEq(scope, UNSCOPED);
    }

    /// @notice A key set in block N cannot confirm or execute until `SEATING_DELAY`.
    ///         The owner can clear immediately.
    function test_PMNM04_caseC_newKeyWaitsDelay() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        (,,,, uint256 liveAt) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(liveAt, block.number + SEATING_DELAY);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.confirmTransaction(TOKEN_WALLET, 0);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeTransaction(TOKEN_WALLET, 0, "");

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (TOKEN_WALLET, address(0), 0, 0)));
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0), "owner can clear immediately");

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(sessionKey);
        chamber.confirmTransaction(TOKEN_WALLET, 0);
        assertTrue(chamber.getConfirmation(TOKEN_WALLET, 0));

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(sessionKey);
        chamber.executeTransaction(TOKEN_WALLET, 0, "");
        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed, "key may execute after SEATING_DELAY");
    }

    /// @notice Live getters expose scope and liveAt. Raw getDirectorSession may retain leftovers.
    function test_PMNM04_viewsExposeScopeAndLiveAt() public {
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), 0);
        assertEq(chamber.getDirectorOperatorLiveAt(TOKEN_WALLET), 0);

        uint32 confirmOnly = chamber.SESSION_SCOPE_CONFIRM();
        _setKey(sessionKey, block.timestamp + 30 days, confirmOnly);
        uint256 expectedLiveAt = block.number + SEATING_DELAY;

        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey);
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), confirmOnly);
        assertEq(chamber.getDirectorOperatorLiveAt(TOKEN_WALLET), expectedLiveAt);

        (,,, uint32 rawScope, uint256 rawLiveAt) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(rawScope, confirmOnly);
        assertEq(rawLiveAt, expectedLiveAt);

        vm.warp(block.timestamp + 31 days);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0), "expired key is not live");
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), 0);
        assertEq(chamber.getDirectorOperatorLiveAt(TOKEN_WALLET), 0);
        (,,, uint32 leftoverScope,) = chamber.getDirectorSession(TOKEN_WALLET);
        assertEq(leftoverScope, confirmOnly, "raw session retains leftover scope");
    }

    /// @notice Burning the membership NFT drops the live key. Leftover storage is not a director.
    function test_PMNM04_burnDropsLiveKey() public {
        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), sessionKey);
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), UNSCOPED);

        nft.burn(TOKEN_WALLET);

        assertEq(chamber.getDirectorOperator(TOKEN_WALLET), address(0));
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), 0);
        assertEq(chamber.getDirectorOperatorLiveAt(TOKEN_WALLET), 0);
        assertFalse(chamber.isTokenAuthorized(TOKEN_WALLET, sessionKey));
        assertFalse(chamber.isTokenAuthorized(TOKEN_WALLET, address(wallet)));

        vm.prank(sessionKey);
        vm.expectRevert();
        chamber.submitTransaction(TOKEN_WALLET, address(0x3), 0, "");
    }

    /// @notice Confirm-only cannot revoke. A revoke-scoped key may revoke immediately (no C delay).
    function test_PMNM04_revokeRespectsScope() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        uint32 confirmOnly = chamber.SESSION_SCOPE_CONFIRM();
        _setKey(sessionKey, block.timestamp + 30 days, confirmOnly);
        vm.roll(block.number + SEATING_DELAY);

        vm.prank(sessionKey);
        chamber.confirmTransaction(TOKEN_WALLET, 0);
        assertTrue(chamber.getConfirmation(TOKEN_WALLET, 0));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.revokeConfirmation(TOKEN_WALLET, 0);

        uint32 revokeOnly = chamber.SESSION_SCOPE_REVOKE();
        _setKey(sessionKey, block.timestamp + 30 days, revokeOnly);
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), revokeOnly);

        vm.prank(sessionKey);
        chamber.revokeConfirmation(TOKEN_WALLET, 0);
        assertFalse(chamber.getConfirmation(TOKEN_WALLET, 0), "revoke-scoped key may revoke immediately");
    }

    /// @notice Batch confirm/execute wait `SEATING_DELAY`. Confirm-only cannot executeBatch.
    function test_PMNM04_batchRespectsScopeAndDelay() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        bytes[] memory execData = new bytes[](1);

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        assertEq(chamber.getDirectorOperatorLiveAt(TOKEN_WALLET), block.number + SEATING_DELAY);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.confirmBatchTransactions(TOKEN_WALLET, ids);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeBatchTransactions(TOKEN_WALLET, ids, execData);

        address[] memory targets = new address[](1);
        targets[0] = address(0x4);
        uint256[] memory values = new uint256[](1);
        bytes[] memory data = new bytes[](1);
        vm.prank(sessionKey);
        chamber.submitBatchTransactions(TOKEN_WALLET, targets, values, data);

        vm.roll(block.number + SEATING_DELAY);
        vm.prank(sessionKey);
        chamber.confirmBatchTransactions(TOKEN_WALLET, ids);
        assertTrue(chamber.getConfirmation(TOKEN_WALLET, 0));

        uint32 confirmOnly = chamber.SESSION_SCOPE_CONFIRM();
        _setKey(sessionKey, block.timestamp + 30 days, confirmOnly);
        vm.roll(block.number + SEATING_DELAY);
        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeBatchTransactions(TOKEN_WALLET, ids, execData);
    }

    /// @notice Refreshing the key restarts `liveAt`. Confirm/execute wait the delay again.
    function test_PMNM04_refreshRestartsLiveAt() public {
        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        _setKey(sessionKey, block.timestamp + 30 days, UNSCOPED);
        uint256 firstLiveAt = chamber.getDirectorOperatorLiveAt(TOKEN_WALLET);
        vm.roll(firstLiveAt);
        vm.prank(sessionKey);
        chamber.confirmTransaction(TOKEN_WALLET, 0);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x5), 0, "");

        _setKey(sessionKey, block.timestamp + 60 days, UNSCOPED);
        uint256 secondLiveAt = chamber.getDirectorOperatorLiveAt(TOKEN_WALLET);
        assertGt(secondLiveAt, firstLiveAt, "refresh restarts liveAt");
        assertEq(secondLiveAt, firstLiveAt + SEATING_DELAY, "refresh liveAt is prior liveAt plus SEATING_DELAY");
        assertEq(chamber.getDirectorOperatorScope(TOKEN_WALLET), UNSCOPED);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.confirmTransaction(TOKEN_WALLET, 1);

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.executeTransaction(TOKEN_WALLET, 1, "");

        vm.roll(secondLiveAt);
        vm.prank(sessionKey);
        chamber.confirmTransaction(TOKEN_WALLET, 1);
        assertTrue(chamber.getConfirmation(TOKEN_WALLET, 1));
    }

    /// @notice Solution D only after written acceptance on #212. Not shipped in this PR.
    function test_PMNM04_accepted_unscopedUntilOwnerClears() public {
        // D: product acceptance that the key equals the seat until clear/transfer.
        // No written acceptance on #212. Tests 1–6 cover A+B+C instead.
        vm.skip(true);
    }

    function _setKey(address operator, uint256 expiry, uint32 scope) internal {
        wallet.execute(
            address(chamber), abi.encodeCall(chamber.setDirectorOperator, (TOKEN_WALLET, operator, expiry, scope))
        );
    }

    function _seat(address user, uint256 tokenId, uint256 amount) internal {
        nft.mintWithTokenId(user, tokenId);
        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user);
        chamber.delegate(tokenId, amount);
        vm.stopPrank();
    }
}
