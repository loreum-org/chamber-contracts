// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {HalmosDeploy} from "test/symbolic/HalmosDeploy.sol";

/// @notice Symbolic verification of Registry access control (deprecated create path)
/// @dev Initializes the Registry implementation (HalmosDeploy). `createChamber` success
///      deploys `TransparentUpgradeableProxy` and is not executable under Halmos 0.3.3.
contract RegistrySymTest is Test, SymTest {
    Registry internal registry;
    Chamber internal alternateImpl;
    MockERC20 internal token;
    MockERC721 internal nft;

    address internal admin = address(0xA11CE);

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        alternateImpl = new Chamber();
        registry = HalmosDeploy.registry(address(alternateImpl), admin);
    }

    /// @dev initialize stores the intended implementation and grants admin roles
    function symbolicInitializeStoresAdminAndImpl() public {
        address nextAdmin = svm.createAddress("nextAdmin");
        vm.assume(nextAdmin != address(0));

        Chamber impl = new Chamber();
        Registry fresh = HalmosDeploy.registry(address(impl), nextAdmin);

        assertEq(fresh.implementation(), address(impl));
        assertEq(fresh.proxyAdmin(), nextAdmin);
        assertTrue(fresh.hasRole(fresh.DEFAULT_ADMIN_ROLE(), nextAdmin));
        assertTrue(fresh.hasRole(fresh.ADMIN_ROLE(), nextAdmin));
        assertEq(fresh.getChamberCount(), 0);
    }

    /// @dev Zero or excessive seat counts cannot create a chamber
    function symbolicCreateChamberInvalidSeatsReverts() public {
        uint256 seats = svm.createUint256("seats");
        vm.assume(seats == 0 || seats > 20);

        uint256 countBefore = registry.getChamberCount();
        address implBefore = registry.implementation();

        (bool success,) = address(registry).call(
            abi.encodeCall(Registry.createChamber, (address(token), address(nft), seats, "Chamber", "CHMB"))
        );

        assertFalse(success);
        assertEq(registry.getChamberCount(), countBefore);
        assertEq(registry.implementation(), implBefore);
    }

    /// @dev Zero token addresses cannot create a chamber
    function symbolicCreateChamberZeroTokenReverts() public {
        address erc20 = svm.createAddress("erc20");
        address erc721 = svm.createAddress("erc721");
        vm.assume(erc20 == address(0) || erc721 == address(0));

        uint256 countBefore = registry.getChamberCount();
        (bool success,) =
            address(registry).call(abi.encodeCall(Registry.createChamber, (erc20, erc721, 3, "Chamber", "CHMB")));
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
            address(registry).call(abi.encodeCall(Registry.setChamberImplementation, (address(new Chamber()))));

        assertFalse(success);
        assertEq(registry.implementation(), implBefore);
    }

    /// @dev Admin can update the implementation pointer used for future chamber deploys
    function symbolicSetImplementationAdminUpdates() public {
        Chamber next = new Chamber();
        address implBefore = registry.implementation();
        vm.assume(address(next) != implBefore);

        vm.prank(admin);
        registry.setChamberImplementation(address(next));

        assertEq(registry.implementation(), address(next));
    }

    /// @dev Same-address setChamberImplementation is a no-op
    function symbolicSetImplementationSameAddressNoOp() public {
        address current = registry.implementation();
        vm.prank(admin);
        registry.setChamberImplementation(current);
        assertEq(registry.implementation(), current);
    }
}
