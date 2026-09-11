// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployRegistry} from "test/utils/DeployRegistry.sol";

/// @notice Symbolic verification of Registry access control. Create is disabled (PMN-M03 A).
contract RegistrySymTest is Test, SymTest {
    Registry internal registry;
    Chamber internal alternateImpl;
    MockERC20 internal token;
    MockERC721 internal nft;

    address internal admin = makeAddr("admin");

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1_000_000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        registry = DeployRegistry.deploy(admin);
        alternateImpl = new Chamber();
    }

    /// @dev Valid seats still cannot create; Factory is the Ethereum create path
    function symbolicCreateChamberValidSeats() public {
        uint256 seats = svm.createUint(5, "seats");
        vm.assume(seats >= 1 && seats <= 20);

        uint256 countBefore = registry.getChamberCount();

        (bool success,) = address(registry).call(
            abi.encodeCall(Registry.createChamber, (address(token), address(nft), seats, "Chamber", "CHMB"))
        );

        assertFalse(success);
        assertEq(registry.getChamberCount(), countBefore);
    }

    /// @dev Invalid seats also revert (create is unconditionally disabled)
    function symbolicCreateChamberInvalidSeatsReverts() public {
        uint256 seats = svm.createUint256("seats");
        vm.assume(seats == 0 || seats > 20);

        uint256 countBefore = registry.getChamberCount();

        (bool success,) = address(registry).call(
            abi.encodeCall(Registry.createChamber, (address(token), address(nft), seats, "Chamber", "CHMB"))
        );

        assertFalse(success);
        assertEq(registry.getChamberCount(), countBefore);
    }

    /// @dev Non-admin callers cannot update the chamber implementation pointer
    function symbolicSetImplementationNonAdminReverts() public {
        address caller = svm.createAddress("caller");
        vm.assume(caller != admin);
        vm.assume(!registry.hasRole(registry.ADMIN_ROLE(), caller));

        address implBefore = registry.implementation();

        vm.prank(caller);
        (bool success,) =
            address(registry).call(abi.encodeCall(Registry.setChamberImplementation, (address(alternateImpl))));

        assertFalse(success);
        assertEq(registry.implementation(), implBefore);
    }

    /// @dev Admin can update the leftover implementation pointer (unused after create disable)
    function symbolicSetImplementationAdminUpdates() public {
        address implBefore = registry.implementation();
        vm.assume(address(alternateImpl) != implBefore);

        vm.prank(admin);
        registry.setChamberImplementation(address(alternateImpl));

        assertEq(registry.implementation(), address(alternateImpl));
    }

    /// @dev Create cannot register an asset in the leftover index
    function symbolicCreateChamberRegistersAsset() public {
        uint256 seats = svm.createUint(5, "seats");
        vm.assume(seats >= 1 && seats <= 20);

        assertEq(registry.getAssets().length, 0);

        (bool success,) = address(registry).call(
            abi.encodeCall(Registry.createChamber, (address(token), address(nft), seats, "Chamber", "CHMB"))
        );

        assertFalse(success);
        assertEq(registry.getAssets().length, 0);
        assertEq(registry.getChambersByAsset(address(token)).length, 0);
    }
}
