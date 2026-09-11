// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockERC721} from "test/mock/MockERC721.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

/// @dev Mock chamber that returns address(0) for getProxyAdmin() to trigger defensive check
contract ZeroProxyAdminChamber {
    bytes32 public constant VERSION = "mock";

    function initialize(address, address, uint256, string calldata, string calldata) external {}

    function getProxyAdmin() external pure returns (address) {
        return address(0);
    }
}

contract FactoryTest is Test {
    event ChamberCreated(
        address indexed chamber,
        address indexed asset,
        address indexed nft,
        uint256 seats,
        string name,
        string symbol,
        address creator
    );

    event ChamberImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);

    Factory public factory;
    Chamber public implementation;
    MockERC20 public token;
    MockERC721 public nft;
    address public admin = makeAddr("admin");

    /// @dev ERC-1967 implementation slot (OpenZeppelin `ERC1967Utils.IMPLEMENTATION_SLOT`)
    bytes32 internal constant _ERC1967_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 1000000e18);
        nft = new MockERC721("Mock NFT", "MNFT");
        implementation = new Chamber();
        factory = new Factory(address(implementation), admin);
    }

    function _proxyImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, _ERC1967_IMPL_SLOT))));
    }

    function test_Factory_Constructor_SetsImplementationAndOwner() public view {
        assertEq(factory.implementation(), address(implementation));
        assertEq(factory.owner(), admin);
    }

    function test_Factory_Constructor_ZeroImplementation_Reverts() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        new Factory(address(0), admin);
    }

    function test_Factory_Constructor_EoaImplementation_Reverts() public {
        vm.expectRevert(Factory.NotContract.selector);
        new Factory(makeAddr("eoaImpl"), admin);
    }

    function test_Factory_Constructor_NonChamberCode_Reverts() public {
        vm.expectRevert(Factory.NotChamberImplementation.selector);
        new Factory(address(token), admin);
    }

    function test_Factory_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Factory(address(implementation), address(0));
    }

    function test_Factory_CreateChamber() public {
        address chamber = factory.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");

        uint256 codeSize;
        assembly {
            codeSize := extcodesize(chamber)
        }
        assertGt(codeSize, 0);

        IChamber chamberContract = IChamber(chamber);
        assertEq(chamberContract.name(), "Chamber Token");
        assertEq(chamberContract.symbol(), "CHMB");
        assertEq(chamberContract.getSeats(), 5);
        assertEq(chamberContract.asset(), address(token));
        assertEq(address(Chamber(payable(chamber)).nft()), address(nft));
    }

    function test_Factory_CreateChamber_EmitsChamberCreated() public {
        uint64 nonce = vm.getNonce(address(factory));
        address predicted = vm.computeCreateAddress(address(factory), nonce);

        vm.expectEmit(true, true, true, true, address(factory));
        emit ChamberCreated(predicted, address(token), address(nft), 5, "Chamber Token", "CHMB", address(this));

        address chamber = factory.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");
        assertEq(chamber, predicted);
    }

    function test_Factory_CreateChamber_ProxyAdminOwnership() public {
        address chamber = factory.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");

        address proxyAdminAddress = IChamber(chamber).getProxyAdmin();
        assertNotEq(proxyAdminAddress, address(0));

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        assertEq(proxyAdmin.owner(), chamber);
    }

    function test_Factory_CreateChamber_UsesCurrentImplementation() public {
        address chamber = factory.createChamber(address(token), address(nft), 5, "Chamber Token", "CHMB");
        assertEq(_proxyImplementation(chamber), address(implementation));
    }

    function test_Factory_CreateChamber_ZeroERC20_Reverts() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createChamber(address(0), address(nft), 5, "Chamber Token", "CHMB");
    }

    function test_Factory_CreateChamber_ZeroERC721_Reverts() public {
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.createChamber(address(token), address(0), 5, "Chamber Token", "CHMB");
    }

    function test_Factory_CreateChamber_ZeroSeats_Reverts() public {
        vm.expectRevert(Factory.InvalidSeats.selector);
        factory.createChamber(address(token), address(nft), 0, "Chamber Token", "CHMB");
    }

    function test_Factory_CreateChamber_TooManySeats_Reverts() public {
        vm.expectRevert(Factory.InvalidSeats.selector);
        factory.createChamber(address(token), address(nft), 21, "Chamber Token", "CHMB");
    }

    function test_Factory_CreateChamber_ZeroProxyAdmin_Reverts() public {
        ZeroProxyAdminChamber badImpl = new ZeroProxyAdminChamber();
        Factory badFactory = new Factory(address(badImpl), admin);

        vm.expectRevert(Factory.ZeroAddress.selector);
        badFactory.createChamber(address(token), address(nft), 5, "C", "C");
    }

    function test_Factory_SetImplementation_UpdatesPointer() public {
        Chamber newImpl = new Chamber();
        address prev = factory.implementation();

        vm.expectEmit(true, true, false, false, address(factory));
        emit ChamberImplementationUpdated(prev, address(newImpl));

        vm.prank(admin);
        factory.setImplementation(address(newImpl));

        assertEq(factory.implementation(), address(newImpl));
    }

    function test_Factory_SetImplementation_FutureDeploysOnly() public {
        address chamberBefore = factory.createChamber(address(token), address(nft), 5, "Before", "BEF");
        address implBefore = _proxyImplementation(chamberBefore);

        Chamber newImpl = new Chamber();
        vm.prank(admin);
        factory.setImplementation(address(newImpl));

        address chamberAfter = factory.createChamber(address(token), address(nft), 3, "After", "AFT");

        assertEq(_proxyImplementation(chamberBefore), implBefore);
        assertEq(_proxyImplementation(chamberAfter), address(newImpl));
        assertEq(IChamber(chamberBefore).getSeats(), 5);
        assertEq(IChamber(chamberAfter).getSeats(), 3);
    }

    function test_Factory_SetImplementation_SameImplementation_NoEmit() public {
        address curr = factory.implementation();
        vm.recordLogs();

        vm.prank(admin);
        factory.setImplementation(curr);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0);
    }

    function test_Factory_SetImplementation_Zero_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(Factory.ZeroAddress.selector);
        factory.setImplementation(address(0));
    }

    function test_Factory_SetImplementation_Eoa_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(Factory.NotContract.selector);
        factory.setImplementation(makeAddr("eoaImpl"));
    }

    function test_Factory_SetImplementation_NonChamberCode_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(Factory.NotChamberImplementation.selector);
        factory.setImplementation(address(token));
    }

    function test_Factory_SetImplementation_NotOwner_Reverts() public {
        Chamber newImpl = new Chamber();
        address stranger = makeAddr("stranger");

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        factory.setImplementation(address(newImpl));
    }

    function test_Factory_CreateChamber_AnyoneCanDeploy() public {
        address user = makeAddr("user");
        vm.prank(user);
        address chamber = factory.createChamber(address(token), address(nft), 5, "User Chamber", "USR");
        assertEq(IChamber(chamber).name(), "User Chamber");
    }
}
