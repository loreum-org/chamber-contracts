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
        assertEq(chamber.LeaderboardList(0).stakerAddress, address(0));
        assertEq(chamber.LeaderboardList(0).tokenId, 0);
        assertEq(chamber.LeaderboardList(0).amount, 0);

        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10

        // Check of the index 0 is not empty
        assertEq(chamber.LeaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.LeaderboardList(0).tokenId, 1);
        assertEq(chamber.LeaderboardList(0).amount, 10);

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,10][0][0]
    }

    function test_addMoreTokenByTheSamePerson() public {
        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10
        // Check if the array is updated with the data
        assertEq(chamber.LeaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.LeaderboardList(0).tokenId, 1);
        assertEq(chamber.LeaderboardList(0).amount, 10);

        // Previous amount was 10, now he is adding extra 10 token, which will be 10+10 = 20
        chamber.stakeTokens(1, 10); // NFT ID = 1 and Amount = 10
        assertEq(chamber.LeaderboardList(0).stakerAddress, address(this));
        assertEq(chamber.LeaderboardList(0).tokenId, 1);
        assertEq(chamber.LeaderboardList(0).amount, 20);

        // LeaderBoard = [0][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,10][0][0]
        //                  ⬇
        // LeaderBoard = [this,1,20][0][0]
    }

    function test_secondPersonStakeMoreTokenThanFirstPerson() public {
        chamber.stakeTokens(1, 10);
        assertEq(chamber.LeaderboardList(0).stakerAddress, address(this));

        vm.prank(bones);
        chamber.stakeTokens(2, 20); // NFT ID = 2 and Amount = 20
        assertEq(chamber.LeaderboardList(0).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(1).stakerAddress, address(this));

        vm.prank(jack);
        chamber.stakeTokens(3, 30); // NFT ID = 2 and Amount = 20
        assertEq(chamber.LeaderboardList(0).stakerAddress, jack);
        assertEq(chamber.LeaderboardList(1).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(2).stakerAddress, address(this));

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
        assertEq(chamber.LeaderboardList(0).stakerAddress, jack);

        // address(this) got out of the leaderboard
        vm.prank(jb);
        chamber.stakeTokens(4, 40);
        assertEq(chamber.LeaderboardList(0).stakerAddress, jb);

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

        assertEq(chamber.LeaderboardList(0).stakerAddress, jack);
        assertEq(chamber.LeaderboardList(1).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(2).stakerAddress, address(this));

        // jack unstake amount 11, so he sould remian only 19
        // which is less than bones
        vm.prank(jack);
        chamber.unstakeTokens(3, 11);

        assertEq(chamber.LeaderboardList(0).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(1).stakerAddress, jack);
        assertEq(chamber.LeaderboardList(2).stakerAddress, address(this));

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

        assertEq(chamber.LeaderboardList(0).stakerAddress, jack);
        assertEq(chamber.LeaderboardList(1).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(2).stakerAddress, address(this));

        // jack unstake all amount, so he sould be remove from the leaderboard
        vm.prank(jack);
        chamber.unstakeTokens(3, 30);

        assertEq(chamber.LeaderboardList(0).stakerAddress, bones);
        assertEq(chamber.LeaderboardList(1).stakerAddress, address(this));
        assertEq(chamber.LeaderboardList(2).stakerAddress, address(0));

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

        assertEq(chamber.MemberList(0).stakerAddress, address(this));

        vm.prank(bob);
        chamber.stakeTokens(5, 40);

        assertEq(chamber.MemberList(0).stakerAddress, address(this));
        assertEq(chamber.MemberList(1).stakerAddress, jb);

        vm.prank(bones);
        chamber.unstakeTokens(2, 20);

        assertEq(chamber.MemberList(0).stakerAddress, address(this));

        assertEq(chamber.LeaderboardList(2).stakerAddress, jb);

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

    // function test_addMoreTokensByDifferentPerson() public {
    //     uint256 stakeAmount1 = 100;
    //     vm.prank(address(1));
    //     chamber.stakeTokens(1, 100);

    //     StakeLeadersBoard.Staker memory one = chamber.LeaderboardList(1);

    //     uint256 stakeAmount2 = 200;
    //     vm.prank(address(2));
    //     chamber.stakeTokens(1, 200);

    //     StakeLeadersBoard.Staker memory two = chamber.LeaderboardList(1);

    //     require(one.amount + two.amount == stakeAmount1 + stakeAmount2);

    //     // The stake for tokenId is not accumulated
    // }

    function test_quick() public {
        vm.prank(address(1));
        chamber.stakeTokens(1, 100);

        vm.prank(address(1));
        chamber.stakeTokens(1, 100);

        uint256 amount = chamber.getStakerAmount(address(1), 1);

        assert(amount == 200);
    }

    function test_memberAddMoreAmount() public {
        chamber.stakeTokens(1, 10); // M1
        chamber.stakeTokens(2, 20); // M2
        chamber.stakeTokens(3, 30); // M3
        chamber.stakeTokens(4, 40); // L3
        chamber.stakeTokens(5, 50); // L2
        chamber.stakeTokens(6, 60); // L1

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 2);
        assertEq(chamber.MemberList(2).tokenId, 3);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 20);
        assertEq(chamber.MemberList(2).amount, 30);

        chamber.stakeTokens(7, 25);

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 2);
        assertEq(chamber.MemberList(2).tokenId, 7);
        assertEq(chamber.MemberList(3).tokenId, 3);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 20);
        assertEq(chamber.MemberList(2).amount, 25);
        assertEq(chamber.MemberList(3).amount, 30);
    }

    function test_memberUnstakeSomeAmount() public {
        chamber.stakeTokens(1, 10);
        chamber.stakeTokens(2, 20);
        chamber.stakeTokens(3, 30);
        chamber.stakeTokens(4, 40);
        chamber.stakeTokens(5, 50);
        chamber.stakeTokens(6, 60);

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 2);
        assertEq(chamber.MemberList(2).tokenId, 3);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 20);
        assertEq(chamber.MemberList(2).amount, 30);

        chamber.unstakeTokens(3, 11);

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 3);
        assertEq(chamber.MemberList(2).tokenId, 2);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 19);
        assertEq(chamber.MemberList(2).amount, 20);
    }

    function test_memberUnstakeAllAmount() public {
        chamber.stakeTokens(1, 10);
        chamber.stakeTokens(2, 20);
        chamber.stakeTokens(3, 30);
        chamber.stakeTokens(4, 40);
        chamber.stakeTokens(5, 50);
        chamber.stakeTokens(6, 60);

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 2);
        assertEq(chamber.MemberList(2).tokenId, 3);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 20);
        assertEq(chamber.MemberList(2).amount, 30);

        chamber.unstakeTokens(2, 20);

        assertEq(chamber.MemberList(0).tokenId, 1);
        assertEq(chamber.MemberList(1).tokenId, 3);
        //assertEq(chamber.MemberList(2).tokenId, 2);

        assertEq(chamber.MemberList(0).amount, 10);
        assertEq(chamber.MemberList(1).amount, 30);
    }

    function test_swap() public {
        chamber.stakeTokens(1, 10); // M1
        chamber.stakeTokens(2, 20); // M2
        chamber.stakeTokens(3, 30); // M3
        chamber.stakeTokens(4, 40); // L3
        chamber.stakeTokens(5, 50); // L2
        chamber.stakeTokens(6, 60); // L1

        assertEq(chamber.LeaderboardList(2).tokenId, 4);
        assertEq(chamber.MemberList(2).tokenId, 3);

        chamber.stakeTokens(3, 11);

        assertEq(chamber.LeaderboardList(2).tokenId, 3);
        assertEq(chamber.MemberList(2).tokenId, 4);
    }
}
