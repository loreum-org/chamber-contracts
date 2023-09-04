// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Chamber } from "../src/Chamber.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";

import { TestUtilities } from "../lib/contract-utils/src/TestUtilities.sol";

contract ChamberTest is Test, TestUtilities {

    MockERC20 USD;
    MockERC20 mERC20;
    MockNFT mNFT;
    Chamber chamber;

    function setUp() public {
        
        mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        mNFT = new MockNFT("MockNFT", "mNFT", address(this));
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

        chamber.createProposal(targetArray, valueArray, dataArray);

        // Approve Proposal

        chamber.approveProposal(1, 3);
        chamber.approveProposal(1, 2);

        // Execute Proposal

        chamber.approveProposal(1, 1);

    }

    function test_Chamber_stake (uint256 amount) public {
        deal(address(mERC20), address(33), amount);
        vm.startPrank(address(33));
        mERC20.approve(address(chamber), amount);
        chamber.stake(amount, 5);

        uint256 stakeBalance = chamber.accountNftStake(address(33), 5);
        assertEq(stakeBalance, amount);

        uint256 totalStakeForNft = chamber.totalStake(5);
        assertEq(totalStakeForNft, amount);

        vm.stopPrank();
    }

    function test_Chamber_stakeEnd (
        uint256 amount1, 
        uint256 amount2,
        uint256 amount3,
        uint256 amount4,
        uint256 amount5,
        uint256 amount6,
        uint256 amount7,
        uint256 amount8
        ) public {
        vm.assume(amount1 > 1000);
        vm.assume(amount2 > 1000);
        vm.assume(amount3 > 1000);
        vm.assume(amount4 > 1000);
        vm.assume(amount5 > 100);
        vm.assume(amount6 > 100);
        vm.assume(amount7 > 100);
        vm.assume(amount8 > 100);
        
        vm.assume(amount1 < 100_000_000_000 ether);
        vm.assume(amount2 < 100_000_000_000 ether);
        vm.assume(amount3 < 100_000_000_000 ether);
        vm.assume(amount4 < 100_000_000_000 ether);
        
        deal(address(mERC20), address(this), amount1);
        mERC20.approve(address(chamber), amount1);
        chamber.stake(amount1, amount5);
        chamber.unstake(amount1 / 2, amount5);

        deal(address(mERC20), address(this), amount2);
        mERC20.approve(address(chamber), amount2);        
        chamber.stake(amount2, amount6);
        chamber.unstake(amount2 / 5, amount6);
        
        deal(address(mERC20), address(this), amount3);
        mERC20.approve(address(chamber), amount3);        
        chamber.stake(amount3, amount7);
        chamber.unstake(amount3 / 3, amount7);
        
        deal(address(mERC20), address(this), amount4);
        mERC20.approve(address(chamber), amount4);        
        chamber.stake(amount4 / 4, amount8);
        chamber.unstake(amount4 / 4, amount8);

        deal(address(mERC20), address(this), amount1 / 4);
        mERC20.approve(address(chamber), amount1 / 4);        
        chamber.stake(amount1 / 4, amount5 / 5);

        deal(address(mERC20), address(this), amount2 / 4);
        mERC20.approve(address(chamber), amount2 / 4);        
        chamber.stake(amount2 / 4, amount4);

        deal(address(mERC20), address(this), amount2 / 5);
        mERC20.approve(address(chamber),amount2 / 5);  
        chamber.stake(amount2 / 5, amount6 / 4);

        deal(address(mERC20), address(this), amount3 / 2);
        mERC20.approve(address(chamber),amount3 / 2); 
        chamber.stake(amount3 / 2, amount6 / 3);
    }

    function test_Chamber_unstakeToZero() public {
        deal(address(mERC20), address(this), 10_000_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.stake(1_000 ether, 1);
        chamber.unstake(1_000 ether, 1);
    }

    function test_Chamber_stakeUnchanged() public {
        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.stake(6 ether, 1);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.stake(4 ether, 2);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.stake(2 ether, 3);

        chamber.stake(1, 3);
        chamber.stake(1, 5);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.stake(2 ether, 5);

        chamber.stake(1, 1);

        chamber.stake(1 ether, 2);
        chamber.stake(1 ether, 7);
        chamber.viewRankings();
    }

    function test_Chamber_unstake (uint256 amount) public {
        deal(address(mERC20), address(34), amount);
        vm.startPrank(address(34));
        mERC20.approve(address(chamber), amount);
        chamber.stake(amount, 6);

        uint256 stakeBalance = chamber.accountNftStake(address(34), 6);
        assertEq(stakeBalance, amount);

        uint256 totalStakeForNft = chamber.totalStake(6);
        assertEq(totalStakeForNft, amount);

        chamber.unstake(amount, 6);
        uint256 newStakeBalance = chamber.accountNftStake(address(34), 6);
        assertEq(newStakeBalance, 0);
        
        uint newTotalStakeForNft = chamber.totalStake(6);
        assertEq(newTotalStakeForNft, 0);
        vm.stopPrank();
    }

    function test_Chamber_ethTransfer (uint256 amount) public {
        vm.assume(amount < 100_000_000 ether);
        vm.deal(address(this), amount);
        
        (bool sent,) = address(chamber).call{value: amount}("");
        assertTrue(sent);
        assertEq(address(chamber).balance, amount + 100 ether);
    }

    function test_Chamber_fallback (uint256 amount) public {
        vm.assume(amount < 100_000_000 ether);
        uint256 bal1 = address(chamber).balance;
        (bool sent,) = address(chamber).call{value: amount}("sailMaster()");
        assertTrue(sent);
        uint256 bal2 = address(chamber).balance;
        assertEq(bal1, bal2 - amount);
    }
}
