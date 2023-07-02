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
    MockERC20 LORE;
    MockNFT Explorers;
    Chamber Treasury;

    function setUp() public {
        
        LORE = new MockERC20("Loreum", "LORE", address(this));
        Explorers = new MockNFT("Loreum Explorers", "LOREUM", address(this));
        Treasury = new Chamber(address(Explorers), address(LORE), 3, 5);
        USD = new MockERC20("US Dollar", "USD", address(Treasury));

        vm.deal(address(Treasury), 100 ether);

    }

    event Log(uint256[]);

    function stakeExplorers() public {
        
        // Approve Chamber for large amount of LORE
        LORE.approve(address(Treasury), 10_000_000_000 ether);

        Treasury.stake(100_000 ether, 1);
        Treasury.stake(120_000 ether, 2);
        Treasury.stake(50_000 ether, 3);
        Treasury.stake(250_000 ether, 4);
        Treasury.stake(70_000 ether, 5);

        (uint[] memory ranksTop, uint[] memory stakesTop) = Treasury.viewRankings();

    }

    function test_proposal_cycle() public {

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

        Treasury.create(targetArray, valueArray, dataArray);

        // Approve Proposal

        Treasury.approve(1, 3);
        Treasury.approve(1, 2);

        // Execute Proposal

        Treasury.approve(1, 1);

    }

}