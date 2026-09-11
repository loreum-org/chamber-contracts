// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Registry} from "src/Registry.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {DeployRegistry} from "test/utils/DeployRegistry.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract RegistryTest is Test {
    event ChamberImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);

    Registry public registry;
    Chamber public implementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");

    /// @dev ERC-7201 `RegistryStorage` namespace; `chambers` is field index 2.
    bytes32 internal constant _REGISTRY_STORAGE_SLOT =
        0xf6315592a63ddf317bd8b41aa1ba894c04251b3cfbd8a95258342cd83f2a4600;

    /// @dev OZ 5.1.0 `AccessControlUpgradeable` ERC-7201 slot (`openzeppelin.storage.AccessControl`).
    bytes32 internal constant _ACCESS_CONTROL_STORAGE =
        0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    /// @dev ERC-1967 admin slot (OpenZeppelin `ERC1967Utils.ADMIN_SLOT`)
    bytes32 internal constant _ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");

        implementation = new Chamber();
        registry = DeployRegistry.deploy(admin);
    }

    function _chambersArraySlot() internal pure returns (bytes32) {
        return bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 2);
    }

    function _assetsArraySlot() internal pure returns (bytes32) {
        return bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 3);
    }

    function _isChamberSlot(address chamber) internal pure returns (bytes32) {
        return keccak256(abi.encode(chamber, bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 4)));
    }

    function _chambersByAssetArraySlot(address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(asset, bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 6)));
    }

    function _parentChamberSlot(address chamber) internal pure returns (bytes32) {
        return keccak256(abi.encode(chamber, bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 7)));
    }

    function _childChambersArraySlot(address parent) internal pure returns (bytes32) {
        return keccak256(abi.encode(parent, bytes32(uint256(_REGISTRY_STORAGE_SLOT) + 8)));
    }

    function _pushAddress(bytes32 arraySlot, address value) internal {
        uint256 len = uint256(vm.load(address(registry), arraySlot));
        bytes32 data = keccak256(abi.encode(arraySlot));
        vm.store(address(registry), bytes32(uint256(data) + len), bytes32(uint256(uint160(value))));
        vm.store(address(registry), arraySlot, bytes32(len + 1));
    }

    /// @dev Plant a historical index row. New creates cannot write this graph (PMN-M03 A).
    function _plantChamber(address chamber, address asset) internal {
        _pushAddress(_chambersArraySlot(), chamber);
        vm.store(address(registry), _isChamberSlot(chamber), bytes32(uint256(1)));
        _pushAddress(_chambersByAssetArraySlot(asset), chamber);
        if (uint256(vm.load(address(registry), _assetsArraySlot())) == 0) {
            _pushAddress(_assetsArraySlot(), asset);
        }
    }

    function test_Registry_Initialize() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
    }

    function test_Registry_Initialize_ZeroAdmin_Reverts() public {
        address payable proxy = payable(Clones.clone(address(new Registry())));
        Registry proxyRegistry = Registry(proxy);

        vm.expectRevert(Registry.ZeroAddress.selector);
        proxyRegistry.initialize(address(implementation), address(0));
    }

    function test_Registry_Initialize_ZeroImplementation_Reverts() public {
        address payable proxy = payable(Clones.clone(address(new Registry())));
        Registry proxyRegistry = Registry(proxy);

        vm.expectRevert(Registry.ZeroAddress.selector);
        proxyRegistry.initialize(address(0), admin);
    }

    function test_Registry_CreateChamber_Disabled() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");

        assertEq(registry.getChamberCount(), 0);
        assertFalse(registry.isChamber(address(token)));
    }

    function test_Registry_CreateChamber_ZeroERC20_StillDisabled() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(0), address(nft), 5, "Chamber Token", "CHMB");
    }

    function test_Registry_CreateChamber_ZeroERC721_StillDisabled() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(0), 5, "Chamber Token", "CHMB");
    }

    function test_Registry_CreateChamber_ZeroSeats_StillDisabled() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 0, "Chamber Token", "CHMB");
    }

    function test_Registry_CreateChamber_TooManySeats_StillDisabled() public {
        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 21, "Chamber Token", "CHMB");
    }

    function test_Registry_IsChamber_False() public view {
        assertFalse(registry.isChamber(address(0x1234)));
    }

    function test_Registry_GetAllChambers_Empty() public view {
        address[] memory chambers = registry.getAllChambers();
        assertEq(chambers.length, 0);
    }

    function test_Registry_GetChamberCount_Empty() public view {
        assertEq(registry.getChamberCount(), 0);
    }

    function test_Registry_Getters() public view {
        assertNotEq(registry.implementation(), address(0));
        assertEq(registry.proxyAdmin(), admin);
    }

    function test_Registry_HistoricalIndex_Getters() public {
        address chamber1 = makeAddr("hist1");
        address chamber2 = makeAddr("hist2");
        _plantChamber(chamber1, address(token));
        _plantChamber(chamber2, address(token));

        assertTrue(registry.isChamber(chamber1));
        assertTrue(registry.isChamber(chamber2));
        assertEq(registry.getChamberCount(), 2);

        address[] memory chambers = registry.getAllChambers();
        assertEq(chambers.length, 2);
        assertEq(chambers[0], chamber1);
        assertEq(chambers[1], chamber2);

        address[] memory byAsset = registry.getChambersByAsset(address(token));
        assertEq(byAsset.length, 2);
        assertEq(registry.getAssets().length, 1);
        assertEq(registry.getAssets()[0], address(token));
    }

    function test_Registry_GetChambers_LimitZero_Empty() public {
        _plantChamber(makeAddr("hist"), address(token));
        address[] memory page = registry.getChambers(0, 0);
        assertEq(page.length, 0);
    }

    function test_Registry_GetChambers_Pagination() public {
        address[5] memory planted;
        for (uint256 i = 0; i < 5; i++) {
            planted[i] = makeAddr(string.concat("hist", vm.toString(i)));
            _plantChamber(planted[i], address(token));
        }

        address[] memory chambers = registry.getChambers(2, 1);
        assertEq(chambers.length, 2);
        assertEq(chambers[0], planted[1]);
        assertEq(chambers[1], planted[2]);

        chambers = registry.getChambers(2, 5);
        assertEq(chambers.length, 0);

        chambers = registry.getChambers(3, 3);
        assertEq(chambers.length, 2);
    }

    function test_Registry_GetChambers_ClampsOversizedLimit() public {
        address first = makeAddr("first");
        _plantChamber(first, address(token));
        vm.store(address(registry), _chambersArraySlot(), bytes32(uint256(10_000)));

        address[] memory page = registry.getChambers(type(uint256).max, 0);
        assertEq(page.length, registry.MAX_PAGE_SIZE());
        assertEq(page[0], first);
    }

    function test_Registry_GetAllChambers_CapsAtMaxPageSize() public {
        address first = makeAddr("first");
        _plantChamber(first, address(token));
        vm.store(address(registry), _chambersArraySlot(), bytes32(uint256(10_000)));

        assertEq(registry.getChamberCount(), 10_000);

        address[] memory page = registry.getAllChambers();
        assertEq(page.length, registry.MAX_PAGE_SIZE());
        assertEq(page[0], first);

        address[] memory next = registry.getChambers(registry.MAX_PAGE_SIZE(), registry.MAX_PAGE_SIZE());
        assertEq(next.length, registry.MAX_PAGE_SIZE());
    }

    function test_Registry_GetChambersByAsset_PaginationAndCap() public {
        address chamber1 = makeAddr("c1");
        address chamber2 = makeAddr("c2");
        address chamber3 = makeAddr("c3");
        _plantChamber(chamber1, address(token));
        _plantChamber(chamber2, address(token));
        _plantChamber(chamber3, address(token));

        assertEq(registry.getChambersByAssetCount(address(token)), 3);

        address[] memory page = registry.getChambersByAsset(address(token), 2, 0);
        assertEq(page.length, 2);
        assertEq(page[0], chamber1);
        assertEq(page[1], chamber2);

        page = registry.getChambersByAsset(address(token), 2, 2);
        assertEq(page.length, 1);
        assertEq(page[0], chamber3);

        page = registry.getChambersByAsset(address(token), 2, 5);
        assertEq(page.length, 0);

        vm.store(address(registry), _chambersByAssetArraySlot(address(token)), bytes32(uint256(10_000)));
        assertEq(registry.getChambersByAssetCount(address(token)), 10_000);
        address[] memory capped = registry.getChambersByAsset(address(token));
        assertEq(capped.length, registry.MAX_PAGE_SIZE());
        assertEq(capped[0], chamber1);

        address[] memory clamped = registry.getChambersByAsset(address(token), type(uint256).max, 0);
        assertEq(clamped.length, registry.MAX_PAGE_SIZE());
    }

    function test_Registry_GetChildChambers_PaginationAndCap() public {
        address parent = makeAddr("parent");
        address child1 = makeAddr("child1");
        address child2 = makeAddr("child2");
        address child3 = makeAddr("child3");

        _pushAddress(_childChambersArraySlot(parent), child1);
        _pushAddress(_childChambersArraySlot(parent), child2);
        _pushAddress(_childChambersArraySlot(parent), child3);
        vm.store(address(registry), _parentChamberSlot(child1), bytes32(uint256(uint160(parent))));
        vm.store(address(registry), _parentChamberSlot(child2), bytes32(uint256(uint160(parent))));
        vm.store(address(registry), _parentChamberSlot(child3), bytes32(uint256(uint160(parent))));

        assertEq(registry.getChildChamberCount(parent), 3);
        assertEq(registry.getParentChamber(child1), parent);
        assertEq(registry.getParentChamber(parent), address(0));

        address[] memory page = registry.getChildChambers(parent, 2, 0);
        assertEq(page.length, 2);
        assertEq(page[0], child1);
        assertEq(page[1], child2);

        page = registry.getChildChambers(parent, 2, 2);
        assertEq(page.length, 1);
        assertEq(page[0], child3);

        page = registry.getChildChambers(parent, 1, 10);
        assertEq(page.length, 0);

        vm.store(address(registry), _childChambersArraySlot(parent), bytes32(uint256(10_000)));
        assertEq(registry.getChildChamberCount(parent), 10_000);
        address[] memory capped = registry.getChildChambers(parent);
        assertEq(capped.length, registry.MAX_PAGE_SIZE());
        assertEq(capped[0], child1);

        address[] memory clamped = registry.getChildChambers(parent, type(uint256).max, 0);
        assertEq(clamped.length, registry.MAX_PAGE_SIZE());
    }

    function test_Registry_GetAssets_PaginationAndCap() public {
        MockERC20 token2 = new MockERC20("Token2", "T2", 1e18);
        MockERC20 token3 = new MockERC20("Token3", "T3", 1e18);

        _plantChamber(makeAddr("c1"), address(token));
        _pushAddress(_assetsArraySlot(), address(token2));
        _pushAddress(_assetsArraySlot(), address(token3));
        _plantChamber(makeAddr("c2"), address(token2));
        _plantChamber(makeAddr("c3"), address(token3));

        assertEq(registry.getAssetCount(), 3);

        address[] memory page = registry.getAssets(2, 0);
        assertEq(page.length, 2);
        assertEq(page[0], address(token));
        assertEq(page[1], address(token2));

        page = registry.getAssets(2, 2);
        assertEq(page.length, 1);
        assertEq(page[0], address(token3));

        vm.store(address(registry), _assetsArraySlot(), bytes32(uint256(10_000)));
        assertEq(registry.getAssetCount(), 10_000);
        address[] memory capped = registry.getAssets();
        assertEq(capped.length, registry.MAX_PAGE_SIZE());
        assertEq(capped[0], address(token));
    }

    function test_Registry_GetParentChamber_None() public {
        address nobody = makeAddr("nobody");
        assertEq(registry.getParentChamber(nobody), address(0));
    }

    function test_Registry_GetChildChambers_None() public {
        address nobody = makeAddr("nobody");
        assertEq(registry.getChildChambers(nobody).length, 0);
    }

    function test_Registry_SetChamberImplementation_UpdatesPointer() public {
        Chamber newImpl = new Chamber();
        address prev = registry.implementation();

        vm.expectEmit(true, true, false, false);
        emit ChamberImplementationUpdated(prev, address(newImpl));

        vm.prank(admin);
        registry.setChamberImplementation(address(newImpl));

        assertEq(registry.implementation(), address(newImpl));
    }

    function test_Registry_SetChamberImplementation_DoesNotUnlockCreate() public {
        Chamber newImpl = new Chamber();
        vm.prank(admin);
        registry.setChamberImplementation(address(newImpl));

        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");
        assertEq(registry.getChamberCount(), 0);
    }

    function test_Registry_SetChamberImplementation_SameImplementation_NoEmit() public {
        address curr = registry.implementation();
        vm.recordLogs();

        vm.prank(admin);
        registry.setChamberImplementation(curr);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0);
    }

    function test_Registry_SetChamberImplementation_Zero_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setChamberImplementation(address(0));
    }

    function test_Registry_SetChamberImplementation_NotAdmin_Reverts() public {
        Chamber newImpl = new Chamber();
        address stranger = makeAddr("stranger");
        bytes32 adminRole = registry.ADMIN_ROLE();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, adminRole)
        );
        registry.setChamberImplementation(address(newImpl));
    }

    function _roleMemberSlot(bytes32 namespace, bytes32 role, address account) internal pure returns (bytes32) {
        bytes32 roleDataSlot = keccak256(abi.encode(role, namespace));
        return keccak256(abi.encode(account, roleDataSlot));
    }

    function _registryProxyAdmin() internal view returns (ProxyAdmin) {
        return ProxyAdmin(address(uint160(uint256(vm.load(address(registry), _ERC1967_ADMIN_SLOT)))));
    }

    function test_Registry_AccessControlUsesErc7201Namespace() public view {
        bytes32 defaultAdminRole = registry.DEFAULT_ADMIN_ROLE();
        bytes32 adminRole = registry.ADMIN_ROLE();

        assertEq(
            uint256(vm.load(address(registry), _roleMemberSlot(_ACCESS_CONTROL_STORAGE, defaultAdminRole, admin))), 1
        );
        assertEq(uint256(vm.load(address(registry), _roleMemberSlot(_ACCESS_CONTROL_STORAGE, adminRole, admin))), 1);

        // Legacy non-upgradeable AccessControl stored `_roles` at sequential slot 0.
        assertEq(uint256(vm.load(address(registry), _roleMemberSlot(bytes32(0), defaultAdminRole, admin))), 0);
        assertEq(uint256(vm.load(address(registry), _roleMemberSlot(bytes32(0), adminRole, admin))), 0);
    }

    function test_Registry_GrantAndRevokeAdminRole() public {
        address operator = makeAddr("operator");
        bytes32 adminRole = registry.ADMIN_ROLE();
        Chamber newImpl = new Chamber();

        vm.prank(admin);
        registry.grantRole(adminRole, operator);
        assertTrue(registry.hasRole(adminRole, operator));

        vm.prank(operator);
        registry.setChamberImplementation(address(newImpl));
        assertEq(registry.implementation(), address(newImpl));

        vm.prank(admin);
        registry.revokeRole(adminRole, operator);
        assertFalse(registry.hasRole(adminRole, operator));

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, operator, adminRole)
        );
        registry.setChamberImplementation(address(implementation));
    }

    function test_Registry_NonAdminCannotGrantRole() public {
        address stranger = makeAddr("stranger");
        bytes32 adminRole = registry.ADMIN_ROLE();
        bytes32 defaultAdminRole = registry.DEFAULT_ADMIN_ROLE();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, defaultAdminRole)
        );
        registry.grantRole(adminRole, stranger);
    }

    function test_Registry_InitializeCannotBeCalledTwice() public {
        vm.expectRevert();
        registry.initialize(address(implementation), admin);
    }

    function test_Registry_UpgradePreservesRolesAndCreateStaysDisabled() public {
        address planted = makeAddr("historical");
        _plantChamber(planted, address(token));

        address chamberImpl = registry.implementation();
        Registry newRegistryImpl = new Registry();
        ProxyAdmin registryProxyAdmin = _registryProxyAdmin();
        assertEq(registryProxyAdmin.owner(), admin);

        vm.prank(admin);
        registryProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(registry)), address(newRegistryImpl), "");

        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
        assertEq(registry.getChamberCount(), 1);
        assertTrue(registry.isChamber(planted));
        assertEq(registry.implementation(), chamberImpl);

        vm.expectRevert(Registry.CreateDisabled.selector);
        registry.createChamber(address(token), address(nft), 3, "C2", "C2");
        assertEq(registry.getChamberCount(), 1);
    }
}
