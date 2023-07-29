// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StakeLeadersBoard} from "../src/Chamber@0.3.sol";

contract TestLeaderBoardLogic is Test {
    function setUp() public {
        chamber = new Chamber(3);
    }
    function test_three_checkGasSameNFT()  returns () {
        chamber.stakeTokens(1, 10);
        chamber.stakeTokens(1, 20);
        chamber.stakeTokens(1, 30);
        chamber.stakeTokens(1, 40);
        chamber.stakeTokens(1, 50);
        chamber.stakeTokens(1, 50);
        chamber.stakeTokens(1, 50);
        chamber.stakeTokens(1, 50);
        chamber.stakeTokens(1, 50);
        chamber.stakeTokens(1, 50);
    }
    function test_three_checkGasDifferentfNFT()public {
        chamber.stakeTokens(1, 10);
        chamber.stakeTokens(2, 20);
        chamber.stakeTokens(3, 30);
        chamber.stakeTokens(4, 40);
        chamber.stakeTokens(5, 50);
        chamber.stakeTokens(6, 50);
        chamber.stakeTokens(7, 50);
        chamber.stakeTokens(8, 50);
        chamber.stakeTokens(9, 50);
        chamber.stakeTokens(10, 50);
    }
}