// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @dev Test-local copy of Factory's pointer + create validation.
///      `new Factory()` in `src/` is rewritten to `vm.deployCode` (Halmos-unsupported).
///      Logic must stay aligned with `src/Factory.sol`.
contract FactoryPointerHarness is Ownable {
    error ZeroAddress();
    error InvalidSeats();

    address private _implementation;

    constructor(address implementation_, address admin) Ownable(admin) {
        if (implementation_ == address(0)) revert ZeroAddress();
        _implementation = implementation_;
    }

    function implementation() external view returns (address) {
        return _implementation;
    }

    function setImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        if (_implementation == newImplementation) return;
        _implementation = newImplementation;
    }

    /// @dev Same pre-proxy checks as Factory.createChamber; does not deploy a proxy.
    function createChamber(address erc20Token, address erc721Token, uint256 seats, string memory, string memory)
        external
        view
    {
        if (erc20Token == address(0) || erc721Token == address(0)) revert ZeroAddress();
        if (seats == 0 || seats > 20) revert InvalidSeats();
        if (_implementation == address(0)) revert ZeroAddress();
    }
}

/// @notice Symbolic verification of Factory owner / implementation invariants
contract FactorySymTest is Test, SymTest {
    FactoryPointerHarness internal factory;

    address internal constant ADMIN = address(0xA11CE);
    address internal constant IMPL = address(0xB0B);

    function setUp() public {
        factory = new FactoryPointerHarness(IMPL, ADMIN);
    }

    /// @dev Constructor stores the intended implementation and Ownable admin
    function symbolicConstructorStoresAdminAndImpl() public {
        address nextAdmin = svm.createAddress("nextAdmin");
        address nextImpl = svm.createAddress("nextImpl");
        vm.assume(nextAdmin != address(0) && nextImpl != address(0));

        FactoryPointerHarness fresh = new FactoryPointerHarness(nextImpl, nextAdmin);

        assertEq(fresh.implementation(), nextImpl);
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
        new FactoryPointerHarness(impl, owner_);
    }

    /// @dev Owner may replace the future-deploy implementation; non-owners cannot
    function symbolicSetImplementationOnlyOwner() public {
        address caller = svm.createAddress("caller");
        address next = svm.createAddress("nextImpl");
        vm.assume(caller != ADMIN);
        vm.assume(next != address(0) && next != IMPL);

        vm.prank(caller);
        (bool success,) = address(factory).call(abi.encodeCall(FactoryPointerHarness.setImplementation, (next)));
        assertFalse(success);
        assertEq(factory.implementation(), IMPL);

        vm.prank(ADMIN);
        factory.setImplementation(next);
        assertEq(factory.implementation(), next);
        assertEq(factory.owner(), ADMIN);
    }

    /// @dev Same-address setImplementation is a no-op; zero impl reverts
    function symbolicSetImplementationSameOrZero() public {
        vm.prank(ADMIN);
        factory.setImplementation(IMPL);
        assertEq(factory.implementation(), IMPL);

        vm.prank(ADMIN);
        (bool success,) = address(factory).call(abi.encodeCall(FactoryPointerHarness.setImplementation, (address(0))));
        assertFalse(success);
        assertEq(factory.implementation(), IMPL);
    }

    /// @dev Invalid createChamber inputs revert and leave impl / owner unchanged
    function symbolicCreateChamberInvalidInputsDoNotMutate() public {
        uint256 seats = svm.createUint256("seats");
        address erc20 = svm.createAddress("erc20");
        address erc721 = svm.createAddress("erc721");

        bool invalidSeats = seats == 0 || seats > 20;
        bool invalidTokens = erc20 == address(0) || erc721 == address(0);
        vm.assume(invalidSeats || invalidTokens);

        (bool success,) =
            address(factory).call(abi.encodeCall(FactoryPointerHarness.createChamber, (erc20, erc721, seats, "C", "C")));
        assertFalse(success);
        assertEq(factory.implementation(), IMPL);
        assertEq(factory.owner(), ADMIN);
    }
}
