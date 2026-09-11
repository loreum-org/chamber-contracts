// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
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

/// @notice Symbolic verification of Chamber delegation accounting via Halmos
contract ChamberSymTest is Test, SymTest {
    Chamber internal chamber;
    MockERC20 internal token;
    MockERC721 internal nft;

    address internal constant USER = address(0xBEEF);

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 1_000_000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamber = DeployChamber.deploy(address(token), address(nft), 5, "vERC20", "Vault Token", address(0x9));
    }

    /// @dev Holder delegation never exceeds chamber share balance
    function symbolicDelegationBoundedByBalance() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        vm.assume(tokenId > 0);

        uint256 depositAmount = svm.createUint256("depositAmount");
        uint256 delegateAmount = svm.createUint256("delegateAmount");
        vm.assume(depositAmount > 0 && delegateAmount > 0 && delegateAmount <= depositAmount);

        _fundAndDelegate(tokenId, depositAmount, delegateAmount);

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

        _fundAndDelegate(tokenId, depositAmount, delegateAmount);

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

        _fundAndDelegate(tokenId, depositAmount, delegateAmount);

        vm.prank(USER);
        chamber.undelegate(tokenId, undelegateAmount);

        uint256 expected = delegateAmount - undelegateAmount;
        assertEq(chamber.getHolderDelegation(USER, tokenId), expected);
        assertEq(chamber.getTotalHolderDelegations(USER), expected);

        (, uint256 nodeAmount,,) = chamber.getMember(tokenId);
        assertEq(nodeAmount, expected);
    }

    function _fundAndDelegate(uint256 tokenId, uint256 depositAmount, uint256 delegateAmount) internal {
        nft.mintWithTokenId(USER, tokenId);
        token.mint(USER, depositAmount);

        vm.startPrank(USER);
        token.approve(address(chamber), depositAmount);
        chamber.deposit(depositAmount, USER);
        chamber.delegate(tokenId, delegateAmount);
        vm.stopPrank();
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
    ///      Reads the PMN-M04 session ABI (expiry/scope/liveAt). Not a symbolic proof of
    ///      expiry, scope bits, or the confirm/execute delay.
    function symbolicSessionKeyIsOnlyApprovedOperator() public {
        uint256 tokenId = svm.createUint(128, "tokenId");
        address sessionKey = svm.createAddress("sessionKey");
        address other = svm.createAddress("other");
        vm.assume(tokenId > 0);
        vm.assume(sessionKey != address(0));
        vm.assume(other != address(0) && other != sessionKey);

        MockSessionOwner wallet = new MockSessionOwner();
        vm.assume(other != address(wallet));

        nft.mintWithTokenId(address(wallet), tokenId);
        wallet.execute(
            address(chamber),
            abi.encodeCall(IChamber.setDirectorOperator, (tokenId, sessionKey, type(uint64).max, type(uint32).max))
        );

        assertTrue(chamber.isTokenAuthorized(tokenId, address(wallet)));
        assertTrue(chamber.isTokenAuthorized(tokenId, sessionKey));
        assertFalse(chamber.isTokenAuthorized(tokenId, other));
        assertEq(chamber.getDirectorOperator(tokenId), sessionKey);
        assertEq(chamber.getDirectorOperatorScope(tokenId), type(uint32).max);
        assertEq(chamber.getDirectorOperatorLiveAt(tokenId), block.number + 1);

        (address sessionOwner, address storedOp, uint256 expiry, uint32 scope, uint256 liveAt) =
            chamber.getDirectorSession(tokenId);
        assertEq(sessionOwner, address(wallet));
        assertEq(storedOp, sessionKey);
        assertEq(expiry, type(uint64).max);
        assertEq(scope, type(uint32).max);
        assertEq(liveAt, block.number + 1);
    }
}
