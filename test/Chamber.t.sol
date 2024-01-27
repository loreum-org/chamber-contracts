// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import { Registry } from "../src/Registry.sol";
import { Chamber } from "../src/Chamber.sol";

import { DeployRegistry } from "../test/utils/DeployRegistry.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";
import { IChamber } from "../src/interfaces/IChamber.sol";
import { MockERC20 } from "../lib/contract-utils/src/MockERC20.sol";
import { MockNFT } from "../lib/contract-utils/src/MockNFT.sol";
import { DenyTransactionGuard } from "../src/example/DenyTransactionGuard.sol";

contract ChamberTest is Test {

    MockERC20 USD;
    MockERC20 mERC20;
    MockNFT mNFT;
    IChamber chamber;
    IRegistry registry;
    DenyTransactionGuard guard;

    address registryProxyAddr;
    address chamberProxyAddr;

    function getSignature(uint8 _proposalId, uint8 _tokenId, uint256 _privateKey)public view returns(bytes memory){
        bytes32 digest = chamber.constructMessageHash(_proposalId,_tokenId);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); 
        return signature;
    }

    function setUp() public {
        
        mERC20 = new MockERC20("MockERC20", "mERC20", vm.addr(1));
        mNFT = new MockNFT("MockNFT", "mNFT", vm.addr(1));
        // mERC20 = new MockERC20("MockERC20", "mERC20", address(this));
        // mNFT = new MockNFT("MockNFT", "mNFT", address(this));

        DeployRegistry registryDeployer = new DeployRegistry();
        registryProxyAddr = registryDeployer.deploy(address(this));
        chamberProxyAddr = IRegistry(registryProxyAddr).deploy(address(mNFT), address(mERC20));
        chamber = IChamber(chamberProxyAddr);

        USD = new MockERC20("US Dollar", "USD", address(chamber));
        vm.deal(address(chamber), 100 ether);
    }

    function promoteMembers() public {
        
        vm.startPrank(vm.addr(1));
        // Approve Chamber for large amount of LORE
        mERC20.approve(address(chamber), 10_000_000_000 ether);

        chamber.promote(100_000 ether, 1);
        chamber.promote(120_000 ether, 2);
        chamber.promote(50_000 ether, 3);
        chamber.promote(250_000 ether, 4);
        chamber.promote(70_000 ether, 5);

        (uint8[] memory leaders, uint256[] memory delegations) = chamber.getLeaderboard();
        (leaders, delegations);
        vm.stopPrank();
    }

    function testFail_guard()public{
        promoteMembers();
        vm.startPrank(vm.addr(1));

        /**************************************************************
         Create a proposal to set a guard with three blocked addresses.
        ***************************************************************/
        address[] memory blockedAddresses = new address[](3);
        blockedAddresses[0] = vm.addr(11);
        blockedAddresses[1] = vm.addr(12);
        blockedAddresses[2] = vm.addr(13);

        // Deploy the guard
        guard = new DenyTransactionGuard(blockedAddresses, address(chamber));

        bytes[] memory dataArray = new bytes[](1);
        address[] memory targetArray = new address[](1);
        uint256[] memory valueArray = new uint256[](1);

        dataArray[0] = abi.encodeWithSignature("setGuard(address)", guard);
        targetArray[0] = address(chamber);
        valueArray[0] = 0;

        chamber.createProposal(targetArray, valueArray, dataArray);

        chamber.approveProposal(1, 3,getSignature(1,3,1));
        chamber.approveProposal(1, 2,getSignature(1,2,1));

        // Execute Proposal
        chamber.approveProposal(1, 1,getSignature(1,1,1));

        /**************************************************
         Create a proposal to send Ether to two addresses, 
         but one address is in the blocked list address(11).
        ***************************************************/

        bytes[] memory dataArray1 = new bytes[](2);
        address[] memory targetArray1 = new address[](2);
        uint256[] memory valueArray1 = new uint256[](2);

        dataArray1[0] = abi.encodeWithSignature("transfer()");
        dataArray1[1] = abi.encodeWithSignature("transfer()");

        targetArray1[0] = vm.addr(10);
        targetArray1[1] = vm.addr(11); // Address blacklisted

        valueArray1[0] = 10 ether;
        valueArray1[1] = 5 ether;

        chamber.createProposal(targetArray1, valueArray1, dataArray1);

        // Approve Proposal
        chamber.approveProposal(2, 3,getSignature(2,3,1));
        chamber.approveProposal(2, 2,getSignature(2,2,1));

        // Execute Proposal
        chamber.approveProposal(2, 1,getSignature(2,1,1));

        vm.stopPrank();
    }

    function test_Chamber_proposal() public {

        promoteMembers();
        vm.startPrank(vm.addr(1));

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

        chamber.createProposal(targetArray, valueArray, dataArray);

        // Approve Proposal

        chamber.approveProposal(1, 3,getSignature(1,3,1));
        chamber.approveProposal(1, 2,getSignature(1,2,1));

        // Execute Proposal
        chamber.approveProposal(1, 1,getSignature(1,1,1));
        chamber.getLeaderboard();
        vm.stopPrank();
    }

    function test_Chamber_promote (uint256 amount) public {
        deal(address(mERC20), address(33), amount);
        vm.startPrank(address(33));
        mERC20.approve(address(chamber), amount);
        chamber.promote(amount, 5);

        uint256 balance = chamber.accountDelegation(address(33), 5);
        assertEq(balance, amount);

        uint256 totalDelegation = chamber.totalDelegation(5);
        assertEq(totalDelegation, amount);

        vm.stopPrank();
        chamber.getLeaderboard();

    }

    function test_Chamber_demoteToZero() public {
        deal(address(mERC20), address(this), 10_000_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.promote(1_000 ether, 1);
        chamber.demote(1_000 ether, 1);
        chamber.getLeaderboard();
    }

    function test_Chamber_delegationUnchanged() public {
        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.promote(6 ether, 1);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.promote(4 ether, 2);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.promote(2 ether, 3);

        chamber.promote(1, 3);
        chamber.promote(1, 5);

        deal(address(mERC20), address(this), 1_000 ether);
        mERC20.approve(address(chamber), 1_000 ether);
        chamber.promote(2 ether, 5);

        chamber.promote(1, 1);

        chamber.promote(1 ether, 2);
        chamber.promote(1 ether, 7);
        chamber.getLeaderboard();
    }

    function test_Chamber_demote (uint256 amount) public {
        deal(address(mERC20), address(34), amount);
        vm.startPrank(address(34));
        mERC20.approve(address(chamber), amount);
        chamber.promote(amount, 6);

        uint256 balance = chamber.accountDelegation(address(34), 6);
        assertEq(balance, amount);

        uint256 totalDelegation = chamber.totalDelegation(6);
        assertEq(totalDelegation, amount);

        chamber.demote(amount, 6);
        uint256 newBalance = chamber.accountDelegation(address(34), 6);
        assertEq(newBalance, 0);
        
        uint newTotalDelegation = chamber.totalDelegation(6);
        assertEq(newTotalDelegation, 0);
        vm.stopPrank();
        chamber.getLeaderboard();
    }

    function test_Chamber_ethTransfer (uint256 amount) public {
        vm.assume(amount < 100_000_000 ether);
        vm.deal(address(this), amount);
        
        (bool sent,) = address(chamber).call{value: amount}("");
        assertTrue(sent);
        assertEq(address(chamber).balance, amount + 100 ether);
    }

    function test_Chamber_fallback (uint256 amount) public {
        vm.assume(amount < 100_000_000 ether);
        uint256 bal1 = address(chamber).balance;
        (bool sent,) = address(chamber).call{value: amount}("sailMaster()");
        assertTrue(sent);
        uint256 bal2 = address(chamber).balance;
        assertEq(bal1, bal2 - amount);
    }

    function testFail_Chamber_demoteToZeroAndUpdateLeaderboard() public{
        deal(address(mERC20), address(this), 10_000_000 ether);
        mERC20.approve(address(chamber), 15_000 ether);
        chamber.promote(5_000 ether, 5);
        chamber.promote(4_000 ether, 4);
        chamber.promote(3_000 ether, 3);
        chamber.promote(2_000 ether, 2);
        chamber.promote(1_000 ether, 1);

        (uint8[] memory _leaderboard, uint256[] memory _delegations) = chamber.getLeaderboard();
        assertEq(_leaderboard[0], 5);
        assertEq(_leaderboard[1], 4);
        assertEq(_leaderboard[2], 3);
        assertEq(_leaderboard[3], 2);
        assertEq(_leaderboard[4], 1);

        assertEq(_delegations[0], 5_000 ether);
        assertEq(_delegations[1], 4_000 ether);
        assertEq(_delegations[2], 3_000 ether);
        assertEq(_delegations[3], 2_000 ether);
        assertEq(_delegations[4], 1_000 ether);

        chamber.demote(5_000 ether, 5);

        (uint8[] memory _leaderboard2, uint256[] memory _delegations2) = chamber.getLeaderboard();

		// The totalDelegation of tokenId 5 demote to 0
		// but the position did not changed
        assertEq(_leaderboard2[0], 5);
        assertEq(_leaderboard2[1], 4);
        assertEq(_leaderboard2[2], 3);
        assertEq(_leaderboard2[3], 2);
        assertEq(_leaderboard2[4], 1);

        assertEq(_delegations2[0], 0);
        assertEq(_delegations2[1], 4_000 ether);
        assertEq(_delegations2[2], 3_000 ether);
        assertEq(_delegations2[3], 2_000 ether);
        assertEq(_delegations2[4], 1_000 ether);
    }

    function testFail_Chamber_promote_duplicateLeader() public{
        deal(address(mERC20), address(this), 10_000_000 ether);
        mERC20.approve(address(chamber), 15_000 ether);
        chamber.promote(5_000 ether, 5);
        chamber.promote(4_000 ether, 4);
        chamber.promote(3_000 ether, 3);
        chamber.promote(2_000 ether, 2);
        chamber.promote(1_000 ether, 1);

        deal(address(mERC20), address(1), 10_000_000 ether);
        vm.startPrank(address(1));
        mERC20.approve(address(chamber),15_000 ether );
        chamber.promote(4_000 ether, 4);
        
        (uint8[] memory _leaderboard, uint256[] memory _delegations) = chamber.getLeaderboard();

        assertEq(_leaderboard[0], 4);
        assertEq(_leaderboard[1], 5);
        assertEq(_leaderboard[2], 4); // Duplicate
        assertEq(_leaderboard[3], 3);
        assertEq(_leaderboard[4], 2);

        assertEq(_delegations[0], 8_000 ether);
        assertEq(_delegations[1], 5_000 ether);
        assertEq(_delegations[2], 8_000 ether); // Duplicate
        assertEq(_delegations[3], 3_000 ether);
        assertEq(_delegations[4], 2_000 ether);
        vm.stopPrank();
    }
}
