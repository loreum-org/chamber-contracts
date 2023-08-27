// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Chamber } from "../src/Chamber.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { MockList } from "./mocks/MockList.sol";

import { TestUtilities } from "../lib/contract-utils/src/TestUtilities.sol";

contract LinkedListTest is Test, TestUtilities {

    MockERC20 MUSD;
    MockNFT NFT;
    Chamber chamber;
    MockList mockList;
        
    uint8 leaders = 8;
    uint8 quorum = 5;

    event Log(uint);
    event Log(uint256[2]);
    event Log(uint256[]);

    function setUp() public {
        NFT = new MockNFT("Mock NFT", "MNFT", address(this));
        MUSD = new MockERC20("Mock Stable Dollar", "MUSD", address(this));
        chamber = new Chamber(address(NFT), address(MUSD), quorum, leaders);
        mockList = new MockList();
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
        assertEq(chamber.govToken(), address(MUSD));
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

    function test_LinkedList_inList (uint256 amount) public {
        deal(address(MUSD), address(this), amount);
        vm.assume(amount > 0);
        bool resultFalse = chamber.inList(amount);
        assertFalse(resultFalse);

        MUSD.approve(address(chamber), amount);
        chamber.stake(amount, 1);
        bool resultTrue = chamber.inList(1);
        assertTrue(resultTrue);
    }
    
    function test_LinkedList_getData(uint256 amount) public {
        (bool exists, uint prev, uint next) = chamber.getData(1);
        assertFalse(exists);
        assertTrue(prev == 0 && next == 0);
    
        vm.assume(amount > 100);

        deal(address(MUSD), address(this), amount);

        MUSD.approve(address(chamber), amount);
        chamber.stake(amount / 2, 1);
        chamber.stake(amount / 3, 2);

        (exists, prev, next) = chamber.getData(1);
        chamber.viewRankingsAll();
        assertTrue(exists);
        assertTrue(prev == 2 && next == 2);
    }

    function test_LinkedList_getPrev(uint256 amount) public {
        (bool exists, uint prev) = chamber.getPrev(1);
        assertFalse(exists);
        assertTrue(prev == 0);
    
        vm.assume(amount > 100);

        deal(address(MUSD), address(this), amount);

        MUSD.approve(address(chamber), amount);
        chamber.stake(amount / 2, 1);
        chamber.stake(amount / 3, 2);

        (exists, prev) = chamber.getPrev(1);
        chamber.viewRankingsAll();
        assertTrue(exists);
        assertTrue(prev == 2);
    }

    function test_LinkedList_insert() public {
        vm.expectRevert();
        mockList.insertTest(1, 2);
    }

    function test_LinkedList_remove() public {
        vm.expectRevert();
        mockList.removeTest(1);
    }  

}
