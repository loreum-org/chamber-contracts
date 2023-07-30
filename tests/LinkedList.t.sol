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
    Chamber Treasury;
        
    uint16 leaders = 8;
    uint16 quorum = 5;

    event Log(uint);
    event Log(uint256[2]);
    event Log(uint256[]);

    function setUp() public {

        NFT = new MockNFT("Mock NFT", "MNFT", address(this));
        MUSD = new MockERC20("Mock Stable Dollar", "MUSD", address(this));
        Treasury = new Chamber(address(NFT), address(MUSD), quorum, leaders);
    }

    function helperLogger() public {
        (uint[] memory ranksTop, uint[] memory stakesTop) = Treasury.viewRankings();
        (uint[] memory ranksAll, uint[] memory stakesAll) = Treasury.viewRankingsAll();
        emit Log(ranksTop);
        emit Log(stakesTop);
        emit Log(ranksAll);
        emit Log(stakesAll);
    }

    function test_LinkedList_init() public {
        assertEq(Treasury.stakingToken(), address(MUSD));
        assert(!Treasury.isInitialized());
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
        
        // Approve LoreumChamber contract for "amt".
        MUSD.approve(address(Treasury), 10_000_000_000 ether);

        {
            uint256 amt1 = (uint256(random1) % (10_000_000 ether)) / 10;
            uint256 amt2 = (uint256(random2) % (10_000_000 ether)) / 10;
            uint256 amt3 = (uint256(random3) % (10_000_000 ether)) / 10;
            Treasury.stake(amt1 + 1, 1);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt2 + 1, 2);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt3 + 1, 3);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt4 = (uint256(random4) % (10_000_000 ether)) / 10;
            uint256 amt5 = (uint256(random5) % (10_000_000 ether)) / 10;
            uint256 amt6 = (uint256(random6) % (10_000_000 ether)) / 10;
            Treasury.stake(amt4 + 1, 4);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt5 + 1, 5);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt6 + 1, 6);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt7 = (uint256(random7) % (10_000_000 ether)) / 10;
            uint256 amt8 = (uint256(random8) % (10_000_000 ether)) / 10;
            uint256 amt9 = (uint256(random9) % (10_000_000 ether)) / 10;
            Treasury.stake(amt7 + 1, 7);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt8 + 1, 8);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt9 + 1, 9);
            Treasury.helperView();
            helperLogger();
        }

        {
            uint256 amt9 = Treasury.totalStake(1) % (uint256(random9) + 1);
            uint256 amt8 = Treasury.totalStake(2) % (uint256(random8) + 1);
            uint256 amt7 = Treasury.totalStake(3) % (uint256(random7) + 1);
            Treasury.unstake(amt9 != 0 ? amt9 : amt9 + 1, 1);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt8 != 0 ? amt8 : amt8 + 1, 2);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt7 != 0 ? amt7 : amt7 + 1, 3);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt6 = Treasury.totalStake(4) % (uint256(random6) + 1);
            uint256 amt5 = Treasury.totalStake(5) % (uint256(random5) + 1);
            uint256 amt4 = Treasury.totalStake(6) % (uint256(random4) + 1);
            Treasury.unstake(amt6 != 0 ? amt6 : amt6 + 1, 4);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt5 != 0 ? amt5 : amt5 + 1, 5);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt4 != 0 ? amt4 : amt4 + 1, 6);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt3 = Treasury.totalStake(7) % (uint256(random3) + 1);
            uint256 amt2 = Treasury.totalStake(8) % (uint256(random2) + 1);
            uint256 amt1 = Treasury.totalStake(9) % (uint256(random1) + 1);
            Treasury.unstake(amt3 != 0 ? amt3 : amt3 + 1, 7);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt2 != 0 ? amt2 : amt2 + 1, 8);
            Treasury.helperView();
            helperLogger();
            Treasury.unstake(amt1 != 0 ? amt1 : amt1 + 1, 9);
            Treasury.helperView();
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
        MUSD.approve(address(Treasury), 10_000_000_000 ether);

        {
            uint256 amt1 = (uint256(random1) % (10_000_000 ether)) / 10;
            uint256 amt2 = (uint256(random2) % (10_000_000 ether)) / 10;
            uint256 amt3 = (uint256(random3) % (10_000_000 ether)) / 10;
            Treasury.stake(amt1 + 1, 1);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt2 + 1, 2);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt3 + 1, 3);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt4 = (uint256(random4) % (10_000_000 ether)) / 10;
            uint256 amt5 = (uint256(random5) % (10_000_000 ether)) / 10;
            uint256 amt6 = (uint256(random6) % (10_000_000 ether)) / 10;
            Treasury.stake(amt4 + 1, 4);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt5 + 1, 5);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt6 + 1, 6);
            Treasury.helperView();
            helperLogger();
        }
        {
            uint256 amt7 = (uint256(random7) % (10_000_000 ether)) / 10;
            uint256 amt8 = (uint256(random8) % (10_000_000 ether)) / 10;
            uint256 amt9 = (uint256(random9) % (10_000_000 ether)) / 10;
            Treasury.stake(amt7 + 1, 7);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt8 + 1, 8);
            Treasury.helperView();
            helperLogger();
            Treasury.stake(amt9 + 1, 9);
            Treasury.helperView();
            helperLogger();
        }

        helperLogger();

    }

}
