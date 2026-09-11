// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IWallet} from "src/interfaces/IWallet.sol";
import {IERC1271} from "lib/openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployChamber} from "test/utils/DeployChamber.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";

/// @dev A minimal ERC-1271 contract that authorises a single address
contract MockERC1271Wallet {
    address public authorizedAddress;

    constructor(address _authorized) {
        authorizedAddress = _authorized;
    }

    function isValidSignature(bytes32, bytes memory signature) external view returns (bytes4) {
        if (signature.length == 32) {
            address decoded = abi.decode(signature, (address));
            if (decoded == authorizedAddress) {
                return IERC1271.isValidSignature.selector;
            }
        }
        return bytes4(0xffffffff);
    }

    /// @dev Lets the wallet contract call Chamber as itself (owner path).
    function execute(address target, bytes calldata data) external {
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

/// @dev A minimal Chamber contract that implements IERC1271 for testing
contract MockChamberERC1271 {
    address public authorizedAddress;

    constructor(address _authorized) {
        authorizedAddress = _authorized;
    }

    function isValidSignature(bytes32, bytes memory signature) external view returns (bytes4) {
        if (signature.length == 32) {
            address decoded = abi.decode(signature, (address));
            if (decoded == authorizedAddress) {
                return IERC1271.isValidSignature.selector;
            }
        }
        return bytes4(0xffffffff);
    }

    // Chamber must implement onERC721Received to receive NFTs
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}

contract ChamberTest is Test {
    Chamber public chamber;
    IERC20 public token;
    IERC721 public nft;
    uint256 public seats;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        string memory name = "vERC20";
        string memory symbol = "Vault Token";

        address admin = address(0x9);

        seats = 5;
        chamber = DeployChamber.deploy(address(token), address(nft), seats, name, symbol, admin);
    }

    function test_Chamber_delegate_success() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Mint tokens to user1
        MockERC20(address(token)).mint(user1, amount);

        // Mint NFT to user1
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);

        // Approve and delegate tokens
        vm.startPrank(user1);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, amount);
        vm.stopPrank();

        // Check user delegation amount
        assertEq(chamber.getHolderDelegation(user1, tokenId), amount);

        // Check node amount
        (uint256 nodeTokenId, uint256 nodeAmount,,) = chamber.getMember(tokenId);
        assertEq(nodeTokenId, tokenId);
        assertEq(nodeAmount, amount);
    }

    function test_Chamber_Undelegate_success(uint256 tokenId, uint256 amount) public {
        if (tokenId == 0 || tokenId > type(uint128).max) return;
        if (amount < 1 || amount > 1_000_000_000 ether) return;
        // Mint tokens to user1
        MockERC20(address(token)).mint(user1, amount);

        // Mint NFT to user1
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);

        // Approve and delegate tokens
        vm.startPrank(user1);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, amount);
        vm.stopPrank();

        // Undelegate tokens
        vm.startPrank(user1);
        chamber.undelegate(tokenId, amount);
        vm.stopPrank();

        // Check user delegation amount
        assertEq(chamber.getHolderDelegation(user1, tokenId), 0);

        // Check node amount
        (, uint256 nodeAmount,,) = chamber.getMember(tokenId);
        assertEq(nodeAmount, 0);
    }

    function test_Chamber_SubmitTransaction() public {
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";

        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);

        chamber.submitTransaction(1, target, value, data);
        vm.stopPrank();

        (bool executed, uint8 confirmations, address trxTarget, uint256 trxValue, bytes32 trxDataHash) =
            chamber.getTransaction(0);

        assertEq(target, trxTarget);
        assertEq(value, trxValue);
        assertEq(keccak256(data), trxDataHash);
        assertEq(false, executed);
        assertEq(1, confirmations);
    }

    function test_Chamber_SubmitTransactionWithMetadata() public {
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";
        string memory metadataURI = "ipfs://proposal-risk-brief";

        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);

        chamber.submitTransactionWithMetadata(1, target, value, data, metadataURI);
        vm.stopPrank();

        (bool executed, uint8 confirmations, address trxTarget, uint256 trxValue, bytes32 trxDataHash) =
            chamber.getTransaction(0);

        assertEq(target, trxTarget);
        assertEq(value, trxValue);
        assertEq(keccak256(data), trxDataHash);
        assertEq(false, executed);
        assertEq(1, confirmations);
        assertEq(chamber.getTransactionMetadata(0), metadataURI);
    }

    function test_Chamber_ConfirmTransaction() public {
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";

        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);

        chamber.submitTransaction(1, target, value, data);
        vm.stopPrank();

        (, uint8 confirmations,,,) = chamber.getTransaction(0);
        assertEq(confirmations, 1);
    }

    function test_Chamber_RevokeConfirmation() public {
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";

        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);

        chamber.submitTransaction(1, target, value, data);
        chamber.revokeConfirmation(1, 0);
        vm.stopPrank();

        (, uint8 revokedConfirmations,,,) = chamber.getTransaction(0);
        assertEq(revokedConfirmations, 0);
    }

    function test_Chamber_ExecuteTransaction() public {
        address target = address(0x3);
        uint256 value = 1 ether;
        bytes memory data = "";

        deal(address(chamber), value);

        uint256 tokenId = 1;
        uint256 amount = 1 ether;

        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        MockERC721(address(nft)).mintWithTokenId(user2, tokenId + 1);
        MockERC20(address(token)).mint(user2, amount);

        MockERC721(address(nft)).mintWithTokenId(user3, tokenId + 2);
        MockERC20(address(token)).mint(user3, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.stopPrank();

        vm.startPrank(user2);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user2);
        chamber.delegate(tokenId + 1, 1);
        vm.stopPrank();

        vm.startPrank(user3);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user3);
        chamber.delegate(tokenId + 2, 1);
        vm.stopPrank();
        vm.roll(block.number + 1);

        vm.prank(user1);
        chamber.submitTransaction(1, target, value, data);

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.startPrank(user1);
        chamber.executeTransaction(1, 0, data);
        vm.stopPrank();

        (bool executed,,,,) = chamber.getTransaction(0);
        assertEq(executed, true);
        assertEq(address(0x3).balance, 1 ether);
        assertEq(address(chamber).balance, 0);
    }

    function test_Chamber_GetTransactionCount() public {
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";

        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);

        chamber.submitTransaction(1, target, value, data);
        vm.stopPrank();

        uint256 count = chamber.getTransactionCount();

        assertEq(count, 1);
    }

    function test_Chamber_ZeroAmountDelegation() public {
        uint256 amount = 0;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        vm.expectRevert();
        chamber.delegate(tokenId1, amount);
        vm.stopPrank();
    }

    function test_Chamber_DelegateFunction_NodeTokenIdCheck() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount / 2);
        chamber.delegate(tokenId1, amount / 2);
        vm.stopPrank();
    }

    function test_Chamber_DelegateFunction_BadTransfer() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);

        vm.expectRevert();
        chamber.delegate(tokenId1, amount + 1);
        vm.stopPrank();
    }

    function test_Chamber_UndelegateRevertsWithZeroAmount() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount);
        // Attempt to undelegate with zero amount
        vm.expectRevert();
        chamber.undelegate(tokenId1, 0);
        vm.stopPrank();
    }

    function test_Chamber_UndelegateRevertsWithExcessAmount() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount);

        // Attempt to undelegate more than the delegated amount
        vm.expectRevert();
        chamber.undelegate(tokenId1, amount + 1);
        vm.stopPrank();
    }

    function test_Chamber_DelegateAndUndelegate() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount);

        // Check delegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), amount);

        // Undelegate tokens
        chamber.undelegate(tokenId1, amount);

        // Check undelegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), 0);
        vm.stopPrank();
    }

    function test_Chamber_UndelegateUpdatesNodeAmount() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount);

        // Check delegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), amount);

        // Undelegate part of the tokens
        uint256 undelegateAmount = 500;
        chamber.undelegate(tokenId1, undelegateAmount);

        // Check updated delegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), amount - undelegateAmount);

        // Check node amount
        (, uint256 nodeAmount,,) = chamber.getMember(tokenId1);
        assertEq(nodeAmount, amount - undelegateAmount);
        vm.stopPrank();
    }

    function test_Chamber_UndelegateRemovesNodeIfAmountIsZero() public {
        uint256 amount = 1000;
        uint256 tokenId1 = 1;

        // Mint NFT to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);

        // Mint tokens to user
        MockERC20(address(token)).mint(user1, amount);

        // Approve and delegate tokens
        vm.startPrank(user1);
        MockERC20(address(token)).approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId1, amount);

        // Check delegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), amount);

        // Undelegate all tokens
        chamber.undelegate(tokenId1, amount);

        // Check updated delegation
        assertEq(chamber.getHolderDelegation(user1, tokenId1), 0);
        vm.stopPrank();
    }

    function test_Chamber_GetSeats() public view {
        uint256 _seats = chamber.getSeats();
        assertEq(_seats, 5);
    }

    function test_Chamber_GetDirectors() public {
        addDirectors();

        // Get directors
        address[] memory directors = chamber.getDirectors();

        // Check directors
        assertEq(directors.length, 3);
        assertEq(directors[0], user1);
        assertEq(directors[1], user2);
        assertEq(directors[2], user3);
    }

    function test_Chamber_ExecuteTransaction_NotDirector() public {
        // Submit a transaction first
        address target = address(0x3);
        uint256 value = 0;
        bytes memory data = "";

        vm.startPrank(user1);
        vm.expectRevert();
        chamber.submitTransaction(1, target, value, data);
        vm.stopPrank();
    }

    function test_Chamber_getUserDelegations() public {
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        uint256 tokenId3 = 3;

        // Mint tokens to users
        uint256 amount1 = 100;
        uint256 amount2 = 200;
        uint256 amount3 = 300;
        MockERC20(address(token)).mint(user1, amount1);
        MockERC20(address(token)).mint(user1, amount2);
        MockERC20(address(token)).mint(user1, amount3);

        // Approve and delegate tokens
        addDirectors();

        vm.startPrank(user1);
        token.approve(address(chamber), amount1 + amount2 + amount3);
        chamber.deposit(amount1 + amount2 + amount3, user1);
        chamber.delegate(tokenId1, amount1);
        chamber.delegate(tokenId2, amount2);
        chamber.delegate(tokenId3, amount3);
        vm.stopPrank();

        // Get user delegations (order is set insertion order, not board rank)
        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(user1);

        assertEq(tokenIds.length, 3);
        assertEq(amounts.length, 3);
        assertEq(_delegationAmount(tokenIds, amounts, tokenId1), amount1 + 1);
        assertEq(_delegationAmount(tokenIds, amounts, tokenId2), amount2);
        assertEq(_delegationAmount(tokenIds, amounts, tokenId3), amount3);
    }

    function test_Chamber_ExecuteTransaction_MockERC20() public {
        uint256 value = 100 ether;
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", user1, value);

        addDirectors();

        // Create a new mock token and send balance to chamber
        MockERC20 mockToken = new MockERC20("Mock Token", "MCK", 0);
        mockToken.mint(address(chamber), value);

        address target = address(mockToken);

        // Submit and confirm the transaction
        vm.startPrank(user1);
        chamber.submitTransaction(1, target, 0, data);
        vm.stopPrank();

        vm.startPrank(user2);
        chamber.confirmTransaction(2, 0);
        vm.stopPrank();

        vm.startPrank(user3);
        chamber.confirmTransaction(3, 0);
        vm.stopPrank();

        // Execute the transaction
        vm.startPrank(user1);
        chamber.executeTransaction(1, 0, data);
        vm.stopPrank();

        // Check the transaction execution
        assertEq(MockERC20(target).balanceOf(user1), value);
    }

    function test_Chamber_ExecuteBatchTransactions() public {
        address target1 = address(0x3);
        address target2 = address(0x4);
        uint256 value1 = 1 ether;
        uint256 value2 = 2 ether;
        bytes memory data1 = "";
        bytes memory data2 = "";
        deal(address(chamber), 3 ether);

        address[] memory targets = new address[](2);
        targets[0] = target1;
        targets[1] = target2;

        uint256[] memory values = new uint256[](2);
        values[0] = value1;
        values[1] = value2;

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data2;

        addDirectors();

        vm.startPrank(user1);
        chamber.submitBatchTransactions(1, targets, values, data);
        uint256[] memory batch = new uint256[](2);
        batch[0] = 0;
        batch[1] = 1;
        vm.stopPrank();

        vm.startPrank(user2);
        chamber.confirmBatchTransactions(2, batch);
        vm.stopPrank();

        vm.startPrank(user3);
        chamber.confirmBatchTransactions(3, batch);
        vm.stopPrank();

        vm.startPrank(user1);
        chamber.executeBatchTransactions(1, batch, data);
        vm.stopPrank();

        (bool executed0,,,,) = chamber.getTransaction(0);
        (bool executed1,,,,) = chamber.getTransaction(1);
        assertEq(executed0, true);
        assertEq(executed1, true);
        assertEq(address(0x3).balance, 1 ether);
        assertEq(address(0x4).balance, 2 ether);
        assertEq(address(chamber).balance, 0);
    }

    function test_Chamber_ExecuteTransactionLowConfCount() public {
        uint256 amount = 1000;
        address target = address(token);
        bytes memory approveData = abi.encodeWithSignature("approve(address,uint256)", address(0x5), amount);
        bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", address(0x5), amount);

        addDirectors();

        // Submit approve transaction
        vm.startPrank(user1);
        chamber.submitTransaction(1, target, 0, approveData);
        vm.stopPrank();

        vm.startPrank(user2);
        chamber.confirmTransaction(2, 0);
        vm.stopPrank();

        vm.startPrank(user3);
        chamber.confirmTransaction(3, 0);
        chamber.executeTransaction(3, 0, approveData);
        vm.stopPrank();

        // Submit transfer transaction
        vm.startPrank(user1);
        chamber.submitTransaction(1, target, 0, transferData);
        vm.stopPrank();

        // Only one confirmation, should revert on execute
        vm.startPrank(user1);
        vm.expectRevert();
        chamber.executeTransaction(1, 1, transferData);
        vm.stopPrank();
    }

    function test_Chamber_ExecuteTransactionMintNFT() public {
        uint256 tokenId = 100;
        address target = address(nft);
        bytes memory mintData = abi.encodeWithSignature("mintWithTokenId(address,uint256)", address(0x5), tokenId);

        addDirectors();

        // Submit mint transaction
        vm.startPrank(user1);
        chamber.submitTransaction(1, target, 0, mintData);
        vm.stopPrank();

        vm.startPrank(user2);
        chamber.confirmTransaction(2, 0);
        vm.stopPrank();

        vm.startPrank(user3);
        chamber.confirmTransaction(3, 0);
        chamber.executeTransaction(3, 0, mintData);
        vm.stopPrank();

        (bool executedNft,,,,) = chamber.getTransaction(0);
        assertEq(executedNft, true);
        assertEq(MockERC721(address(nft)).ownerOf(tokenId), address(0x5));
    }

    function test_Chamber_transfer_Success() public {
        deal(address(chamber), address(this), 1e18);

        chamber.approve(user1, 1 ether);
        bool success = chamber.transfer(user1, 1 ether);
        assertTrue(success, "Transfer failed");

        assertEq(chamber.balanceOf(user1), 1 ether);
    }

    function test_Chamber_transfer_ExceedsDelegatedAmount() public {
        addDirectors();
        address bob = address(22323);

        uint256 amount = chamber.balanceOf(user1);

        vm.startPrank(user1);
        chamber.approve(bob, amount);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transfer(bob, amount);
    }

    function test_Chamber_transferFrom() public {
        deal(address(chamber), address(this), 1e18);

        chamber.approve(address(this), 1 ether);
        bool success = chamber.transferFrom(address(this), user1, 1 ether);
        assertTrue(success, "TransferFrom failed");

        assertEq(chamber.balanceOf(user1), 1 ether);
    }

    function test_Chamber_transferFrom_ExceedsDelegatedAmount() public {
        addDirectors();
        address bob = address(22323);
        uint256 amount = chamber.balanceOf(user1);

        vm.startPrank(user1);
        chamber.approve(user1, amount);
        vm.expectRevert(IChamber.ExceedsDelegatedAmount.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transferFrom(user1, bob, amount);
    }

    function _delegationAmount(uint256[] memory tokenIds, uint256[] memory amounts, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) return amounts[i];
        }
        return 0;
    }

    function addDirectors() internal {
        uint256 amount = 1 ether;

        // Mint NFTs and tokens to users
        MockERC721(address(nft)).mintWithTokenId(user1, 1);
        MockERC721(address(nft)).mintWithTokenId(user2, 2);
        MockERC721(address(nft)).mintWithTokenId(user3, 3);

        MockERC20(address(token)).mint(user1, amount);
        MockERC20(address(token)).mint(user2, amount);
        MockERC20(address(token)).mint(user3, amount);

        // Set up user1
        vm.startPrank(user1);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(1, 1);
        vm.stopPrank();

        // Set up user2
        vm.startPrank(user2);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user2);
        chamber.delegate(2, 1);
        vm.stopPrank();

        // Set up user3
        vm.startPrank(user3);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user3);
        chamber.delegate(3, 1);
        vm.stopPrank();
        vm.roll(block.number + 1);
    }

    function test_Chamber_GetTotalHolderDelegations() public {
        uint256 amount1 = 100;
        uint256 amount2 = 200;
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;

        // Mint NFTs and tokens to user
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId1);
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId2);
        MockERC20(address(token)).mint(user1, amount1 + amount2);

        // Approve and delegate tokens
        vm.startPrank(user1);
        token.approve(address(chamber), amount1 + amount2);
        chamber.deposit(amount1 + amount2, user1);
        chamber.delegate(tokenId1, amount1);
        chamber.delegate(tokenId2, amount2);
        vm.stopPrank();

        // Check total delegated weight across tokenIds for this holder
        uint256 totalDelegations = chamber.getTotalHolderDelegations(user1);
        assertEq(totalDelegations, amount1 + amount2);
    }

    function test_Chamber_GetSeatUpdate() public {
        addDirectors();

        // Submit a seat update proposal
        uint256 newSeats = 7;
        vm.prank(user1);
        chamber.updateSeats(1, newSeats);

        // Get the seat update proposal
        (uint256 proposedSeats, uint256 timestamp,, uint256[] memory supporters) = chamber.getSeatUpdate();

        // Check the proposal details
        assertEq(proposedSeats, newSeats);
        assertEq(supporters[0], 1);
        assertEq(timestamp, block.timestamp);
    }

    function test_Chamber_UpdateSeats() public {
        addDirectors();

        uint256 newSeats = 7;
        vm.prank(user1);
        chamber.updateSeats(1, newSeats);

        // Check the seat update proposal
        (uint256 proposedSeats2, uint256 timestamp2,, uint256[] memory supporters2) = chamber.getSeatUpdate();
        assertEq(proposedSeats2, newSeats);
        assertEq(supporters2[0], 1);
        assertEq(timestamp2, block.timestamp);
    }

    function test_Chamber_UpdateSeats_ZeroSeats() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroSeats.selector);
        chamber.updateSeats(1, 0);
    }

    function test_Chamber_UpdateSeats_TooManySeats() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.TooManySeats.selector);
        chamber.updateSeats(1, 21);
    }

    function test_Chamber_ExecuteSeatsUpdate() public {
        addDirectors();

        uint256 newSeats = 7;
        vm.prank(user1);
        chamber.updateSeats(1, newSeats);

        // Fast forward 8 days
        vm.warp(block.timestamp + 8 days);

        // Execute the seat update
        vm.prank(user2);
        chamber.updateSeats(2, newSeats);

        vm.prank(user3);
        chamber.updateSeats(3, newSeats);

        vm.prank(user3);
        chamber.executeSeatsUpdate(3);

        // Check the seats are not updated
        assertEq(chamber.getSeats(), 7);
    }

    function test_Chamber_GetTop() public {
        addDirectors();

        // Get the top 3 directors
        (uint256[] memory topTokenIds, uint256[] memory topAmounts) = chamber.getTop(3);

        // Check the top directors
        assertEq(topTokenIds.length, 3);
        assertEq(topAmounts.length, 3);
        assertEq(topTokenIds[0], 1);
        assertEq(topTokenIds[1], 2);
        assertEq(topTokenIds[2], 3);
        assertEq(topAmounts[0], 1);
        assertEq(topAmounts[1], 1);
        assertEq(topAmounts[2], 1);
    }

    function test_Chamber_GetSize() public {
        addDirectors();

        // Check the board size
        uint256 size = chamber.getSize();
        assertEq(size, 3);
    }

    function test_Chamber_GetQuorum() public {
        addDirectors();

        // Check the quorum
        uint256 quorum = chamber.getQuorum();
        // 3 reachable directors on 5 configured seats → 1 + (3 * 51) / 100 = 2 (PMN-M01)
        assertEq(quorum, 2);
    }

    function test_Chamber_SendEth() public {
        addDirectors();

        deal(address(chamber), 1 ether);
        // Submit a transaction to send ETH to an EOA
        address payable recipient = payable(address(0x1234));

        vm.prank(user1);
        chamber.submitTransaction(1, recipient, 1 ether, "");

        // Confirm the transaction
        vm.prank(user2);
        chamber.confirmTransaction(2, 0);
        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        // Check recipient balance before execution
        uint256 initialBalance = recipient.balance;

        // Execute the transaction
        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        // Check the ETH was transferred to the recipient
        assertEq(recipient.balance, initialBalance + 1 ether);
    }

    // Additional tests for 100% coverage

    function test_Chamber_Initialize_ZeroERC20_Reverts() public {
        // Use a minimal proxy to test initialization with zero ERC20
        Chamber impl = new Chamber();
        address payable proxy = payable(Clones.clone(address(impl)));
        Chamber proxyChamber = Chamber(proxy);

        vm.expectRevert(IChamber.ZeroAddress.selector);
        proxyChamber.initialize(address(0), address(nft), 5, "Test", "TST");
    }

    function test_Chamber_Initialize_ZeroERC721_Reverts() public {
        // Use a minimal proxy to test initialization with zero ERC721
        Chamber impl = new Chamber();
        address payable proxy = payable(Clones.clone(address(impl)));
        Chamber proxyChamber = Chamber(proxy);

        vm.expectRevert(IChamber.ZeroAddress.selector);
        proxyChamber.initialize(address(token), address(0), 5, "Test", "TST");
    }

    function test_Chamber_Initialize_ZeroSeats_Reverts() public {
        Chamber impl = new Chamber();
        address payable proxy = payable(Clones.clone(address(impl)));
        Chamber proxyChamber = Chamber(proxy);

        vm.expectRevert(IChamber.ZeroSeats.selector);
        proxyChamber.initialize(address(token), address(nft), 0, "Test", "TST");
    }

    function test_Chamber_Initialize_TooManySeats_Reverts() public {
        Chamber impl = new Chamber();
        address payable proxy = payable(Clones.clone(address(impl)));
        Chamber proxyChamber = Chamber(proxy);

        vm.expectRevert(IChamber.TooManySeats.selector);
        proxyChamber.initialize(address(token), address(nft), 21, "Test", "TST");
    }

    function test_Chamber_Delegate_ZeroTokenId_Reverts() public {
        MockERC20(address(token)).mint(user1, 100);

        vm.startPrank(user1);
        token.approve(address(chamber), 100);
        chamber.deposit(100, user1);

        vm.expectRevert(IChamber.ZeroTokenId.selector);
        chamber.delegate(0, 50);
        vm.stopPrank();
    }

    function test_Chamber_Delegate_InvalidTokenId_Reverts() public {
        MockERC20(address(token)).mint(user1, 100);

        vm.startPrank(user1);
        token.approve(address(chamber), 100);
        chamber.deposit(100, user1);

        // Token 999 doesn't exist
        vm.expectRevert(IChamber.InvalidTokenId.selector);
        chamber.delegate(999, 50);
        vm.stopPrank();
    }

    function test_Chamber_Undelegate_ZeroTokenId_Reverts() public {
        vm.expectRevert(IChamber.ZeroTokenId.selector);
        chamber.undelegate(0, 50);
    }

    function test_Chamber_GetDelegations_ZeroAddress_Reverts() public {
        vm.expectRevert(IChamber.ZeroAddress.selector);
        chamber.getDelegations(address(0));
    }

    function test_Chamber_SubmitTransaction_ZeroAddress_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroAddress.selector);
        chamber.submitTransaction(1, address(0), 0, "");
    }

    function test_Chamber_SubmitTransaction_SelfTarget_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitTransaction(1, address(chamber), 0, "");
    }

    function test_Chamber_SubmitTransaction_InsufficientBalance_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.InsufficientChamberBalance.selector);
        chamber.submitTransaction(1, address(0x3), 100 ether, "");
    }

    function test_Chamber_ConfirmTransaction_NonExistent_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert();
        chamber.confirmTransaction(1, 999);
    }

    function test_Chamber_ConfirmTransaction_AlreadyExecuted_Reverts() public {
        addDirectors();
        deal(address(chamber), 1 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 1 ether, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        // Try to confirm again - should revert
        address user4 = address(0x4);
        MockERC721(address(nft)).mintWithTokenId(user4, 4);
        MockERC20(address(token)).mint(user4, 1 ether);

        vm.startPrank(user4);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user4);
        chamber.delegate(4, 1);
        vm.expectRevert();
        chamber.confirmTransaction(4, 0);
        vm.stopPrank();
    }

    function test_Chamber_ConfirmTransaction_AlreadyConfirmed_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        vm.expectRevert();
        chamber.confirmTransaction(1, 0);
    }

    function test_Chamber_ExecuteTransaction_NonExistent_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert();
        chamber.executeTransaction(1, 999, "");
    }

    function test_Chamber_ExecuteTransaction_AlreadyExecuted_Reverts() public {
        addDirectors();
        deal(address(chamber), 1 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 1 ether, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        vm.prank(user1);
        vm.expectRevert();
        chamber.executeTransaction(1, 0, "");
    }

    function test_Chamber_SubmitBatchTransactions_EmptyArray_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory data = new bytes[](0);

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroAmount.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    function test_Chamber_SubmitBatchTransactions_ArrayMismatch_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](2);
        targets[0] = address(0x3);
        targets[1] = address(0x4);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](2);

        vm.prank(user1);
        vm.expectRevert(IChamber.ArrayLengthsMustMatch.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    function test_Chamber_SubmitBatchTransactions_ZeroAddress_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroAddress.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    function test_Chamber_SubmitBatchTransactions_SelfTarget_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](1);
        targets[0] = address(chamber);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory data = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    function test_Chamber_SubmitBatchTransactions_InsufficientBalance_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](1);
        targets[0] = address(0x3);
        uint256[] memory values = new uint256[](1);
        values[0] = 100 ether;
        bytes[] memory data = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert(IChamber.InsufficientChamberBalance.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    function test_Chamber_ConfirmBatchTransactions_EmptyArray_Reverts() public {
        addDirectors();

        uint256[] memory transactionIds = new uint256[](0);

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroAmount.selector);
        chamber.confirmBatchTransactions(1, transactionIds);
    }

    function test_Chamber_ConfirmBatchTransactions_NonExistent_Reverts() public {
        addDirectors();

        uint256[] memory transactionIds = new uint256[](1);
        transactionIds[0] = 999;

        vm.prank(user1);
        vm.expectRevert();
        chamber.confirmBatchTransactions(1, transactionIds);
    }

    function test_Chamber_ExecuteBatchTransactions_EmptyArray_Reverts() public {
        addDirectors();

        uint256[] memory transactionIds = new uint256[](0);
        bytes[] memory batchData = new bytes[](0);

        vm.prank(user1);
        vm.expectRevert(IChamber.ZeroAmount.selector);
        chamber.executeBatchTransactions(1, transactionIds, batchData);
    }

    function test_Chamber_ExecuteBatchTransactions_NonExistent_Reverts() public {
        addDirectors();

        uint256[] memory transactionIds = new uint256[](1);
        transactionIds[0] = 999;
        bytes[] memory batchData = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert();
        chamber.executeBatchTransactions(1, transactionIds, batchData);
    }

    function test_Chamber_ExecuteBatchTransactions_NotEnoughConfirmations_Reverts() public {
        addDirectors();
        deal(address(chamber), 1 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        uint256[] memory transactionIds = new uint256[](1);
        transactionIds[0] = 0;
        bytes[] memory batchData = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert(IChamber.NotEnoughConfirmations.selector);
        chamber.executeBatchTransactions(1, transactionIds, batchData);
    }

    function test_Chamber_Receive() public {
        deal(address(this), 1 ether);

        (bool success,) = address(chamber).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(chamber).balance, 1 ether);
    }

    function test_Chamber_ReceiveERC721() public {
        // Intended: Chamber custodies arbitrary ERC-721s, not only the membership collection.
        MockERC721 otherNft = new MockERC721("Other NFT", "ONFT");
        uint256 tokenId = otherNft.mint(user1);

        vm.prank(user1);
        otherNft.safeTransferFrom(user1, address(chamber), tokenId);

        assertEq(otherNft.ownerOf(tokenId), address(chamber));
    }

    function test_Chamber_CancelTransaction_Quorum() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        assertFalse(chamber.getCancelled(0));

        // 3 reachable directors → quorum 2 (PMN-M01)
        vm.prank(user1);
        chamber.cancelTransaction(1, 0);
        assertFalse(chamber.getCancelled(0));

        vm.prank(user2);
        chamber.cancelTransaction(2, 0);
        assertTrue(chamber.getCancelled(0));

        // Execute should revert
        vm.prank(user1);
        vm.expectRevert(IWallet.TransactionAlreadyCancelled.selector);
        chamber.executeTransaction(1, 0, "");
    }

    function test_Chamber_CancelTransaction_AlreadyCancelled_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        chamber.cancelTransaction(1, 0);
        vm.prank(user2);
        chamber.cancelTransaction(2, 0);

        vm.prank(user3);
        vm.expectRevert(IWallet.TransactionAlreadyCancelled.selector);
        chamber.cancelTransaction(3, 0);
    }

    function test_Chamber_ConfirmTransaction_AfterCancel_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        chamber.cancelTransaction(1, 0);
        vm.prank(user2);
        chamber.cancelTransaction(2, 0);
        assertTrue(chamber.getCancelled(0));

        vm.prank(user2);
        vm.expectRevert(IWallet.TransactionAlreadyCancelled.selector);
        chamber.confirmTransaction(2, 0);
    }

    function test_Chamber_RevokeConfirmation_AfterCancel_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user1);
        chamber.cancelTransaction(1, 0);
        vm.prank(user2);
        chamber.cancelTransaction(2, 0);
        assertTrue(chamber.getCancelled(0));

        vm.prank(user2);
        vm.expectRevert(IWallet.TransactionAlreadyCancelled.selector);
        chamber.revokeConfirmation(2, 0);
    }

    function test_Chamber_CancelTransaction_DoubleVote_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        chamber.cancelTransaction(1, 0);

        vm.prank(user1);
        vm.expectRevert(IWallet.TransactionCancelAlreadyConfirmed.selector);
        chamber.cancelTransaction(1, 0);
    }

    function test_Chamber_IsDirector_ZeroTokenId_Reverts() public {
        addDirectors();

        vm.prank(user1);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(0, address(0x3), 0, "");
    }

    function test_Chamber_IsDirector_NotOwner_Reverts() public {
        addDirectors();

        // user2 trying to use user1's tokenId
        vm.prank(user2);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(1, address(0x3), 0, "");
    }

    function test_Chamber_IsDirector_NotInTopSeats_Reverts() public {
        // Add 6 directors but only 5 seats
        addDirectors();

        address user4 = address(0x4);
        MockERC721(address(nft)).mintWithTokenId(user4, 4);
        MockERC20(address(token)).mint(user4, 1 ether);

        address user5 = address(0x5);
        MockERC721(address(nft)).mintWithTokenId(user5, 5);
        MockERC20(address(token)).mint(user5, 1 ether);

        address user6 = address(0x6);
        MockERC721(address(nft)).mintWithTokenId(user6, 6);
        MockERC20(address(token)).mint(user6, 1 ether);

        vm.startPrank(user4);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user4);
        chamber.delegate(4, 1);
        vm.stopPrank();

        vm.startPrank(user5);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user5);
        chamber.delegate(5, 1);
        vm.stopPrank();

        vm.startPrank(user6);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user6);
        chamber.delegate(6, 1);
        vm.stopPrank();

        // user6 (tokenId 6) is the 6th but only 5 seats
        vm.prank(user6);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(6, address(0x3), 0, "");
    }

    function test_Chamber_Transfer_ZeroAddress_Reverts() public {
        deal(address(chamber), address(this), 1e18);

        vm.expectRevert(IChamber.TransferToZeroAddress.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transfer(address(0), 1 ether);
    }

    function test_Chamber_Transfer_ZeroAmount_Reverts() public {
        deal(address(chamber), address(this), 1e18);

        vm.expectRevert(IChamber.ZeroAmount.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transfer(user1, 0);
    }

    function test_Chamber_Transfer_InsufficientBalance_Reverts() public {
        vm.expectRevert(IChamber.InsufficientChamberBalance.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transfer(user1, 1 ether);
    }

    function test_Chamber_TransferFrom_ZeroAddress_Reverts() public {
        deal(address(chamber), address(this), 1e18);
        chamber.approve(address(this), 1 ether);

        vm.expectRevert(IChamber.TransferToZeroAddress.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transferFrom(address(this), address(0), 1 ether);
    }

    function test_Chamber_TransferFrom_ZeroAmount_Reverts() public {
        deal(address(chamber), address(this), 1e18);
        chamber.approve(address(this), 1 ether);

        vm.expectRevert(IChamber.ZeroAmount.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transferFrom(address(this), user1, 0);
    }

    function test_Chamber_TransferFrom_InsufficientBalance_Reverts() public {
        chamber.approve(address(this), 1 ether);

        vm.expectRevert(IChamber.InsufficientChamberBalance.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        chamber.transferFrom(address(this), user1, 1 ether);
    }

    function test_Chamber_GetDirectors_BurnedNFT() public {
        addDirectors();

        // Get directors - should return address(0) for burned NFTs
        // (though we can't actually burn in mock, we test the try/catch)
        address[] memory directors = chamber.getDirectors();
        assertEq(directors.length, 3);
    }

    function test_Chamber_GetNextTransactionId() public {
        assertEq(chamber.getNextTransactionId(), 0);

        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        assertEq(chamber.getNextTransactionId(), 1);
    }

    function test_Chamber_GetConfirmation() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        assertTrue(chamber.getConfirmation(1, 0));
        assertFalse(chamber.getConfirmation(2, 0));
    }

    function test_Chamber_RevokeConfirmation_CheckConfirmation() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        vm.prank(user1);
        chamber.revokeConfirmation(1, 0);

        assertFalse(chamber.getConfirmation(1, 0));
    }

    function test_Chamber_ConfirmBatchTransactions_AlreadyExecuted_Reverts() public {
        addDirectors();
        deal(address(chamber), 1 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 1 ether, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        uint256[] memory batch = new uint256[](1);
        batch[0] = 0;

        // Add another director
        address user4 = address(0x4);
        MockERC721(address(nft)).mintWithTokenId(user4, 4);
        MockERC20(address(token)).mint(user4, 1 ether);
        vm.startPrank(user4);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user4);
        chamber.delegate(4, 1);

        vm.expectRevert();
        chamber.confirmBatchTransactions(4, batch);
        vm.stopPrank();
    }

    function test_Chamber_ConfirmBatchTransactions_AlreadyConfirmed_Reverts() public {
        addDirectors();

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 0, "");

        uint256[] memory batch = new uint256[](1);
        batch[0] = 0;

        vm.prank(user1);
        vm.expectRevert();
        chamber.confirmBatchTransactions(1, batch);
    }

    function test_Chamber_ExecuteBatchTransactions_AlreadyExecuted_Reverts() public {
        addDirectors();
        deal(address(chamber), 2 ether);

        vm.prank(user1);
        chamber.submitTransaction(1, address(0x3), 1 ether, "");

        vm.prank(user2);
        chamber.confirmTransaction(2, 0);

        vm.prank(user3);
        chamber.confirmTransaction(3, 0);

        vm.prank(user1);
        chamber.executeTransaction(1, 0, "");

        uint256[] memory batch = new uint256[](1);
        batch[0] = 0;
        bytes[] memory batchData = new bytes[](1);

        vm.prank(user1);
        vm.expectRevert();
        chamber.executeBatchTransactions(1, batch, batchData);
    }

    function test_Chamber_GetDelegations_NoMatches() public {
        addDirectors();

        // user1 has delegations, but user2's delegations should not be returned
        address otherUser = address(0x999);
        (uint256[] memory tokenIds, uint256[] memory amounts) = chamber.getDelegations(otherUser);

        assertEq(tokenIds.length, 0);
        assertEq(amounts.length, 0);
    }

    function test_Chamber_Version() public view {
        assertEq(chamber.VERSION(), bytes32("1.1.8"));
    }

    // ─── acceptAdmin (no-op) ───────────────────────────────────────────

    function test_Chamber_AcceptAdmin_NoOp() public {
        // acceptAdmin is a no-op; calling it should not revert
        chamber.acceptAdmin();
    }

    // ─── submitTransaction: short data when target == self ─────────────

    function test_Chamber_SubmitTransaction_ShortData_Reverts() public {
        addDirectors();

        // target == chamber with data < 4 bytes → InvalidTransaction
        bytes memory shortData = hex"aabb"; // only 2 bytes

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitTransaction(1, address(chamber), 0, shortData);
    }

    // ─── getDirectors: ownerOf reverts (burned NFT) ────────────────────

    function test_Chamber_GetDirectors_BurnedNFT_ReturnsZeroAddress() public {
        uint256 tokenId = 1;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, 1 ether);

        vm.startPrank(user1);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, user1);
        chamber.delegate(tokenId, 1 ether);
        vm.stopPrank();

        // Burn the NFT so ownerOf reverts
        MockERC721(address(nft)).burn(tokenId);

        // getDirectors should catch the revert and return address(0)
        address[] memory directors = chamber.getDirectors();
        assertEq(directors.length, 1);
        assertEq(directors[0], address(0));
    }

    // ─── submitBatchTransactions: wrong selector when target == self ───

    function test_Chamber_SubmitBatchTransactions_WrongSelector_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](1);
        targets[0] = address(chamber);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory data = new bytes[](1);
        // 4+ bytes with wrong selector
        data[0] = abi.encodeWithSignature("wrongFunction()");

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    // ─── submitBatchTransactions: short data when target == self ───────

    function test_Chamber_SubmitBatchTransactions_ShortData_Reverts() public {
        addDirectors();

        address[] memory targets = new address[](1);
        targets[0] = address(chamber);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory data = new bytes[](1);
        data[0] = hex"aa"; // 1 byte — too short

        vm.prank(user1);
        vm.expectRevert(IChamber.InvalidTransaction.selector);
        chamber.submitBatchTransactions(1, targets, values, data);
    }

    // ─── _isDirector: only the NFT owner (msg.sender == owner) ───────────

    function test_Chamber_IsDirector_EOAOwner_Works() public {
        uint256 tokenId = 1;
        uint256 amount = 1 ether;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);
        MockERC20(address(token)).mint(user1, amount);

        vm.startPrank(user1);
        token.approve(address(chamber), amount);
        chamber.deposit(amount, user1);
        chamber.delegate(tokenId, 1);
        vm.roll(block.number + 1);
        chamber.submitTransaction(tokenId, address(0x3), 0, "");
        vm.stopPrank();

        assertEq(chamber.getTransactionCount(), 1);
    }

    function test_Chamber_IsDirector_ContractOwnerCallingAsItself_Works() public {
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xABCD));
        uint256 tokenId = 10;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);
        vm.roll(block.number + 1);

        vm.prank(address(wallet));
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");

        assertEq(chamber.getTransactionCount(), 1);
    }

    function test_Chamber_IsDirector_Promiscuous1271_CannotAuthorizeRandomCaller() public {
        // Wallet would accept any encoded caller as a 1271 "signature"; Chamber must not consult it.
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 11;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);

        vm.prank(address(0xDEAD));
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");

        assertEq(chamber.getTransactionCount(), 0);
    }

    function test_Chamber_IsDirector_SessionKey_Works() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 12;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);
        vm.roll(block.number + 1);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, sessionKey)));
        assertEq(chamber.getDirectorOperator(tokenId), sessionKey);
        assertTrue(chamber.isTokenAuthorized(tokenId, sessionKey));
        assertTrue(chamber.isTokenAuthorized(tokenId, address(wallet)));

        vm.prank(sessionKey);
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");

        assertEq(chamber.getTransactionCount(), 1);
    }

    function test_Chamber_IsDirector_SessionKey_Promiscuous1271StillBlocked() public {
        address sessionKey = address(0xB0B);
        address random1271Caller = address(0xDEAD);
        MockERC1271Wallet wallet = new MockERC1271Wallet(random1271Caller);
        uint256 tokenId = 13;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);
        vm.roll(block.number + 1);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, sessionKey)));

        vm.prank(random1271Caller);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");

        assertEq(chamber.getTransactionCount(), 0);
        assertFalse(chamber.isTokenAuthorized(tokenId, random1271Caller));
    }

    function test_Chamber_SetDirectorOperator_EOAOwnerReverts() public {
        uint256 tokenId = 1;
        MockERC721(address(nft)).mintWithTokenId(user1, tokenId);

        vm.prank(user1);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(tokenId, address(0xB0B));
    }

    function test_Chamber_SetDirectorOperator_NonOwnerReverts() public {
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 14;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        vm.prank(address(0xB0B));
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(tokenId, address(0xB0B));
    }

    function test_Chamber_SetDirectorOperator_OperatorCannotReplace() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 17;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, sessionKey)));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.setDirectorOperator(tokenId, address(0xFEE1));
    }

    function test_Chamber_SessionKey_InvalidatedOnTransfer() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 15;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);
        vm.roll(block.number + 1);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, sessionKey)));

        vm.prank(address(wallet));
        nft.transferFrom(address(wallet), user1, tokenId);

        assertEq(chamber.getDirectorOperator(tokenId), address(0));
        assertFalse(chamber.isTokenAuthorized(tokenId, sessionKey));

        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");
    }

    function test_Chamber_SessionKey_Clear() public {
        address sessionKey = address(0xB0B);
        MockERC1271Wallet wallet = new MockERC1271Wallet(address(0xDEAD));
        uint256 tokenId = 16;
        MockERC721(address(nft)).mintWithTokenId(address(wallet), tokenId);

        MockERC20(address(token)).mint(address(this), 1 ether);
        token.approve(address(chamber), 1 ether);
        chamber.deposit(1 ether, address(this));
        chamber.delegate(tokenId, 1 ether);
        vm.roll(block.number + 1);

        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, sessionKey)));
        wallet.execute(address(chamber), abi.encodeCall(chamber.setDirectorOperator, (tokenId, address(0))));

        assertEq(chamber.getDirectorOperator(tokenId), address(0));
        vm.prank(sessionKey);
        vm.expectRevert(IChamber.NotDirector.selector);
        chamber.submitTransaction(tokenId, address(0x9999), 0, "");
    }

    function test_ChamberAsDirector_ExecutesTransactionToAnotherChamber() public {
        // Setup: Create two Chambers
        // Chamber A (director chamber) will be a director of Chamber B

        // Deploy Chamber A (as ERC1271 contract)
        address authorizedAddress = address(this);
        MockChamberERC1271 chamberA = new MockChamberERC1271(authorizedAddress);

        // Deploy Chamber B (regular chamber)
        Chamber chamberB = DeployChamber.deploy(address(token), address(nft), 3, "Chamber B", "CHMB", address(0x9));

        // 1. Chamber A needs to hold an NFT from Chamber B's collection
        uint256 tokenId = 1;
        MockERC721(address(nft)).mintWithTokenId(address(chamberA), tokenId);

        // 2. Chamber A needs delegated voting power in Chamber B to become director
        // Mint tokens to this test contract
        uint256 delegationAmount = 1000e18;
        MockERC20(address(token)).mint(address(this), delegationAmount);

        // Approve and deposit to Chamber B
        token.approve(address(chamberB), delegationAmount);
        chamberB.deposit(delegationAmount, address(this));

        // Delegate tokens to Chamber A's tokenId
        chamberB.delegate(tokenId, delegationAmount);

        // 3. Verify Chamber A is now a director of Chamber B
        // Chamber A should be in top 3 positions (seats = 3)
        address[] memory directors = chamberB.getDirectors();
        bool chamberAIsDirector = false;
        for (uint256 i = 0; i < directors.length; i++) {
            if (directors[i] == address(chamberA)) {
                chamberAIsDirector = true;
                break;
            }
        }
        assertTrue(chamberAIsDirector, "Chamber A should be a director of Chamber B");

        // 5. Get other directors to confirm (need quorum)
        // Mint more NFTs and delegate to get more directors
        uint256 tokenId2 = 2;
        address testUser2 = address(0x20);
        MockERC721(address(nft)).mintWithTokenId(testUser2, tokenId2);

        // Delegate to tokenId2
        chamberB.delegate(tokenId2, 500e18);
        vm.roll(block.number + 1);

        // 4. Chamber A submits a transaction on Chamber B by calling as itself
        bytes memory testData = abi.encodeWithSignature("testFunction()");
        vm.prank(address(chamberA));
        chamberB.submitTransaction(tokenId, address(0x1234), 0, testData);

        // Verify transaction was submitted
        assertEq(chamberB.getTransactionCount(), 1);

        // testUser2 confirms the transaction
        vm.prank(testUser2);
        chamberB.confirmTransaction(tokenId2, 0);

        // 6. Chamber A executes the transaction
        vm.prank(address(chamberA));
        chamberB.executeTransaction(tokenId, 0, testData);

        // Verify transaction executed
        (bool executed,,,,) = chamberB.getTransaction(0);
        assertTrue(executed, "Transaction should be executed");

        emit log("Test passed: Chamber A successfully acted as director and executed transaction on Chamber B");
    }

    function test_ChamberAsDirector_ExecutesTransactionFromChamberToChamber() public {
        // More comprehensive test: Chamber A is director of Chamber B and executes
        // a transaction from Chamber B to Chamber C

        // Setup: Create three Chambers
        // Chamber A (director chamber) will be a director of Chamber B
        // Chamber B will execute a transaction to Chamber C

        // Deploy Chamber A (as ERC1271 contract)
        address authorizedAddress = address(this);
        MockChamberERC1271 chamberA = new MockChamberERC1271(authorizedAddress);

        // Deploy Chamber B (regular chamber - where Chamber A is director)
        Chamber chamberB = DeployChamber.deploy(address(token), address(nft), 3, "Chamber B", "CHMB", address(0x9));

        // Deploy Chamber C (target chamber for transaction)
        Chamber chamberC = DeployChamber.deploy(address(token), address(nft), 3, "Chamber C", "CHMC", address(0x9));

        // 1. Chamber A needs to hold an NFT from Chamber B's collection
        uint256 tokenId = 1;
        MockERC721(address(nft)).mintWithTokenId(address(chamberA), tokenId);

        // 2. Chamber A needs delegated voting power in Chamber B to become director
        uint256 delegationAmount = 1000e18;
        MockERC20(address(token)).mint(address(this), delegationAmount);

        // Approve and deposit to Chamber B
        token.approve(address(chamberB), delegationAmount);
        chamberB.deposit(delegationAmount, address(this));

        // Delegate tokens to Chamber A's tokenId
        chamberB.delegate(tokenId, delegationAmount);

        // 3. Verify Chamber A is now a director of Chamber B
        address[] memory directors = chamberB.getDirectors();
        bool chamberAIsDirector = false;
        for (uint256 i = 0; i < directors.length; i++) {
            if (directors[i] == address(chamberA)) {
                chamberAIsDirector = true;
                break;
            }
        }
        assertTrue(chamberAIsDirector, "Chamber A should be a director of Chamber B");

        // 4. Fund Chamber B with some tokens to send to Chamber C
        uint256 transferAmount = 100e18;
        MockERC20(address(token)).mint(address(chamberB), transferAmount);

        // 6. Get other directors to confirm (need quorum)
        // Create second director
        uint256 tokenId2 = 2;
        address director2 = address(0x20);
        MockERC721(address(nft)).mintWithTokenId(director2, tokenId2);

        // Delegate to tokenId2
        chamberB.delegate(tokenId2, 500e18);

        // Create third director
        uint256 tokenId3 = 3;
        address director3 = address(0x30);
        MockERC721(address(nft)).mintWithTokenId(director3, tokenId3);

        // Delegate to tokenId3
        chamberB.delegate(tokenId3, 400e18);
        vm.roll(block.number + 1);

        // 5. Chamber A submits a transaction on Chamber B by calling as itself
        // This transaction will transfer tokens from Chamber B to Chamber C
        bytes memory transferData = abi.encodeWithSelector(IERC20.transfer.selector, address(chamberC), transferAmount);

        vm.prank(address(chamberA));
        chamberB.submitTransaction(tokenId, address(token), 0, transferData);

        // Verify transaction was submitted
        assertEq(chamberB.getTransactionCount(), 1);

        // director2 confirms the transaction
        vm.prank(director2);
        chamberB.confirmTransaction(tokenId2, 0);

        // director3 confirms the transaction
        vm.prank(director3);
        chamberB.confirmTransaction(tokenId3, 0);

        // 7. Check balances before execution
        uint256 chamberBBalanceBefore = token.balanceOf(address(chamberB));
        uint256 chamberCBalanceBefore = token.balanceOf(address(chamberC));

        // 8. Chamber A executes the transaction (transfer from Chamber B to Chamber C)
        vm.prank(address(chamberA));
        chamberB.executeTransaction(tokenId, 0, transferData);

        // 9. Verify balances after execution
        uint256 chamberBBalanceAfter = token.balanceOf(address(chamberB));
        uint256 chamberCBalanceAfter = token.balanceOf(address(chamberC));

        assertEq(
            chamberBBalanceBefore - chamberBBalanceAfter,
            transferAmount,
            "Chamber B balance should decrease by transfer amount"
        );
        assertEq(
            chamberCBalanceAfter - chamberCBalanceBefore,
            transferAmount,
            "Chamber C balance should increase by transfer amount"
        );

        // 10. Verify transaction executed
        (bool executed,,,,) = chamberB.getTransaction(0);
        assertTrue(executed, "Transaction should be executed");

        emit log("Test passed: Chamber A (as director of Chamber B) executed transaction from Chamber B to Chamber C");
        emit log_string(string(
                abi.encodePacked("Transferred ", vm.toString(transferAmount), " tokens from Chamber B to Chamber C")
            ));
    }
}
