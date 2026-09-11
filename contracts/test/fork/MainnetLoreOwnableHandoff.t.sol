// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "src/Factory.sol";
import {Chamber} from "src/Chamber.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {ILoreOwnable, MainnetLoreHandoff} from "test/utils/MainnetLoreHandoff.sol";

/**
 * @title MainnetLoreOwnableHandoffTest
 * @notice Fork-only M1 rehearsal: deploy Factory + Chamber on an Ethereum mainnet fork, then
 *         impersonate the team Safe and `transferOwnership` of LORE to the Chamber proxy.
 *
 * @dev Run (from `contracts/`):
 *
 *      export MAINNET_RPC_URL=...   # or ETH_RPC_URL
 *      forge test --match-path test/fork/MainnetLoreOwnableHandoff.t.sol -vvv
 *
 *      Or: `make rehearse-mainnet-lore-handoff`
 *
 *      Without an RPC the test is skipped so `make ci-test` / `forge test` stay green.
 *      This is a dry run — it never broadcasts to live mainnet.
 *
 *      Success: logs Factory / Chamber impl / Chamber proxy, and `LORE.owner() == chamber`.
 *
 *      Board seating is not exercised here. Factory create leaves an empty board
 *      (`FactoryBootstrap.t.sol`); reachable quorum is 1 until directors seat (PMN-M01).
 *      Ownable handoff does not require a seated board.
 *
 *      Fork proves the *mechanics* of Factory create + single-step Ownable handoff.
 *      It does **not** decide CCA vs Ownable production sequencing (#188).
 */
contract MainnetLoreOwnableHandoffTest is Test {
    bool internal forked;

    function setUp() public {
        string memory rpc = _rpcUrl();
        if (bytes(rpc).length == 0) {
            // No mainnet RPC in CI / default `forge test` — skip rather than fail.
            return;
        }
        vm.createSelectFork(rpc);
        forked = true;
    }

    function test_FactoryCreateAndLoreOwnableHandoff() public {
        if (!forked) {
            vm.skip(true);
            return;
        }

        assertEq(block.chainid, 1, "fork must be Ethereum mainnet");

        ILoreOwnable lore = ILoreOwnable(MainnetLoreHandoff.LORE);
        assertEq(lore.owner(), MainnetLoreHandoff.TEAM_SAFE, "precondition: team Safe is LORE owner");
        _assertSingleStepOwnable(MainnetLoreHandoff.LORE);

        MainnetLoreHandoff.Deployment memory d =
            MainnetLoreHandoff.deployFactoryAndChamber(MainnetLoreHandoff.TEAM_SAFE);

        Chamber chamber = Chamber(d.chamber);
        assertEq(d.factory.owner(), MainnetLoreHandoff.TEAM_SAFE);
        assertEq(d.factory.implementation(), d.chamberImplementation);
        assertEq(chamber.asset(), MainnetLoreHandoff.LORE);
        assertEq(address(chamber.nft()), MainnetLoreHandoff.MEMBERSHIP_NFT);
        assertEq(chamber.getSeats(), MainnetLoreHandoff.SEATS);
        assertEq(chamber.name(), MainnetLoreHandoff.NAME);
        assertEq(chamber.symbol(), MainnetLoreHandoff.SYMBOL);
        assertEq(chamber.getDirectors().length, 0, "factory create leaves an empty board");
        assertEq(chamber.getQuorum(), 1, "empty board reachable quorum (PMN-M01)");

        address proxyAdmin = IChamber(d.chamber).getProxyAdmin();
        assertEq(ProxyAdmin(proxyAdmin).owner(), d.chamber, "ProxyAdmin owned by Chamber proxy");

        vm.deal(MainnetLoreHandoff.TEAM_SAFE, 1 ether);
        vm.prank(MainnetLoreHandoff.TEAM_SAFE);
        lore.transferOwnership(d.chamber);

        assertEq(lore.owner(), d.chamber, "LORE.owner() flipped to Chamber proxy");

        console.log("========================================");
        console.log("Mainnet fork rehearsal (Ownable handoff)");
        console.log("========================================");
        console.log("Factory                ", address(d.factory));
        console.log("Chamber implementation ", d.chamberImplementation);
        console.log("Chamber (LORE owner)   ", d.chamber);
        console.log("LORE.owner()           ", lore.owner());
        console.log("BoardLib/WalletLib     auto-linked by forge test (see script for explicit addrs)");
        console.log("========================================");
    }

    function _rpcUrl() internal view returns (string memory) {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length != 0) return rpc;
        return vm.envOr("ETH_RPC_URL", string(""));
    }

    /// @dev Deployed LORE ABI has `transferOwnership` / `owner` and no `pendingOwner`.
    function _assertSingleStepOwnable(address token) internal view {
        (bool ok, bytes memory ret) = token.staticcall(abi.encodeWithSignature("pendingOwner()"));
        if (ok && ret.length >= 32) {
            revert("LORE looks Ownable2Step; rehearsal expects single-step transferOwnership");
        }
    }
}
