// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../lib/forge-std/src/Test.sol";

import { Chamber } from "../../src/Chamber.sol";
import { IChamber } from "../../src/interfaces/IChamber.sol";

import { MockERC20 } from "../../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../../lib/contract-utils/src/MockNFT.sol";
import { LoreumNFT } from "../../lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "../../lib/loreum-token/src/LoreumToken.sol";

contract ProposalCycleTest is Test {

    MockERC20 USD;
    LoreumToken LORE;
    LoreumNFT Explorers;
    Chamber chamber;
    address bones = address(1);
    address coconut = address(2);
    address hurricane = address(3);
    address jack = address(4);
    address danny = address(5);
    address shifty = address(6);
    address blackbeard = address(7); 

    address[7] lorians = [bones,coconut,hurricane,jack,danny,shifty,blackbeard];

    function setUp() public {
        LORE = new LoreumToken(address(100), 1000000 ether, 10000000 ether);
        Explorers = new LoreumNFT(
            "Loreum Explorers",
            "LOREUM",
            "ipfs://QmcTBMUiaDQTCt3KT3JLadwKMcBGKTYtiuhopTUafo1h9L/",
            0.05 ether,
            500,
            10000,
            100,
            address(100)
        );

        chamber = new Chamber(address(Explorers), address(LORE));
        USD = new MockERC20("US Dollar", "USD", address(chamber));

        vm.deal(address(chamber), 100 ether);
        vm.label(bones, "Bones");
        vm.label(coconut, "Coconut");
        vm.label(hurricane, "Hurricane");
        vm.label(jack, "Jack");
        vm.label(danny, "Danny");
        vm.label(shifty, "Shifty");
        vm.label(blackbeard, "Blackbeard");

    }

    event Log(uint8[5], uint256[5]);

    function helperLogger() public {
        // for logging out the leaderboard
        (uint8[5] memory ranksTop, uint256[5] memory stakesTop) = chamber.viewRankings();
        emit Log(ranksTop, stakesTop);
    }

    // helper to Mint tokenIds to each Lorian and stake LORE amounts to Chamber
    function chamberSetup () public {
        
        // setup the chamber with stake amounts of 33k
        // from each of the team members above
        for (uint8 i = 0; i <= lorians.length - 1; i++) {
            vm.deal(lorians[i], 100 ether);
            vm.prank(address(100));
            LORE.transfer(lorians[i], 33333 ether);
            vm.startPrank(lorians[i]);
            Explorers.publicMint{ value: 0.05 ether }(1);
            LORE.approve(address(chamber), LORE.balanceOf(lorians[i]));
            chamber.stake(LORE.balanceOf(lorians[i]), i + 1);
            vm.stopPrank();
        }

        helperLogger();
    }

    function test_ProposalCycle_LORE () public {

        chamberSetup();

        /**  @dev transaction lifecycle tests
        * 1. nft holder should be able to create a proposal
        * 2. nft holder without stake should not be able to approve transaction
        * 3. nft holder should not be able to approve transaction using unowned tokenId
        * 4. nft holder should not be able to approve if not a leader
        * 5. Leaders should be able to approve transaction
        * 6. Quorum of leaders should execute transaction
        * 7. nft hodler with stake allocation after leader snapshot should not be able to approve
        * 8. nft holder that unstaked erc20 should be able to approve
        */
        vm.startPrank(address(1776));

        // mint an nft to 1776
        vm.deal(address(1776), 100 ether);
        Explorers.publicMint{ value: 0.05 ether }(1);
        assertEq(Explorers.balanceOf(address(1776)), 1);

        // 1. nft holder should be able to create a proposal
        bytes[] memory dataArray1 = new bytes[](1);
        address[] memory targetArray1 = new address[](1);
        uint256[] memory valueArray1 = new uint256[](1);

        dataArray1[0] = abi.encodeWithSignature("transfer()");
        targetArray1[0] = address(chamber);
        valueArray1[0] = 1 ether;

        chamber.createProposal(targetArray1, valueArray1, dataArray1);
        assertEq(chamber.proposalCount(), 1);

        // 2. nft holder without stake should not be able to approve transaction
        vm.expectRevert();
        chamber.approveProposal(1, 8);

        // 3. nft holder should not be able to approve transaction using unowned tokenId
        vm.expectRevert();
        chamber.approveProposal(1, 5);
 
        vm.stopPrank();

        // transfer ownership of LORE to the chamber
        LORE.transferOwnership(address(chamber));
        assertEq(LORE.owner(), address(chamber));

        uint256 votes;
        Chamber.State state;
        

        // Create a new proposal for minting LORE to Lorains
        bytes[] memory dataArray = new bytes[](7);
        address[] memory targetArray = new address[](7);
        uint256[] memory valueArray = new uint256[](7);

        uint256 amount = 10000 ether;

        targetArray[0] = address(LORE);
        targetArray[1] = address(LORE);
        targetArray[2] = address(LORE);
        targetArray[3] = address(LORE);
        targetArray[4] = address(LORE);
        targetArray[5] = address(LORE);
        targetArray[6] = address(LORE);

        dataArray[0] = abi.encodeWithSignature("mint(address,uint256)", bones, amount);
        dataArray[1] = abi.encodeWithSignature("mint(address,uint256)", coconut, amount);
        dataArray[2] = abi.encodeWithSignature("mint(address,uint256)", hurricane, amount);
        dataArray[3] = abi.encodeWithSignature("mint(address,uint256)", jack, amount);
        dataArray[4] = abi.encodeWithSignature("mint(address,uint256)", danny, amount);
        dataArray[5] = abi.encodeWithSignature("mint(address,uint256)", shifty, amount);
        dataArray[6] = abi.encodeWithSignature("mint(address,uint256)", blackbeard, amount);

        valueArray[0] = 0;
        valueArray[1] = 0;
        valueArray[2] = 0;
        valueArray[3] = 0;
        valueArray[4] = 0;
        valueArray[5] = 0;
        valueArray[6] = 0;

        vm.startPrank(bones);
        chamber.createProposal(targetArray, valueArray, dataArray);
        assertEq(chamber.proposalCount(), 2);
        (votes, state) = chamber.proposals(2);
        assertEq(votes, 0);
        assertTrue(state == IChamber.State.Initialized);

        // 4. nft holder should not be able to approve if not a leader
        chamber.viewRankings();
        vm.startPrank(blackbeard);
        vm.expectRevert();
        chamber.approveProposal(1, 7);
        vm.stopPrank();
        
        // 5. Leaders should be able to approve transaction
        vm.prank(danny);
        chamber.approveProposal(2, 5);
        (votes, state) = chamber.proposals(2);
        assertEq(votes, 1);
        assertTrue(state == IChamber.State.Initialized);

        vm.prank(bones);
        chamber.approveProposal(2, 1);
        (votes, state) = chamber.proposals(2);
        assertEq(votes, 2);
        assertTrue(state == IChamber.State.Initialized);
        
        // 6. Quorum of leaders should execute proposal
        vm.prank(hurricane);
        chamber.approveProposal(2, 3);
        (votes, state) = chamber.proposals(2);
        assertEq(votes, 3);
        assertTrue(state == IChamber.State.Executed);

        // Lorians should now have the amount of LORE
        for (uint8 i = 0; i <= lorians.length - 1; i++) {
            assertEq(LORE.balanceOf(lorians[i]), amount);
        }

        // 7. nft hodler with stake allocation after snapshot should not be able to approve
        vm.startPrank(bones);
        // stake more LORE to chamber
        LORE.approve(address(chamber), 10000 ether);
        chamber.stake(10000 ether, 1);
        assertEq(chamber.getUserStake(bones, 1), 43333 ether);

        // 8. nft holder that unstaked erc20 should be able to approve
        vm.startPrank(jack);
        chamber.unstake(33333 ether, 4);
        helperLogger();
        chamber.approveProposal(1, 4);
        vm.stopPrank();
    }
}