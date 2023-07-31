// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test (foundry-rs) imports.
import "../lib/forge-std/src/Test.sol";

// Loreum core contracts.
import {Chamber} from "../src/Chamber.sol";
import "../lib/contract-utils/src/MockERC20.sol";
import "../lib/contract-utils/src/MockNFT.sol";

import { TestUtilities } from "../lib/contract-utils/src/TestUtilities.sol";

contract LinkedListTest is Test, TestUtilities {

    MockERC20 MUSD;
    MockNFT NFT;
    Chamber chamber;
        
    uint16 leaders = 8;
    uint16 quorum = 5;

    event Log(uint);
    event Log(uint256[2]);
    event Log(uint256[]);

    function setUp() public {

        NFT = new MockNFT("Mock NFT", "MNFT", address(this));
        MUSD = new MockERC20("Mock Stable Dollar", "MUSD", address(this));
        chamber = new Chamber(address(NFT), address(MUSD), quorum, leaders);
    }

    function helperLogger() public {
        (uint[] memory ranksTop, uint[] memory stakesTop) = chamber.viewRankings();
        (uint[] memory ranksAll, uint[] memory stakesAll) = chamber.viewRankingsAll();
        emit Log(ranksTop);
        emit Log(stakesTop);
        emit Log(ranksAll);
        emit Log(stakesAll);
    }

    function test_LinkedList_init() public {
        assertEq(chamber.stakingToken(), address(MUSD));
        assert(!chamber.isInitialized());
    }

    function test_LinkedList_unstake(
        uint96 random1,
        uint96 random2,
        uint96 random3,
        uint96 random4,
        uint96 random5,
        uint96 random6,
        uint96 random7,
        uint96 random8,
        uint96 random9
    ) public {

        vm.assume(random1 > 0);
        vm.assume(random2 > 0);
        vm.assume(random3 > 0);
        vm.assume(random4 > 0);
        vm.assume(random5 > 0);
        vm.assume(random6 > 0);
        vm.assume(random7 > 0);
        vm.assume(random8 > 0);
        vm.assume(random9 > 0);
        
        // Approve LoreumChamber contract for "amt".
        MUSD.approve(address(chamber), 10_000_000_000 ether);

        {
            uint256 amt1 = (uint256(random1) % (10_000_000 ether)) / 10;
            uint256 amt2 = (uint256(random2) % (10_000_000 ether)) / 10;
            uint256 amt3 = (uint256(random3) % (10_000_000 ether)) / 10;
            chamber.stake(amt1 + 1, 1);
            
            helperLogger();
            chamber.stake(amt2 + 1, 2);
            
            helperLogger();
            chamber.stake(amt3 + 1, 3);
            
            helperLogger();
        }
        {
            uint256 amt4 = (uint256(random4) % (10_000_000 ether)) / 10;
            uint256 amt5 = (uint256(random5) % (10_000_000 ether)) / 10;
            uint256 amt6 = (uint256(random6) % (10_000_000 ether)) / 10;
            chamber.stake(amt4 + 1, 4);
            
            helperLogger();
            chamber.stake(amt5 + 1, 5);
            
            helperLogger();
            chamber.stake(amt6 + 1, 6);
            
            helperLogger();
        }
        {
            uint256 amt7 = (uint256(random7) % (10_000_000 ether)) / 10;
            uint256 amt8 = (uint256(random8) % (10_000_000 ether)) / 10;
            uint256 amt9 = (uint256(random9) % (10_000_000 ether)) / 10;
            chamber.stake(amt7 + 1, 7);
            
            helperLogger();
            chamber.stake(amt8 + 1, 8);
            
            helperLogger();
            chamber.stake(amt9 + 1, 9);
            
            helperLogger();
        } 

    }

    function test_LinkedList_stake(
        uint96 random1,
        uint96 random2,
        uint96 random3,
        uint96 random4,
        uint96 random5,
        uint96 random6,
        uint96 random7,
        uint96 random8,
        uint96 random9
    ) public {
        
        // Approve LoreumChamber contract for "amt".
        MUSD.approve(address(chamber), 10_000_000_000 ether);

        {
            uint256 amt1 = (uint256(random1) % (10_000_000 ether)) / 10;
            uint256 amt2 = (uint256(random2) % (10_000_000 ether)) / 10;
            uint256 amt3 = (uint256(random3) % (10_000_000 ether)) / 10;
            chamber.stake(amt1 + 1, 1);
            
            helperLogger();
            chamber.stake(amt2 + 1, 2);
            
            helperLogger();
            chamber.stake(amt3 + 1, 3);
            
            helperLogger();
        }
        {
            uint256 amt4 = (uint256(random4) % (10_000_000 ether)) / 10;
            uint256 amt5 = (uint256(random5) % (10_000_000 ether)) / 10;
            uint256 amt6 = (uint256(random6) % (10_000_000 ether)) / 10;
            chamber.stake(amt4 + 1, 4);
            
            helperLogger();
            chamber.stake(amt5 + 1, 5);
            
            helperLogger();
            chamber.stake(amt6 + 1, 6);
            
            helperLogger();
        }
        {
            uint256 amt7 = (uint256(random7) % (10_000_000 ether)) / 10;
            uint256 amt8 = (uint256(random8) % (10_000_000 ether)) / 10;
            uint256 amt9 = (uint256(random9) % (10_000_000 ether)) / 10;
            chamber.stake(amt7 + 1, 7);
            
            helperLogger();
            chamber.stake(amt8 + 1, 8);
            
            helperLogger();
            chamber.stake(amt9 + 1, 9);
            
            helperLogger();
        }

        helperLogger();

    }

}
