// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../lib/forge-std/src/Test.sol";

import { Registry } from "src/Registry.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { Chamber } from "src/Chamber.sol";
import { IChamber } from "src/interfaces/IChamber.sol";
import { DeployRegistry } from "test/utils/DeployRegistry.sol";

import { MockERC20 } from "lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "lib/contract-utils/src/MockNFT.sol";
import { LoreumNFT } from "lib/loreum-nft/src/LoreumNFT.sol";
import { LoreumToken } from "lib/loreum-token/src/LoreumToken.sol";

contract ProposalCycleTest is Test {

    address registryProxyAddr;
    address chamberProxyAddr;

    MockERC20 USD;
    LoreumToken LORE;
    LoreumNFT Explorers;
    IChamber chamber;
    address bones = vm.addr(1);
    address coconut = vm.addr(2);
    address hurricane = vm.addr(3);
    address jack = vm.addr(4);
    address danny = vm.addr(5);
    address shifty = vm.addr(6);
    address blackbeard = vm.addr(7); 

    address[7] lorians = [bones,coconut,hurricane,jack,danny,shifty,blackbeard];

    function setUp() public {
        LORE = new LoreumToken(vm.addr(100), 1000000 ether, 10000000 ether);
        Explorers = new LoreumNFT(
            "Loreum Explorers",
            "LOREUM",
            "ipfs://QmcTBMUiaDQTCt3KT3JLadwKMcBGKTYtiuhopTUafo1h9L/",
            0.05 ether,
            500,
            10000,
            100,
            vm.addr(100)
        );

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(Explorers), address(LORE));
        chamber = IChamber(chamberProxyAddr);

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

    event Log(uint256[], uint256[]);

    function helperLogger() public {
        // for logging out the leaderboard
        (uint256[] memory leaders, uint256[] memory delegation) = chamber.getLeaderboard();
        emit Log(leaders, delegation);
    }

    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    function getSignature(uint256 _proposalId, uint256 _tokenId, uint256 _privateKey)public view returns(bytes memory){
        bytes32 digest = chamber.constructMessageHash(_proposalId,_tokenId);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v); 
        return signature;
    }

    // helper to Mint tokenIds to each Lorian and delegate LORE amounts to Chamber
    function chamberSetup () public {
        
        // setup the chamber with delegations of 33k
        // from each of the team members above
        for (uint256 i = 0; i <= lorians.length - 1; i++) {
            vm.deal(lorians[i], 100 ether);
            vm.prank(vm.addr(100));
            LORE.transfer(lorians[i], 33333 ether);
            vm.startPrank(lorians[i]);
            Explorers.publicMint{ value: 0.05 ether }(1);
            LORE.approve(address(chamber), LORE.balanceOf(lorians[i]));
            chamber.promote(LORE.balanceOf(lorians[i]), i + 1);
            vm.stopPrank();
        }

        helperLogger();
    }

    function test_ProposalCycle_LORE () public {

        chamberSetup();

        /**  @dev transaction lifecycle tests
        * 1. nft holder should be able to create a proposal
        * 2. nft holder without delegation should not be able to approve transaction
        * 3. nft holder should not be able to approve transaction using unowned tokenId
        * 4. nft holder should not be able to approve if not a leader
        * 5. Leaders should be able to approve transaction
        * 6. Quorum of leaders should execute transaction
        * 7. nft hodler promoted after leader snapshot should not be able to approve
        */
        vm.startPrank(vm.addr(1776));

        // mint an nft to 1776
        vm.deal(vm.addr(1776), 100 ether);
        Explorers.publicMint{ value: 0.05 ether }(1);
        assertEq(Explorers.balanceOf(vm.addr(1776)), 1);

        // 1. nft holder should be able to create a proposal
        bytes[] memory dataArray1 = new bytes[](1);
        address[] memory targetArray1 = new address[](1);
        uint256[] memory valueArray1 = new uint256[](1);

        dataArray1[0] = abi.encodeWithSignature("transfer()");
        targetArray1[0] = address(chamber);
        valueArray1[0] = 1 ether;

        chamber.create(targetArray1, valueArray1, dataArray1);
        assertEq(chamber.nonce(), 1);

        // 2. nft holder without delegation should not be able to approve transaction
        bytes memory signature = getSignature(1,8,1776);
        vm.expectRevert();
        chamber.approve(1, 8,signature);

        // 3. nft holder should not be able to approve transaction using unowned tokenId
        bytes memory signature1 = getSignature(1,5,1776);
        vm.expectRevert();
        chamber.approve(1, 5,signature1);
 
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
        chamber.create(targetArray, valueArray, dataArray);
        assertEq(chamber.nonce(), 2);
        (votes, state) = chamber.proposal(2);
        assertEq(votes, 0);
        assertTrue(state == IChamber.State.Initialized);

        // 4. nft holder should not be able to approve if not a leader
        chamber.getLeaderboard();
        vm.startPrank(blackbeard);
        bytes memory signature2 = getSignature(1,7,7);
        vm.expectRevert();
        chamber.approve(1, 7,signature2);
        vm.stopPrank();
        
        // 5. Leaders should be able to approve transaction
        vm.startPrank(danny);
        chamber.approve(2, 5,getSignature(2,5,5));
        vm.stopPrank();
        (votes, state) = chamber.proposal(2);
        assertEq(votes, 1);
        assertTrue(state == IChamber.State.Initialized);

        vm.startPrank(bones);
        chamber.approve(2, 1,getSignature(2,1,1));
        vm.stopPrank();
        (votes, state) = chamber.proposal(2);
        assertEq(votes, 2);
        assertTrue(state == IChamber.State.Initialized);

        // Executing the second proposal requires prior execution of the first proposal.       
        vm.startPrank(bones);
        chamber.approve(1, 1,getSignature(1,1,1));
        vm.stopPrank();
        vm.startPrank(coconut);
        chamber.approve(1, 2,getSignature(1,2,2));
        vm.stopPrank();
        vm.startPrank(hurricane);
        chamber.approve(1, 3,getSignature(1,3,3));
        vm.stopPrank();
        vm.startPrank(bones);
        chamber.execute(1, 1,getSignature(1,1,1));
        vm.stopPrank();
        
        // 6. Quorum of leaders should execute proposal
        vm.startPrank(hurricane);
        chamber.approve(2, 3,getSignature(2,3,3));
        
        // Execute Proposal
        chamber.execute(2,3,getSignature(2,3,3));
        vm.stopPrank();

        (votes, state) = chamber.proposal(2);
        assertEq(votes, 3);
        assertTrue(state == IChamber.State.Executed);

        // Lorians should now have the amount of LORE
        for (uint256 i = 0; i <= lorians.length - 1; i++) {
            assertEq(LORE.balanceOf(lorians[i]), amount);
        }

        // 7. nft hodler promoted after snapshot should not be able to approve
        vm.startPrank(bones);
        // promote more LORE to chamber
        LORE.approve(address(chamber), 10000 ether);
        chamber.promote(10000 ether, 1);
        assertEq(chamber.accountDelegation(bones, 1), 43333 ether);
    }
}