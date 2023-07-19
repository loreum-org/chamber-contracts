// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test (foundry-rs) imports.
import "../lib/forge-std/src/Test.sol";

// Loreum core contracts.
import "../src/Chamber.sol";
import "../lib/contract-utils/src/MockERC20.sol";
import "../lib/contract-utils/src/MockNFT.sol";
import "../lib/loreum-nft/src/LoreumNFT.sol";
import "../lib/loreum-token/src/LoreumToken.sol";

contract test is Test{
    MockERC20 USD;
    LoreumToken LORE;
    LoreumNFT Explorers;
    Chamber chamber;

    address jb = address(1);
    address bones = address(2);
    address coconut = address(3);
    address hurricane = address(4);
    address jack = address(5);
    address danny = address(6);
    address shifty = address(7);

    address[7] lorians = [jb,bones,coconut,hurricane,jack,danny,shifty];

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

        chamber = new Chamber(address(Explorers), address(LORE), 3, 5);
        USD = new MockERC20("US Dollar", "USD", address(chamber));

        vm.deal(address(chamber), 100 ether);
    }
    function chamberSetup() public {
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
    }
    function test_one() public {
        chamberSetup();

        vm.startPrank(jb);
        chamber.unstake(chamber.getUserStakeIndividualNFT(jb,1),1);
        vm.stopPrank();
    }
    function test_two()  public {
        // console.log("Balance of 100: ", LORE.balanceOf(address(100)));
        chamberSetup();

        vm.prank(address(100));
        LORE.transfer(jb, 1000 ether);

        // Mint one more nft
        vm.startPrank(jb);
        Explorers.publicMint{ value: 0.05 ether }(1);
        LORE.approve(address(chamber), LORE.balanceOf(jb));
        chamber.stake(LORE.balanceOf(jb), 8); // Amount and NFT ID
        vm.stopPrank();

        console.log("Stake amount: ",chamber.getUserStakeIndividualNFT(jb,8));
        console.log("Stake amount: ",chamber.getUserStakeIndividualNFT(jb,1));

        // Unstake
        vm.startPrank(jb);
        chamber.unstake(chamber.getUserStakeIndividualNFT(jb,1),1);
        chamber.unstake(chamber.getUserStakeIndividualNFT(jb,8),8);
        vm.stopPrank();
    }
}