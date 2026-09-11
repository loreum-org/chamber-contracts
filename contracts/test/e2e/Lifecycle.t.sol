// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Factory} from "src/Factory.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";

contract LifecycleTest is Test {
    Factory public factory;
    MockERC20 public token;
    MockERC721 public nft;

    address public admin = makeAddr("admin");
    address public whale = makeAddr("whale");
    address public recipient = makeAddr("recipient");

    address[] public directors;
    uint256[] public directorTokenIds;

    function setUp() public {
        factory = new Factory(address(new Chamber()), admin);

        token = new MockERC20("Mock DAI", "mDAI", 18);
        nft = new MockERC721("Chamber Member", "MEM");

        for (uint256 i = 0; i < 5; i++) {
            address d = makeAddr(string.concat("director", vm.toString(i)));
            directors.push(d);
            vm.prank(d);
            uint256 tid = nft.mint(d);
            directorTokenIds.push(tid);
        }
    }

    function test_E2E_ChamberLifecycle() public {
        console.log("Starting E2E Chamber Lifecycle Test");

        vm.startPrank(whale);
        address chamberAddr = factory.createChamber(address(token), address(nft), 5, "Treasury Chamber", "TCH");
        Chamber chamber = Chamber(payable(chamberAddr));
        vm.stopPrank();

        assertEq(chamber.name(), "Treasury Chamber");
        assertEq(chamber.getSeats(), 5);

        token.mint(whale, 10000e18);

        vm.startPrank(whale);
        token.approve(address(chamber), 10000e18);
        chamber.deposit(10000e18, whale);

        for (uint256 i = 0; i < 5; i++) {
            chamber.delegate(directorTokenIds[i], 2000e18);
        }
        vm.stopPrank();
        vm.roll(block.number + 1);

        address[] memory board = chamber.getDirectors();
        assertEq(board.length, 5);

        bool found;
        for (uint256 i = 0; i < board.length; i++) {
            if (board[i] == directors[0]) found = true;
        }
        assertTrue(found, "Director 0 should be on the board");

        bytes memory transferData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, 100e18);

        vm.prank(directors[0]);
        chamber.submitTransaction(directorTokenIds[0], address(token), 0, transferData);

        (bool executed, uint8 confirmations, address target,,) = chamber.getTransaction(0);
        assertEq(target, address(token));
        assertEq(confirmations, 1);

        vm.prank(directors[1]);
        chamber.confirmTransaction(directorTokenIds[1], 0);

        vm.prank(directors[2]);
        chamber.confirmTransaction(directorTokenIds[2], 0);

        (, confirmations,,,) = chamber.getTransaction(0);
        assertEq(confirmations, 3);

        uint256 balBefore = token.balanceOf(recipient);

        vm.prank(directors[0]);
        chamber.executeTransaction(directorTokenIds[0], 0, transferData);

        uint256 balAfter = token.balanceOf(recipient);
        assertEq(balAfter - balBefore, 100e18);

        (executed,,,,) = chamber.getTransaction(0);
        assertTrue(executed);
    }
}
