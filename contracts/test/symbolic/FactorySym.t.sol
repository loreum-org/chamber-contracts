// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";

/// @notice Symbolic verification of Factory owner / implementation invariants
/// @dev `createChamber` success deploys `TransparentUpgradeableProxy` and is not
///      executable under Halmos 0.3.3 (`vm.deployCode`). This suite checks that
///      the factory only *accepts* the intended admin/impl and that invalid
///      create inputs cannot mutate that pointer. The proxy+ProxyAdmin handoff
///      is covered by `test/unit/Factory.t.sol`, not here.
contract FactorySymTest is Test, SymTest {
    Factory internal factory;
    Chamber internal implementation;
    MockERC20 internal token;
    MockERC721 internal nft;

    address internal admin = address(0xA11CE);

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        implementation = new Chamber();
        factory = new Factory(address(implementation), admin);
    }

    /// @dev Constructor stores the intended implementation and Ownable admin
    function symbolicConstructorStoresAdminAndImpl() public {
        address nextAdmin = svm.createAddress("nextAdmin");
        vm.assume(nextAdmin != address(0));

        Chamber impl = new Chamber();
        Factory fresh = new Factory(address(impl), nextAdmin);

        assertEq(fresh.implementation(), address(impl));
        assertEq(fresh.owner(), nextAdmin);
    }

    /// @dev Zero implementation is rejected; zero admin is rejected by Ownable
    function symbolicConstructorRejectsZeroAddresses() public {
        address maybeAdmin = svm.createAddress("maybeAdmin");
        address maybeImpl = svm.createAddress("maybeImpl");
        vm.assume(maybeAdmin == address(0) || maybeImpl == address(0));

        (bool success,) = address(this).call(abi.encodeCall(this.deployFactory, (maybeImpl, maybeAdmin)));
        assertFalse(success);
    }

    function deployFactory(address impl, address owner_) external {
        new Factory(impl, owner_);
    }

    /// @dev Owner may replace the future-deploy implementation; non-owners cannot
    function symbolicSetImplementationOnlyOwner() public {
        address caller = svm.createAddress("caller");
        Chamber next = new Chamber();
        vm.assume(caller != admin);
        vm.assume(address(next) != address(0));

        address implBefore = factory.implementation();

        vm.prank(caller);
        (bool success,) = address(factory).call(abi.encodeCall(Factory.setImplementation, (address(next))));
        assertFalse(success);
        assertEq(factory.implementation(), implBefore);

        vm.prank(admin);
        factory.setImplementation(address(next));
        assertEq(factory.implementation(), address(next));
        assertEq(factory.owner(), admin);
    }

    /// @dev Same-address setImplementation is a no-op; zero impl reverts
    function symbolicSetImplementationSameOrZero() public {
        address current = factory.implementation();
        vm.prank(admin);
        factory.setImplementation(current);
        assertEq(factory.implementation(), current);

        vm.prank(admin);
        (bool success,) = address(factory).call(abi.encodeCall(Factory.setImplementation, (address(0))));
        assertFalse(success);
        assertEq(factory.implementation(), current);
    }

    /// @dev Invalid createChamber inputs revert and leave impl / owner unchanged
    function symbolicCreateChamberInvalidInputsDoNotMutate() public {
        uint256 seats = svm.createUint256("seats");
        address erc20 = svm.createAddress("erc20");
        address erc721 = svm.createAddress("erc721");

        bool invalidSeats = seats == 0 || seats > 20;
        bool invalidTokens = erc20 == address(0) || erc721 == address(0);
        vm.assume(invalidSeats || invalidTokens);

        address implBefore = factory.implementation();
        address ownerBefore = factory.owner();

        (bool success,) =
            address(factory).call(abi.encodeCall(Factory.createChamber, (erc20, erc721, seats, "Chamber", "CHMB")));
        assertFalse(success);
        assertEq(factory.implementation(), implBefore);
        assertEq(factory.owner(), ownerBefore);
    }
}
