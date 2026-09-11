// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IWallet} from "src/interfaces/IWallet.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract ChamberUpgradeTest is Test {
    Chamber public implementation;
    Chamber public newImplementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    IChamber public chamber;
    Chamber public chamberContract;
    address public chamberAddress;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");

        // Deploy implementations
        implementation = new Chamber();
        newImplementation = new Chamber();

        chamberAddress = address(
            DeployChamber.deployViaFactory(
                address(token),
                address(nft),
                5, // seats
                "Chamber Token",
                "CHMB",
                admin
            )
        );
        chamber = IChamber(chamberAddress);
        chamberContract = Chamber(payable(chamberAddress));

        // Setup users with NFTs and tokens
        _setupUsers();
    }

    function _setupUsers() internal {
        // Mint NFTs to users
        nft.mintWithTokenId(user1, 1);
        nft.mintWithTokenId(user2, 2);
        nft.mintWithTokenId(user3, 3);

        // Mint tokens and deposit to chamber
        uint256 amount = 1000e18;
        token.mint(user1, amount);
        token.mint(user2, amount);
        token.mint(user3, amount);

        vm.startPrank(user1);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user1);
        chamber.delegate(1, amount);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user2);
        chamber.delegate(2, amount);
        vm.stopPrank();

        vm.startPrank(user3);
        token.approve(chamberAddress, amount);
        chamber.deposit(amount, user3);
        chamber.delegate(3, amount);
        vm.stopPrank();
        vm.roll(block.number + 1);
    }

    function test_Chamber_GetProxyAdmin() public view {
        address proxyAdminAddress = chamber.getProxyAdmin();
        assertNotEq(proxyAdminAddress, address(0));

        // Verify it's a ProxyAdmin contract
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        assertEq(proxyAdmin.owner(), chamberAddress);
    }

    function test_Chamber_ProxyAdminOwnership_TransferredToChamber() public view {
        address proxyAdminAddress = chamber.getProxyAdmin();
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Verify chamber owns the ProxyAdmin
        assertEq(proxyAdmin.owner(), chamberAddress);
    }

    function test_Chamber_UpgradeViaTransaction() public {
        // Get current implementation from ERC1967 slot
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address currentImpl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));

        // Encode upgrade call
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        // Submit upgrade transaction as director (user1 with tokenId 1)
        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        // Get transaction ID
        uint256 txId = chamber.getTransactionCount() - 1;

        // Confirm by other directors to reach quorum (need 3 out of 5)
        vm.prank(user2);
        chamber.confirmTransaction(2, txId);

        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        // Verify quorum reached
        (, uint8 confirmations,,,) = chamber.getTransaction(txId);
        assertGe(confirmations, chamber.getQuorum());

        // Execute upgrade transaction
        vm.prank(user1);
        chamber.executeTransaction(1, txId, upgradeData);

        // Verify implementation was upgraded
        address newImpl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));
        assertEq(newImpl, address(newImplementation));
        assertNotEq(newImpl, currentImpl);
    }

    function test_Chamber_UpgradeViaTransaction_ForgottenCalldata_UsesStored() public {
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address currentImpl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));

        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;
        assertEq(chamber.getTransactionCalldata(txId), upgradeData);

        vm.prank(user2);
        chamber.confirmTransaction(2, txId);
        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        // Execute without re-supplying the original bytes (logs / archives unavailable).
        vm.prank(user1);
        chamber.executeTransaction(1, txId, "");

        address newImpl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));
        assertEq(newImpl, address(newImplementation));
        assertNotEq(newImpl, currentImpl);
    }

    function test_Chamber_UpgradeViaTransaction_WrongCalldata_Reverts() public {
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;

        vm.prank(user2);
        chamber.confirmTransaction(2, txId);
        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        bytes memory wrongData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(implementation), "");

        vm.prank(user1);
        vm.expectRevert(IWallet.DataHashMismatch.selector);
        chamber.executeTransaction(1, txId, wrongData);
    }

    function test_Chamber_UpgradeViaTransaction_WithInitialization() public {
        // Create a new implementation with a different version
        Chamber v2Implementation = new Chamber();

        // Upgrade without initialization data (can't reinitialize already initialized contract)
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(v2Implementation), "");

        // Submit upgrade transaction
        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;

        // Confirm by directors
        vm.prank(user2);
        chamber.confirmTransaction(2, txId);

        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        // Execute upgrade
        vm.prank(user1);
        chamber.executeTransaction(1, txId, upgradeData);

        // Verify upgrade succeeded
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address newImpl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));
        assertEq(newImpl, address(v2Implementation));
    }

    function test_Chamber_UpgradeViaTransaction_NonDirector_Reverts() public {
        address nonDirector = makeAddr("nonDirector");

        // Mint NFT to nonDirector but don't delegate, so they're not a director
        nft.mintWithTokenId(nonDirector, 999);

        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        // Non-director cannot submit upgrade transaction (tokenId 999 not in top seats)
        vm.prank(nonDirector);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(999, chamberAddress, 0, upgradeData);
    }

    function test_Chamber_UpgradeViaTransaction_InvalidSelector_Reverts() public {
        // Try to submit transaction to chamber with wrong selector
        bytes memory wrongData =
            abi.encodeWithSelector(bytes4(keccak256("wrongFunction()")), address(newImplementation));

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitTransaction(1, chamberAddress, 0, wrongData);
    }

    function test_Chamber_UpgradeViaTransaction_NotEnoughConfirmations_Reverts() public {
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        // Submit upgrade transaction
        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;

        // Try to execute without enough confirmations
        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeTransaction(1, txId, upgradeData);
    }

    function test_Chamber_UpgradeViaTransaction_ZeroImplementation_Reverts() public {
        bytes memory upgradeData = abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(0), "");

        // Submit upgrade transaction
        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;

        // Confirm by directors
        vm.prank(user2);
        chamber.confirmTransaction(2, txId);

        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        // Execute should revert due to zero implementation
        // The error is wrapped in TransactionFailed, so we check for that
        vm.prank(user1);
        vm.expectRevert(); // TransactionFailed with ZeroAddress error inside
        chamber.executeTransaction(1, txId, upgradeData);
    }

    function test_Chamber_UpgradeDirectly_Unauthorized_Reverts() public {
        // Try to upgrade directly without going through transaction system
        // This MUST revert because upgradeImplementation checks for msg.sender == address(this)

        address currentImpl = address(
            uint160(
                uint256(
                    vm.load(
                        chamberAddress,
                        bytes32(uint256(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
                    )
                )
            )
        );

        // Call directly - this will revert
        vm.expectRevert(IChamber.NotAuthorized.selector);
        chamber.upgradeImplementation(address(newImplementation), "");

        // Verify upgrade did NOT happen
        address newImpl = address(
            uint160(
                uint256(
                    vm.load(
                        chamberAddress,
                        bytes32(uint256(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
                    )
                )
            )
        );
        assertEq(newImpl, currentImpl, "Implementation should remain unchanged");
    }

    function test_Chamber_UpgradePreservesState() public {
        // Store some state before upgrade
        uint256 initialSeats = chamber.getSeats();
        string memory initialName = chamber.name();
        string memory initialSymbol = chamber.symbol();
        address initialAsset = chamber.asset();
        address initialNft = address(chamberContract.nft());

        // Get user balances
        uint256 user1Balance = chamber.balanceOf(user1);
        uint256 user2Balance = chamber.balanceOf(user2);

        // Perform upgrade
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);

        uint256 txId = chamber.getTransactionCount() - 1;

        vm.prank(user2);
        chamber.confirmTransaction(2, txId);

        vm.prank(user3);
        chamber.confirmTransaction(3, txId);

        vm.prank(user1);
        chamber.executeTransaction(1, txId, upgradeData);

        // Verify state is preserved
        assertEq(chamber.getSeats(), initialSeats);
        assertEq(chamber.name(), initialName);
        assertEq(chamber.symbol(), initialSymbol);
        assertEq(chamber.asset(), initialAsset);
        assertEq(address(chamberContract.nft()), initialNft);
        assertEq(chamber.balanceOf(user1), user1Balance);
        assertEq(chamber.balanceOf(user2), user2Balance);
    }

    function test_Chamber_UpgradeBatchTransactions() public {
        // Create two new implementations
        Chamber impl1 = new Chamber();
        Chamber impl2 = new Chamber();

        // Prepare upgrade data for both
        bytes[] memory upgradeDataArray = new bytes[](2);
        upgradeDataArray[0] = abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(impl1), "");
        upgradeDataArray[1] = abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(impl2), "");

        address[] memory targets = new address[](2);
        targets[0] = chamberAddress;
        targets[1] = chamberAddress;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        // Submit batch transactions
        vm.prank(user1);
        chamber.submitBatchTransactions(1, targets, values, upgradeDataArray);

        // Confirm both transactions
        uint256[] memory txIds = new uint256[](2);
        txIds[0] = chamber.getTransactionCount() - 2;
        txIds[1] = chamber.getTransactionCount() - 1;

        vm.prank(user2);
        chamber.confirmBatchTransactions(2, txIds);

        vm.prank(user3);
        chamber.confirmBatchTransactions(3, txIds);

        // Execute first upgrade
        uint256[] memory firstTx = new uint256[](1);
        firstTx[0] = txIds[0];
        bytes[] memory firstData = new bytes[](1);
        firstData[0] = upgradeDataArray[0];
        vm.prank(user1);
        chamber.executeBatchTransactions(1, firstTx, firstData);

        // Verify first upgrade
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address impl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));
        assertEq(impl, address(impl1));

        // Execute second upgrade
        uint256[] memory secondTx = new uint256[](1);
        secondTx[0] = txIds[1];
        bytes[] memory secondData = new bytes[](1);
        secondData[0] = upgradeDataArray[1];
        vm.prank(user1);
        chamber.executeBatchTransactions(1, secondTx, secondData);

        // Verify second upgrade
        impl = address(uint160(uint256(vm.load(chamberAddress, implSlot))));
        assertEq(impl, address(impl2));
    }

    /**
     * @notice Tests Chamber.upgradeImplementation:
     *   `if (proxyAdmin.owner() != address(this)) revert NotAuthorized()`
     *
     * Strategy:
     *   1. Transfer ProxyAdmin ownership to an external address via governance tx.
     *   2. Attempt an upgrade; upgradeImplementation reverts NotAuthorized.
     *   3. The outer executeTransaction catches the inner revert as TransactionFailed.
     */
    function test_Chamber_UpgradeImplementation_NotProxyAdminOwner_Reverts() public {
        address proxyAdminAddress = chamber.getProxyAdmin();

        // Step 1: Submit a governance tx that transfers ProxyAdmin ownership away from chamber
        bytes memory transferData = abi.encodeWithSignature("transferOwnership(address)", address(0xDEAD));

        vm.prank(user1);
        chamber.submitTransaction(1, proxyAdminAddress, 0, transferData);
        uint256 transferTxId = chamber.getTransactionCount() - 1;

        vm.prank(user2);
        chamber.confirmTransaction(2, transferTxId);
        vm.prank(user3);
        chamber.confirmTransaction(3, transferTxId);
        vm.prank(user1);
        chamber.executeTransaction(1, transferTxId, transferData);

        // Verify ProxyAdmin owner is now 0xDEAD
        assertEq(ProxyAdmin(proxyAdminAddress).owner(), address(0xDEAD));

        // Step 2: Submit an upgrade transaction — it will call upgradeImplementation on the chamber
        bytes memory upgradeData =
            abi.encodeWithSelector(IChamber.upgradeImplementation.selector, address(newImplementation), "");

        vm.prank(user1);
        chamber.submitTransaction(1, chamberAddress, 0, upgradeData);
        uint256 upgradeTxId = chamber.getTransactionCount() - 1;

        vm.prank(user2);
        chamber.confirmTransaction(2, upgradeTxId);
        vm.prank(user3);
        chamber.confirmTransaction(3, upgradeTxId);

        // Step 3: Execute — upgradeImplementation checks proxyAdmin.owner() != address(this)
        //   → reverts NotAuthorized → wrapped as TransactionFailed
        vm.prank(user1);
        vm.expectRevert();
        chamber.executeTransaction(1, upgradeTxId, upgradeData);
    }
}
