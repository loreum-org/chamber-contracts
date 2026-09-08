// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

/// @dev Test-local copy of Registry initialize / impl pointer / create validation.
///      `new Registry()` in `src/` is rewritten to `vm.deployCode` (Halmos-unsupported).
///      Role names match Registry: DEFAULT_ADMIN_ROLE is 0x00, ADMIN_ROLE is keccak256("ADMIN_ROLE").
contract RegistryPointerHarness {
    error ZeroAddress();
    error InvalidSeats();
    error NotAdmin();

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

    address public implementation;
    address public proxyAdmin;
    uint256 public chamberCount;
    address private _admin;
    bool private _initialized;

    function initialize(address impl, address admin) external {
        if (_initialized) revert("already initialized");
        if (admin == address(0) || impl == address(0)) revert ZeroAddress();
        _initialized = true;
        implementation = impl;
        proxyAdmin = admin;
        _admin = admin;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        if (account != _admin || account == address(0)) return false;
        return role == DEFAULT_ADMIN_ROLE || role == ADMIN_ROLE;
    }

    function setChamberImplementation(address newImplementation) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        if (newImplementation == address(0)) revert ZeroAddress();
        if (implementation == newImplementation) return;
        implementation = newImplementation;
    }

    function createChamber(address erc20Token, address erc721Token, uint256 seats, string memory, string memory)
        external
        view
    {
        if (erc20Token == address(0) || erc721Token == address(0)) revert ZeroAddress();
        if (seats == 0 || seats > 20) revert InvalidSeats();
        if (implementation == address(0)) revert ZeroAddress();
    }

    function getChamberCount() external view returns (uint256) {
        return chamberCount;
    }
}

/// @notice Symbolic verification of Registry access control (deprecated create path)
contract RegistrySymTest is Test, SymTest {
    RegistryPointerHarness internal registry;

    address internal constant ADMIN = address(0xA11CE);
    address internal constant IMPL = address(0xB0B);

    function setUp() public {
        registry = new RegistryPointerHarness();
        registry.initialize(IMPL, ADMIN);
    }

    /// @dev initialize stores the intended implementation and grants admin roles
    function symbolicInitializeStoresAdminAndImpl() public {
        address nextAdmin = svm.createAddress("nextAdmin");
        address nextImpl = svm.createAddress("nextImpl");
        vm.assume(nextAdmin != address(0) && nextImpl != address(0));
        vm.assume(nextAdmin != nextImpl);

        RegistryPointerHarness fresh = new RegistryPointerHarness();
        fresh.initialize(nextImpl, nextAdmin);

        assertEq(fresh.implementation(), nextImpl);
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

        (bool success,) = address(registry).call(
            abi.encodeCall(RegistryPointerHarness.createChamber, (address(0x1), address(0x2), seats, "C", "C"))
        );

        assertFalse(success);
        assertEq(registry.getChamberCount(), countBefore);
        assertEq(registry.implementation(), IMPL);
    }

    /// @dev Zero token addresses cannot create a chamber
    function symbolicCreateChamberZeroTokenReverts() public {
        address erc20 = svm.createAddress("erc20");
        address erc721 = svm.createAddress("erc721");
        vm.assume(erc20 == address(0) || erc721 == address(0));

        uint256 countBefore = registry.getChamberCount();
        (bool success,) =
            address(registry).call(abi.encodeCall(RegistryPointerHarness.createChamber, (erc20, erc721, 3, "C", "C")));
        assertFalse(success);
        assertEq(registry.getChamberCount(), countBefore);
    }

    /// @dev Non-admin callers cannot update the chamber implementation pointer
    function symbolicSetImplementationNonAdminReverts() public {
        address caller = svm.createAddress("caller");
        address next = svm.createAddress("nextImpl");
        vm.assume(caller != ADMIN);
        vm.assume(next != address(0));
        vm.assume(!registry.hasRole(registry.ADMIN_ROLE(), caller));

        vm.prank(caller);
        (bool success,) = address(registry).call(abi.encodeCall(RegistryPointerHarness.setChamberImplementation, (next)));

        assertFalse(success);
        assertEq(registry.implementation(), IMPL);
    }

    /// @dev Admin can update the implementation pointer used for future chamber deploys
    function symbolicSetImplementationAdminUpdates() public {
        address next = svm.createAddress("nextImpl");
        vm.assume(next != address(0) && next != IMPL);

        vm.prank(ADMIN);
        registry.setChamberImplementation(next);

        assertEq(registry.implementation(), next);
    }

    /// @dev Same-address setChamberImplementation is a no-op
    function symbolicSetImplementationSameAddressNoOp() public {
        vm.prank(ADMIN);
        registry.setChamberImplementation(IMPL);
        assertEq(registry.implementation(), IMPL);
    }
}
