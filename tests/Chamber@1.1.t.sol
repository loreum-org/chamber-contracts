// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StakeLeadersBoard} from "../src/Chamber@1.1.sol";

contract TestLeaderBoardLogic is Test {
    StakeLeadersBoard chamber;
    address jb = makeAddr("jb");
    address bones = makeAddr("Bones");
    address jack = makeAddr("Jack");
    address bob = makeAddr("bob");

    function setUp() public {
        chamber = new StakeLeadersBoard();
    }

    function test_addNewPerson() public {
        // Check of the index 0 is empty
        assertEq(chamber.leaderboardList(0).stakerAddress, address(0));
        assertEq(chamber.leaderboardList(0).tokenId, 0);
        assertEq(chamber.leaderboardList(0).amount, 0);

        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10

        // Check of the index 0 is not empty
        assertEq(chamber.leaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.leaderboardList(0).tokenId, 1);
        assertEq(chamber.leaderboardList(0).amount, 10);

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,10][0][0]
    }

    function test_addMoreTokenByTheSamePerson() public {
        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10
        // Check if the array is updated with the data
        assertEq(chamber.leaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.leaderboardList(0).tokenId, 1);
        assertEq(chamber.leaderboardList(0).amount, 10);

        // Previous amount was 10, now he is adding extra 10 token, which will be 10+10 = 20
        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10
        assertEq(chamber.leaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.leaderboardList(0).tokenId, 1);
        assertEq(chamber.leaderboardList(0).amount, 20);

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,10][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,20][0][0]
    }

    function test_secondPersonStakeMoreTokenThanFirstPerson() public {
        chamber.stakeTokens(1, 10);
        assertEq(chamber.leaderboardList(0).stakerAddress, address(this));

        vm.prank(bones);
        chamber.stakeTokens(2, 20); // NFT ID = 2 and Amount = 20
        assertEq(chamber.leaderboardList(0).stakerAddress, bones);
        assertEq(chamber.leaderboardList(1).stakerAddress, address(this));

        vm.prank(jack);
        chamber.stakeTokens(3, 30); // NFT ID = 2 and Amount = 20
        assertEq(chamber.leaderboardList(0).stakerAddress, jack);
        assertEq(chamber.leaderboardList(1).stakerAddress, bones);
        assertEq(chamber.leaderboardList(2).stakerAddress, address(this));

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,10][0][0]
        //                  ⬇
        // LeaderBoard = [bones,2,20][this,1,10][0]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][this,1,10]
    }

    function test_FourthPersonStackTheHighestAmount() public {
        vm.prank(address(this));
        chamber.stakeTokens(1, 10);

        vm.prank(bones);
        chamber.stakeTokens(2, 20);

        vm.prank(jack);
        chamber.stakeTokens(3, 30);

        // Currently jack is the highest staker and the leaderboard is full
        assertEq(chamber.leaderboardList(0).stakerAddress, jack);

        // address(this) got out of the leaderboard
        vm.prank(jb);
        chamber.stakeTokens(4, 40);
        assertEq(chamber.leaderboardList(0).stakerAddress, jb);

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][this,1,10]
        //                  ⬇
        // LeaderBoard = [jb,4,40][jack,3,30][bones,2,20]
    }

    function test_personUnstakeSomeAmount() public {
        vm.prank(address(this));
        chamber.stakeTokens(1, 10);

        vm.prank(bones);
        chamber.stakeTokens(2, 20);

        vm.prank(jack);
        chamber.stakeTokens(3, 30);

        assertEq(chamber.leaderboardList(0).stakerAddress, jack);
        assertEq(chamber.leaderboardList(1).stakerAddress, bones);
        assertEq(chamber.leaderboardList(2).stakerAddress, address(this));

        // jack unstake amount 11, so he sould remian only 19
        // which is less than bones
        vm.prank(jack);
        chamber.unstakeTokens(3, 11);

        assertEq(chamber.leaderboardList(0).stakerAddress, bones);
        assertEq(chamber.leaderboardList(1).stakerAddress, jack);
        assertEq(chamber.leaderboardList(2).stakerAddress, address(this));

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][this,1,10]
        //                  ⬇
        // LeaderBoard = [bones,2,20][jack,3,19][this,1,10]
    }

    function test_personUnstakeAllAmount() public {
        vm.prank(address(this));
        chamber.stakeTokens(1, 10);

        vm.prank(bones);
        chamber.stakeTokens(2, 20);

        vm.prank(jack);
        chamber.stakeTokens(3, 30);

        assertEq(chamber.leaderboardList(0).stakerAddress, jack);
        assertEq(chamber.leaderboardList(1).stakerAddress, bones);
        assertEq(chamber.leaderboardList(2).stakerAddress, address(this));

        // jack unstake all amount, so he sould be remove from the leaderboard
        vm.prank(jack);
        chamber.unstakeTokens(3, 30);

        assertEq(chamber.leaderboardList(0).stakerAddress, bones);
        assertEq(chamber.leaderboardList(1).stakerAddress, address(this));
        assertEq(chamber.leaderboardList(2).stakerAddress, address(0));

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][this,1,10]
        //                  ⬇
        // LeaderBoard = [bones,2,20][this,1,10][0]
    }

    function test_stakeTokensAndAssertMemberList() public {
        vm.prank(address(this));
        chamber.stakeTokens(1, 10);

        vm.prank(bones);
        chamber.stakeTokens(2, 20);

        vm.prank(jack);
        chamber.stakeTokens(3, 30);

        vm.prank(jb);
        chamber.stakeTokens(4, 11);

        assertEq(chamber.MemberList(0).stakerAddress,address(this));

        vm.prank(bob);
        chamber.stakeTokens(5,40);

        assertEq(chamber.MemberList(0).stakerAddress,address(this));
        assertEq(chamber.MemberList(1).stakerAddress,jb);

        vm.prank(bones);
        chamber.unstakeTokens(2,20);

        assertEq(chamber.MemberList(0).stakerAddress,address(this));

        assertEq(chamber.leaderboardList(2).stakerAddress,jb);


        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][this,1,10]
        //                  ⬇
        // LeaderBoard = [jack,3,30][bones,2,20][jb,4,11]
        // Member = [this,1,10]
        //                  ⬇
        // LeaderBoard = [bob,5,40][jack,3,30][bones,2,20]
        // Member = [this,1,10][jb,4,11]
        //                  ⬇
        // LeaderBoard = [bob,5,40][jack,3,30][0]
        // Member = [this,1,10][jb,4,11]
        //                  ⬇
        // LeaderBoard = [bob,5,40][jack,3,30][jb,4,11]
        // Member = [this,1,10]
    }
}
