// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {HalmosDeploy} from "test/symbolic/HalmosDeploy.sol";
import {IChamber} from "src/interfaces/IChamber.sol";

/// @dev Contract wallet that can register a session key as itself.
contract MockSessionOwner {
    function execute(address target, bytes calldata data) external {
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

/// @notice Symbolic verification of Chamber delegation, session keys, and wallet auth
/// @dev Initializes the Chamber *implementation* (see HalmosDeploy). No proxy / ProxyAdmin.
contract ChamberSymTest is Test, SymTest {
    Chamber internal chamber;
    MockERC20 internal token;
    MockERC721 internal nft;
    MockSessionOwner internal sessionOwner;

    address internal constant USER = address(0xBEEF);
    address internal constant USER2 = address(0xCAFE);
    address internal constant TARGET = address(0x100);

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        sessionOwner = new MockSessionOwner();
        // Two seats → quorum 2, so submit+confirm is required to execute.
        chamber = HalmosDeploy.chamber(address(token), address(nft), 2, "vERC20", "Vault Token");
    }

    /// @dev initialize writes the intended asset, membership NFT, and seat count
    function symbolicInitializeStoresConfig() public view {
        assertEq(chamber.asset(), address(token));
        assertEq(address(chamber.nft()), address(nft));
        assertEq(chamber.getSeats(), 2);
        assertEq(chamber.getQuorum(), 2);
        assertFalse(chamber.paused());
    }

    /// @dev Zero or >20 seats cannot initialize a Chamber implementation
    function symbolicInitializeInvalidSeatsReverts() public {
        uint256 seats = svm.createUint256("seats");
        vm.assume(seats == 0 || seats > 20);

        Chamber fresh = new Chamber();
        HalmosDeploy.enableInitializer(address(fresh));
        (bool success,) =
            address(fresh).call(abi.encodeCall(Chamber.initialize, (address(token), address(nft), seats, "n", "s")));
        assertFalse(success);
    }

    /// @dev Holder delegation never exceeds chamber share balance
    function symbolicDelegationBoundedByBalance() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        vm.assume(tokenId > 0);

        uint256 depositAmount = svm.createUint256("depositAmount");
        uint256 delegateAmount = svm.createUint256("delegateAmount");
        vm.assume(depositAmount > 0 && delegateAmount > 0 && delegateAmount <= depositAmount);

        _fundAndDelegate(USER, tokenId, depositAmount, delegateAmount);

        assertLe(chamber.getHolderDelegation(USER, tokenId), chamber.balanceOf(USER));
        assertEq(chamber.getHolderDelegation(USER, tokenId), delegateAmount);
        assertEq(chamber.getTotalHolderDelegations(USER), delegateAmount);
    }

    /// @dev Board node amount matches holder delegation after delegate
    function symbolicBoardNodeMatchesDelegation() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        vm.assume(tokenId > 0);

        uint256 depositAmount = svm.createUint256("depositAmount");
        uint256 delegateAmount = svm.createUint256("delegateAmount");
        vm.assume(depositAmount > 0 && delegateAmount > 0 && delegateAmount <= depositAmount);

        _fundAndDelegate(USER, tokenId, depositAmount, delegateAmount);

        (, uint256 nodeAmount,,) = chamber.getMember(tokenId);
        assertEq(nodeAmount, delegateAmount);
    }

    /// @dev Partial undelegate reduces holder and node amounts consistently
    function symbolicUndelegateAccounting() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        vm.assume(tokenId > 0);

        uint256 depositAmount = svm.createUint256("depositAmount");
        uint256 delegateAmount = svm.createUint256("delegateAmount");
        uint256 undelegateAmount = svm.createUint256("undelegateAmount");
        vm.assume(depositAmount > 0 && delegateAmount > 0 && delegateAmount <= depositAmount);
        vm.assume(undelegateAmount > 0 && undelegateAmount <= delegateAmount);

        _fundAndDelegate(USER, tokenId, depositAmount, delegateAmount);

        vm.prank(USER);
        chamber.undelegate(tokenId, undelegateAmount);

        uint256 expected = delegateAmount - undelegateAmount;
        assertEq(chamber.getHolderDelegation(USER, tokenId), expected);
        assertEq(chamber.getTotalHolderDelegations(USER), expected);

        (, uint256 nodeAmount,,) = chamber.getMember(tokenId);
        assertEq(nodeAmount, expected);
    }

    /// @dev Transfer cannot drop a holder's share balance below their outstanding delegation
    function symbolicTransferRespectsDelegation() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        uint256 depositAssets = svm.createUint(48, "depositAssets");
        vm.assume(tokenId > 0 && depositAssets > 0);

        nft.mintWithTokenId(USER, tokenId);
        token.mint(USER, depositAssets);
        vm.startPrank(USER);
        token.approve(address(chamber), depositAssets);
        chamber.deposit(depositAssets, USER);
        uint256 shares = chamber.balanceOf(USER);

        uint256 delegateAmount = svm.createUint(64, "delegateAmount");
        uint256 transferAmount = svm.createUint(64, "transferAmount");
        vm.assume(delegateAmount > 0 && delegateAmount <= shares);
        vm.assume(transferAmount > 0 && transferAmount <= shares);
        vm.assume(shares - transferAmount < delegateAmount);

        chamber.delegate(tokenId, delegateAmount);
        (bool success,) = address(chamber).call(abi.encodeCall(chamber.transfer, (USER2, transferAmount)));
        vm.stopPrank();

        assertFalse(success);
        assertEq(chamber.balanceOf(USER), shares);
        assertEq(chamber.getTotalHolderDelegations(USER), delegateAmount);
    }

    /// @dev EOA owner is authorized; any other symbolic caller is not (no 1271, no implicit operator).
    function symbolicUnauthorizedCallerIsNotTokenAuthorized() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        address caller = svm.createAddress("caller");
        vm.assume(tokenId > 0);
        vm.assume(caller != USER && caller != address(0));

        nft.mintWithTokenId(USER, tokenId);

        assertTrue(chamber.isTokenAuthorized(tokenId, USER));
        assertFalse(chamber.isTokenAuthorized(tokenId, caller));
    }

    /// @dev Only the registered session key (plus the contract owner) is authorized.
    function symbolicSessionKeyIsOnlyApprovedOperator() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        address sessionKey = svm.createAddress("sessionKey");
        address other = svm.createAddress("other");
        vm.assume(tokenId > 0);
        vm.assume(sessionKey != address(0));
        vm.assume(other != address(0) && other != sessionKey);
        vm.assume(other != address(sessionOwner) && sessionKey != address(sessionOwner));

        nft.mintWithTokenId(address(sessionOwner), tokenId);
        sessionOwner.execute(address(chamber), abi.encodeCall(IChamber.setDirectorOperator, (tokenId, sessionKey)));

        assertTrue(chamber.isTokenAuthorized(tokenId, address(sessionOwner)));
        assertTrue(chamber.isTokenAuthorized(tokenId, sessionKey));
        assertFalse(chamber.isTokenAuthorized(tokenId, other));
        assertEq(chamber.getDirectorOperator(tokenId), sessionKey);
    }

    /// @dev Transferring the membership NFT clears the live session key (stale owner binding).
    function symbolicOperatorClearedOnTransfer() public {
        uint256 tokenId = svm.createUint(16, "tokenId");
        address sessionKey = svm.createAddress("sessionKey");
        address recipient = svm.createAddress("recipient");
        vm.assume(tokenId > 0);
        vm.assume(sessionKey != address(0) && sessionKey != address(sessionOwner));
        vm.assume(recipient != address(0) && recipient != address(sessionOwner) && recipient != sessionKey);

        nft.mintWithTokenId(address(sessionOwner), tokenId);
        sessionOwner.execute(address(chamber), abi.encodeCall(IChamber.setDirectorOperator, (tokenId, sessionKey)));
        assertEq(chamber.getDirectorOperator(tokenId), sessionKey);

        sessionOwner.execute(address(nft), abi.encodeCall(nft.transferFrom, (address(sessionOwner), recipient, tokenId)));

        assertEq(nft.ownerOf(tokenId), recipient);
        assertEq(chamber.getDirectorOperator(tokenId), address(0));
        assertFalse(chamber.isTokenAuthorized(tokenId, sessionKey));
        assertTrue(chamber.isTokenAuthorized(tokenId, recipient));
    }

    /// @dev A newly seated token cannot submit until the seating delay elapses
    function symbolicImmatureDirectorCannotSubmit() public {
        uint256 tokenId = 1;
        _fundAndDelegate(USER, tokenId, 1e18, 1e18);

        vm.prank(USER);
        (bool success,) = address(chamber).call(_submitTx(tokenId));
        assertFalse(success);
    }

    /// @dev Wallet submit / confirm / execute / cancel require a current, mature director token
    function symbolicWalletQueueRequiresDirector() public {
        address stranger = svm.createAddress("stranger");
        vm.assume(stranger != USER && stranger != USER2 && stranger != address(0));

        _fundAndDelegate(USER, 1, 2e18, 2e18);
        _fundAndDelegate(USER2, 2, 1e18, 1e18);
        vm.roll(block.number + 1);

        vm.prank(stranger);
        (bool submitOk,) = address(chamber).call(_submitTx(1));
        assertFalse(submitOk);

        vm.prank(USER);
        chamber.submitTransaction(1, TARGET, 0, "");
        assertTrue(chamber.getConfirmation(1, 0));
        assertEq(chamber.getTransactionRequiredQuorum(0), 2);

        vm.prank(stranger);
        (bool confirmOk,) = address(chamber).call(abi.encodeCall(chamber.confirmTransaction, (2, 0)));
        assertFalse(confirmOk);

        // One confirmation is below live quorum; execute must fail.
        vm.prank(USER);
        (bool executeEarly,) = address(chamber).call(abi.encodeCall(chamber.executeTransaction, (1, 0, bytes(""))));
        assertFalse(executeEarly);

        vm.prank(USER2);
        chamber.confirmTransaction(2, 0);

        vm.prank(USER);
        chamber.executeTransaction(1, 0, "");
        (bool executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed);
    }

    /// @dev Two cancel votes (quorum 2) mark the nonce cancelled and block execute
    function symbolicWalletCancelRequiresQuorum() public {
        _fundAndDelegate(USER, 1, 2e18, 2e18);
        _fundAndDelegate(USER2, 2, 1e18, 1e18);
        vm.roll(block.number + 1);

        vm.prank(USER);
        chamber.submitTransaction(1, TARGET, 0, "");

        vm.prank(USER);
        chamber.cancelTransaction(1, 0);
        assertFalse(chamber.getCancelled(0));

        vm.prank(USER2);
        chamber.cancelTransaction(2, 0);
        assertTrue(chamber.getCancelled(0));

        vm.prank(USER);
        (bool success,) = address(chamber).call(abi.encodeCall(chamber.executeTransaction, (1, 0, bytes(""))));
        assertFalse(success);
    }

    /// @dev Live session key may submit after seating; NFT transfer drops that right
    function symbolicSessionKeyCanSubmitUntilTransfer() public {
        address sessionKey = svm.createAddress("sessionKey");
        vm.assume(sessionKey != address(0) && sessionKey != address(sessionOwner) && sessionKey != USER);

        _fundAndDelegate(address(sessionOwner), 1, 2e18, 2e18);
        _fundAndDelegate(USER, 2, 1e18, 1e18);
        vm.roll(block.number + 1);

        sessionOwner.execute(address(chamber), abi.encodeCall(IChamber.setDirectorOperator, (uint256(1), sessionKey)));

        vm.prank(sessionKey);
        chamber.submitTransaction(1, TARGET, 0, "");
        assertEq(chamber.getTransactionCount(), 1);

        sessionOwner.execute(address(nft), abi.encodeCall(nft.transferFrom, (address(sessionOwner), USER, uint256(1))));

        vm.prank(sessionKey);
        (bool success,) = address(chamber).call(_submitTx(1));
        assertFalse(success);
        assertEq(chamber.getDirectorOperator(1), address(0));
    }

    /// @dev pause / unpause / upgradeImplementation reject any caller other than the chamber itself
    function symbolicPrivilegedSelfCallsRejectOutsiders() public {
        address caller = svm.createAddress("caller");
        vm.assume(caller != address(chamber) && caller != address(0));

        vm.startPrank(caller);
        (bool pauseOk,) = address(chamber).call(abi.encodeCall(Chamber.pause, ()));
        (bool unpauseOk,) = address(chamber).call(abi.encodeCall(Chamber.unpause, ()));
        (bool upgradeOk,) =
            address(chamber).call(abi.encodeCall(Chamber.upgradeImplementation, (address(0xB0B), bytes(""))));
        vm.stopPrank();

        assertFalse(pauseOk);
        assertFalse(unpauseOk);
        assertFalse(upgradeOk);
        assertFalse(chamber.paused());
    }

    function _submitTx(uint256 tokenId) internal view returns (bytes memory) {
        return abi.encodeWithSignature("submitTransaction(uint256,address,uint256,bytes)", tokenId, TARGET, uint256(0), bytes(""));
    }

    function _fundAndDelegate(address holder, uint256 tokenId, uint256 depositAmount, uint256 delegateAmount)
        internal
    {
        nft.mintWithTokenId(holder, tokenId);
        token.mint(holder, depositAmount);

        vm.startPrank(holder);
        token.approve(address(chamber), depositAmount);
        chamber.deposit(depositAmount, holder);
        chamber.delegate(tokenId, delegateAmount);
        vm.stopPrank();
    }
}
