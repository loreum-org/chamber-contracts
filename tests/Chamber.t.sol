// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test (foundry-rs) imports.
import "../lib/forge-std/src/Test.sol";

// Loreum core contracts.
import "../src/Chamber.sol";
import "../lib/contract-utils/src/MockERC20.sol";
import "../lib/contract-utils/src/MockNFT.sol";

import "../lib/forge-std/src/console2.sol";

import { TestUtilities } from "../lib/contract-utils/src/TestUtilities.sol";

contract ChamberTest is Test, TestUtilities {

    MockERC20 USD;
    MockERC20 mERC20;
    MockNFT mNFT;
    Chamber chamber;

    function setUp() public {
        
        mERC20 = new MockERC20("Loreum", "LORE", address(this));
        mNFT = new MockNFT("Loreum Explorers", "LOREUM", address(this));
        chamber = new Chamber(address(mNFT), address(mERC20), 3, 5);
        USD = new MockERC20("US Dollar", "USD", address(chamber));

        vm.deal(address(chamber), 100 ether);

    }

    function stakeExplorers() public {
        
        // Approve Chamber for large amount of LORE
        mERC20.approve(address(chamber), 10_000_000_000 ether);

        chamber.stake(100_000 ether, 1);
        chamber.stake(120_000 ether, 2);
        chamber.stake(50_000 ether, 3);
        chamber.stake(250_000 ether, 4);
        chamber.stake(70_000 ether, 5);

        (uint[] memory ranksTop, uint[] memory stakesTop) = chamber.viewRankings();
        (ranksTop, stakesTop);

    }

    function test_Chamber_proposal() public {

        stakeExplorers();

        // Create Proposal

        uint256 amount = 100_000 ether;

        bytes[] memory dataArray = new bytes[](4);
        address[] memory targetArray = new address[](4);
        uint256[] memory valueArray = new uint256[](4);

        dataArray[0] = abi.encodeWithSignature("transfer(address,uint256)", address(42), amount);
        dataArray[1] = abi.encodeWithSignature("transfer(address,uint256)", address(69), amount);
        dataArray[2] = abi.encodeWithSignature("transfer()");
        dataArray[3] = abi.encodeWithSignature("transfer()");

        targetArray[0] = address(USD);
        targetArray[1] = address(USD);
        targetArray[2] = address(42);
        targetArray[3] = address(69);

        valueArray[0] = 0;
        valueArray[1] = 0;
        valueArray[2] = 10 ether;
        valueArray[3] = 5 ether;

        chamber.createTx(targetArray, valueArray, dataArray);

        // Approve Proposal

        chamber.approveTx(1, 3);
        chamber.approveTx(1, 2);

        // Execute Proposal

        chamber.approveTx(1, 1);

    }

    function test_Chamber_stake (uint256 amount) public {
        deal(address(mERC20), address(33), amount);
        vm.startPrank(address(33));
        mERC20.approve(address(chamber), amount);
        chamber.stake(amount, 5);

        uint256 stakeBalance = chamber.memberNftStake(address(33), 5);
        assertEq(stakeBalance, amount);

        uint256 totalStakeForNft = chamber.totalStake(5);
        assertEq(totalStakeForNft, amount);

        vm.stopPrank();
    }

    function test_Chamber_unstake (uint256 amount) public {
        deal(address(mERC20), address(34), amount);
        vm.startPrank(address(34));
        mERC20.approve(address(chamber), amount);
        chamber.stake(amount, 6);

        uint256 stakeBalance = chamber.memberNftStake(address(34), 6);
        assertEq(stakeBalance, amount);

        uint256 totalStakeForNft = chamber.totalStake(6);
        assertEq(totalStakeForNft, amount);

        chamber.unstake(amount, 6);
        uint256 newStakeBalance = chamber.memberNftStake(address(34), 6);
        assertEq(newStakeBalance, 0);
        
        uint newTotalStakeForNft = chamber.totalStake(6);
        assertEq(newTotalStakeForNft, 0);
        vm.stopPrank();
    }

}