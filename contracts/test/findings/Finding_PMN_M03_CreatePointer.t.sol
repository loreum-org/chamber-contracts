// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Factory} from "src/Factory.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployRegistry} from "test/utils/DeployRegistry.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

/// @dev Contract with code but no Chamber `VERSION()` getter.
contract EmptyCodeContract {}

/**
 * @title PMN-M03: Factory-only create path and implementation pointer (Solutions A + B)
 * @notice A: `Registry.createChamber` reverts. Factory create of a valid implementation succeeds.
 *         B: `setImplementation` rejects EOAs / empty code and probes existing `VERSION()`.
 *         C: Factory owner timelock/Safe is an M1 deploy checklist — skipped, no invented address.
 */
contract FindingPMNM03CreatePointerTest is Test {
    Factory public factory;
    Registry public registry;
    Chamber public implementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");

    /// @dev ERC-1967 implementation slot (OpenZeppelin `ERC1967Utils.IMPLEMENTATION_SLOT`)
    bytes32 internal constant _ERC1967_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        token = new MockERC20("Mock Token", "MCK", 0);
        nft = new MockERC721("Mock NFT", "MNFT");
        implementation = new Chamber();
        factory = new Factory(address(implementation), admin);
        registry = DeployRegistry.deploy(admin);
    }

    function _proxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, _ERC1967_IMPL_SLOT))));
    }

    /// @notice A later Factory `setImplementation` does not change an existing chamber's ProxyAdmin.
    function test_PMNM03_existingChamberKeepsOwnProxyAdmin() public {
        address chamber = factory.createChamber(address(token), address(nft), 5, "Keep Admin", "KEEP");
        address proxyAdminAddress = IChamber(chamber).getProxyAdmin();
        address implBefore = _proxyImplementation(chamber);
        assertEq(ProxyAdmin(proxyAdminAddress).owner(), chamber);

        Chamber newImpl = new Chamber();
        vm.prank(admin);
        factory.setImplementation(address(newImpl));

        assertEq(factory.implementation(), address(newImpl));
        assertEq(_proxyImplementation(chamber), implBefore, "existing proxy impl is unchanged");
        assertEq(IChamber(chamber).getProxyAdmin(), proxyAdminAddress);
        assertEq(ProxyAdmin(proxyAdminAddress).owner(), chamber, "existing ProxyAdmin owner is unchanged");
    }

    /// @notice After disable, Registry create fails. Factory create of a valid implementation succeeds.
    function test_PMNM03_caseA_registryCreateReverts() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 5, "Registry Path", "REG");

        address chamber = factory.createChamber(address(token), address(nft), 5, "Factory Path", "FAC");
        assertEq(IChamber(chamber).name(), "Factory Path");
        assertEq(IChamber(chamber).getSeats(), 5);
        assertEq(_proxyImplementation(chamber), address(implementation));
        assertEq(ProxyAdmin(IChamber(chamber).getProxyAdmin()).owner(), chamber);
    }

    /// @notice Reverts when the address has no code. A non-owner still reverts first.
    function test_PMNM03_caseB_setImplementationRejectsEoa() public {
        address eoa = makeAddr("eoaImpl");
        address stranger = makeAddr("stranger");
        assertEq(eoa.code.length, 0);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        factory.setImplementation(eoa);

        vm.prank(admin);
        vm.expectRevert(Factory.NotContract.selector);
        factory.setImplementation(eoa);

        assertEq(factory.implementation(), address(implementation));
    }

    /// @notice A contract with code that is not a Chamber implementation reverts.
    /// @dev Probe is the existing Chamber `VERSION()` getter (bytes32 public constant), not a fake selector.
    function test_PMNM03_caseB_setImplementationProbesVersion() public {
        EmptyCodeContract notChamber = new EmptyCodeContract();
        assertGt(address(notChamber).code.length, 0);

        vm.prank(admin);
        vm.expectRevert(Factory.NotChamberImplementation.selector);
        factory.setImplementation(address(notChamber));

        MockERC20 alsoNotChamber = new MockERC20("Not Chamber", "NOCH", 0);
        vm.prank(admin);
        vm.expectRevert(Factory.NotChamberImplementation.selector);
        factory.setImplementation(address(alsoNotChamber));

        Chamber valid = new Chamber();
        vm.prank(admin);
        factory.setImplementation(address(valid));
        assertEq(factory.implementation(), address(valid));
    }

    /// @notice Deploy assertion. Until a real mainnet owner exists, C is an M1 checklist item.
    function test_PMNM03_caseC_factoryOwnerIsTimelockOrSafe() public {
        vm.skip(true, "C is an M1 deploy checklist; do not invent a mainnet Factory owner address");
    }
}
