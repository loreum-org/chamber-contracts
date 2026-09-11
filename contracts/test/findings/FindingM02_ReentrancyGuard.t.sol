// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
import {
    ReentrancyGuardTransientUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardTransientUpgradeable.sol";

/**
 * @title M-02: Shared reentrancy guard on vault, board, and seat mutators
 * @notice Defensive coverage: during wallet `target.call`, previously ungated
 *         public mutators now revert with the shared OZ transient guard.
 */

/// @notice Callback target that attempts one Chamber mutator during execution.
contract GuardedReenterTarget {
    enum Action {
        Deposit,
        Mint,
        Withdraw,
        Redeem,
        Delegate,
        Undelegate,
        UpdateSeats,
        ExecuteSeatsUpdate
    }

    Chamber public immutable chamber;
    Action public action;
    bool public attempted;
    bool public reenterReverted;

    constructor(address _chamber) {
        chamber = Chamber(payable(_chamber));
    }

    function setAction(Action _action) external {
        action = _action;
        attempted = false;
        reenterReverted = false;
    }

    receive() external payable {
        if (attempted) return;
        attempted = true;

        if (action == Action.Deposit) {
            _try(address(chamber), abi.encodeCall(chamber.deposit, (1, address(this))));
        } else if (action == Action.Mint) {
            _try(address(chamber), abi.encodeCall(chamber.mint, (1, address(this))));
        } else if (action == Action.Withdraw) {
            _try(address(chamber), abi.encodeCall(chamber.withdraw, (1, address(this), address(this))));
        } else if (action == Action.Redeem) {
            _try(address(chamber), abi.encodeCall(chamber.redeem, (1, address(this), address(this))));
        } else if (action == Action.Delegate) {
            _try(address(chamber), abi.encodeCall(chamber.delegate, (1, 1)));
        } else if (action == Action.Undelegate) {
            _try(address(chamber), abi.encodeCall(chamber.undelegate, (1, 1)));
        } else if (action == Action.UpdateSeats) {
            _try(address(chamber), abi.encodeCall(chamber.updateSeats, (1, 4)));
        } else {
            _try(address(chamber), abi.encodeCall(chamber.executeSeatsUpdate, (1)));
        }
    }

    function _try(address target, bytes memory data) private {
        (bool ok, bytes memory reason) = target.call(data);
        reenterReverted = !ok && _isGuardError(reason);
    }

    function _isGuardError(bytes memory reason) private pure returns (bool) {
        return reason.length >= 4
            && bytes4(reason) == ReentrancyGuardTransientUpgradeable.ReentrancyGuardReentrantCall.selector;
    }
}

contract FindingM02ReentrancyGuardTest is Test {
    Registry public registry;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public chamberAddress;
    IChamber public chamber;
    GuardedReenterTarget public target;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        chamberAddress = address(DeployChamber.deployViaFactory(address(token), address(nft), 3, "Chamber Token", "CHMB", admin));
        chamber = IChamber(chamberAddress);
        target = new GuardedReenterTarget(chamberAddress);

        _setupDirector(user1, 1, 100e18);
        _setupDirector(user2, 2, 100e18);
        _setupDirector(user3, 3, 100e18);
        vm.roll(block.number + 1);
    }

    function test_M02_DepositRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Deposit);
    }

    function test_M02_MintRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Mint);
    }

    function test_M02_WithdrawRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Withdraw);
    }

    function test_M02_RedeemRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Redeem);
    }

    function test_M02_DelegateRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Delegate);
    }

    function test_M02_UndelegateRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.Undelegate);
    }

    function test_M02_UpdateSeatsRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.UpdateSeats);
    }

    function test_M02_ExecuteSeatsUpdateRevertsOnReenter() public {
        _assertGuarded(GuardedReenterTarget.Action.ExecuteSeatsUpdate);
    }

    function test_M02_GuardReleasedAfterExecution() public {
        _assertGuarded(GuardedReenterTarget.Action.Deposit);

        deal(address(token), user1, 1e18);
        vm.startPrank(user1);
        token.approve(chamberAddress, 1e18);
        uint256 shares = chamber.deposit(1e18, user1);
        vm.stopPrank();

        assertGt(shares, 0, "deposit succeeds after the wallet guard is released");
    }

    function _assertGuarded(GuardedReenterTarget.Action action) internal {
        target.setAction(action);

        deal(chamberAddress, 1 ether);

        vm.prank(user2);
        chamber.submitTransaction(2, address(target), 0.1 ether, "");

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user2);
        chamber.executeTransaction(2, 0, "");

        assertTrue(target.attempted(), "callback ran during execution");
        assertTrue(target.reenterReverted(), "reenter reverted with ReentrancyGuardReentrantCall");
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
