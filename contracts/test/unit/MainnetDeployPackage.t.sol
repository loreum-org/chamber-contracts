// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MainnetLoreHandoff} from "test/utils/MainnetLoreHandoff.sol";
import {MainnetDeployGuard} from "script/MainnetDeployGuard.sol";

/// @dev Guards the verified mainnet package: TBD file, no invented Factory/Chamber,
///      rehearsal still blocks broadcast, scripts never call transferOwnership.
contract MainnetDeployPackageTest is Test {
    address internal constant SEPOLIA_FACTORY = 0x43aA92c8A26392f21F63cdA88B6BaB5031C40550;

    function test_mainnetTxtHasTbdDeployAddresses() public view {
        string memory raw = vm.readFile("deployments/mainnet.txt");
        assertTrue(_contains(raw, "Factory                   TBD"), "Factory line must stay TBD");
        assertTrue(_contains(raw, "Chamber implementation    TBD"), "impl line must stay TBD");
        assertTrue(_contains(raw, "BoardLib                  TBD"), "BoardLib line must stay TBD");
        assertTrue(_contains(raw, "WalletLib                 TBD"), "WalletLib line must stay TBD");
        assertTrue(_contains(raw, "Chamber (proxy)           TBD"), "Chamber proxy must stay TBD");
        assertTrue(_contains(raw, "Registry (proxy)          TBD"), "Registry must stay TBD");
        assertEq(_labeledValue(raw, "Factory"), "TBD", "Factory value must stay TBD");
    }

    function test_appMainnetTxtMatchesContractsCopy() public view {
        assertEq(
            vm.readFile("deployments/mainnet.txt"),
            vm.readFile("../app/contracts/deployments/mainnet.txt"),
            "keep contracts/ and app/ mainnet.txt copies identical"
        );
    }

    function test_mainnetTxtRecordsLiveTokensOnly() public view {
        string memory raw = vm.readFile("deployments/mainnet.txt");
        assertTrue(_containsInsensitive(raw, _hexNoPrefix(MainnetLoreHandoff.LORE)), "LORE");
        assertTrue(_containsInsensitive(raw, _hexNoPrefix(MainnetLoreHandoff.MEMBERSHIP_NFT)), "membership NFT");
        assertTrue(_containsInsensitive(raw, _hexNoPrefix(MainnetLoreHandoff.TEAM_SAFE)), "team Safe");
        assertTrue(_contains(raw, "NOT DEPLOYED"), "template must say not deployed");
        assertTrue(_contains(raw, "#208"), "must cite PMN-H01 blocker");
    }

    function test_mainnetTxtDoesNotTreatSepoliaFactoryAsMainnetFactory() public view {
        string memory raw = vm.readFile("deployments/mainnet.txt");
        assertEq(_labeledValue(raw, "Factory"), "TBD");
        assertEq(_labeledValue(raw, "Chamber implementation"), "TBD");
        // Sepolia Factory may appear only as a do-not-copy warning, not as the Factory value.
        assertTrue(_containsInsensitive(raw, _hexNoPrefix(SEPOLIA_FACTORY)), "must warn against copying Sepolia Factory");
    }

    function test_rehearsalScriptStillBlocksBroadcast() public view {
        string memory raw = vm.readFile("script/RehearseMainnetLoreHandoff.s.sol");
        assertTrue(_contains(raw, "ScriptBroadcast"), "rehearsal must check broadcast context");
        assertTrue(_contains(raw, "fork-only rehearsal"), "rehearsal must revert on --broadcast");
        assertFalse(_contains(raw, "MAINNET_DEPLOY_UNBLOCKED"), "rehearsal must not be unlockable");
    }

    function test_deployScriptsDoNotCallTransferOwnership() public view {
        string memory factory = vm.readFile("script/DeployMainnetFactory.s.sol");
        string memory create = vm.readFile("script/CreateMainnetLoreChamber.s.sol");
        string memory guard = vm.readFile("script/MainnetDeployGuard.sol");
        assertFalse(_contains(factory, "transferOwnership("), "DeployMainnetFactory must not call transferOwnership");
        assertFalse(_contains(create, "transferOwnership("), "CreateMainnetLoreChamber must not call transferOwnership");
        assertTrue(_contains(guard, "MAINNET_DEPLOY_UNBLOCKED"), "broadcast gate missing");
        assertTrue(_contains(create, "refuseSepoliaFactory"), "create must refuse Sepolia Factory");
    }

    function test_printScriptRefusesBroadcastFlag() public view {
        string memory raw = vm.readFile("script/print-mainnet-factory-deploy.sh");
        assertTrue(_contains(raw, "never broadcasts"), "print script must refuse --broadcast");
        assertTrue(_contains(raw, "#208"), "print script must cite the blocker");
    }

    function test_createParamsMatchChamberScriptMainnet() public pure {
        assertEq(MainnetLoreHandoff.LORE, 0x7756D245527F5f8925A537be509BF54feb2FdC99);
        assertEq(MainnetLoreHandoff.MEMBERSHIP_NFT, 0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15);
        assertEq(MainnetLoreHandoff.TEAM_SAFE, 0x5d45A213B2B6259F0b3c116a8907B56AB5E22095);
        assertEq(MainnetLoreHandoff.SEATS, 5);
        assertEq(MainnetLoreHandoff.NAME, "Chamber LORE");
        assertEq(MainnetLoreHandoff.SYMBOL, "cLORE");
        assertEq(MainnetDeployGuard.SEPOLIA_FACTORY, SEPOLIA_FACTORY);
    }

    function test_deployFactoryLinkedLeavesChamberUnset() public {
        MainnetLoreHandoff.Deployment memory d = MainnetLoreHandoff.deployFactoryLinked(MainnetLoreHandoff.TEAM_SAFE);
        assertTrue(address(d.factory) != address(0));
        assertTrue(d.chamberImplementation != address(0));
        assertTrue(d.boardLib != address(0));
        assertTrue(d.walletLib != address(0));
        assertEq(d.chamber, address(0), "CREATE chamber cannot be pre-committed");
        assertEq(d.factory.owner(), MainnetLoreHandoff.TEAM_SAFE);
        assertEq(d.factory.implementation(), d.chamberImplementation);
    }

    function test_refuseSepoliaFactory() public {
        vm.expectRevert(bytes("refusing Sepolia Factory on chain id 1"));
        MainnetDeployGuard.refuseSepoliaFactory(SEPOLIA_FACTORY);
    }

    /// @dev Last field of the last line whose first field equals `label` exactly.
    function _labeledValue(string memory raw, string memory label) internal pure returns (string memory) {
        bytes memory h = bytes(raw);
        bytes memory needle = bytes(label);
        string memory found;
        uint256 start;
        for (uint256 i; i <= h.length; ++i) {
            if (i < h.length && h[i] != "\n") continue;
            string memory line = _trim(_slice(h, start, i < h.length ? i : h.length));
            start = i + 1;
            bytes memory t = bytes(line);
            if (t.length <= needle.length) continue;
            bool matchPrefix = true;
            for (uint256 j; j < needle.length; ++j) {
                if (t[j] != needle[j]) {
                    matchPrefix = false;
                    break;
                }
            }
            if (!matchPrefix) continue;
            // Next char must be whitespace so "Factory constructor" does not match "Factory".
            if (t[needle.length] != " " && t[needle.length] != "\t") continue;
            found = _lastField(line);
        }
        if (bytes(found).length == 0) revert("label line not found");
        return found;
    }

    function _lastField(string memory line) internal pure returns (string memory) {
        bytes memory b = bytes(line);
        uint256 end = b.length;
        while (end > 0 && (b[end - 1] == " " || b[end - 1] == "\t")) --end;
        uint256 start = end;
        while (start > 0 && b[start - 1] != " " && b[start - 1] != "\t") --start;
        return _slice(b, start, end);
    }

    function _slice(bytes memory h, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; ++i) {
            out[i - start] = h[i];
        }
        return string(out);
    }

    function _trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 i;
        uint256 j = b.length;
        while (i < j && (b[i] == " " || b[i] == "\t")) ++i;
        while (j > i && (b[j - 1] == " " || b[j - 1] == "\t" || b[j - 1] == "\r")) --j;
        return _slice(b, i, j);
    }

    function _hexNoPrefix(address account) internal pure returns (string memory) {
        bytes16 hexits = "0123456789abcdef";
        bytes20 data = bytes20(account);
        bytes memory out = new bytes(40);
        for (uint256 i; i < 20; ++i) {
            out[2 * i] = hexits[uint8(data[i] >> 4)];
            out[2 * i + 1] = hexits[uint8(data[i] & 0x0f)];
        }
        return string(out);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; i++) {
            bool ok = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _containsInsensitive(string memory haystack, string memory needle) internal pure returns (bool) {
        return _contains(_lower(haystack), _lower(needle));
    }

    function _lower(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        for (uint256 i; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 65 && c <= 90) b[i] = bytes1(c + 32);
        }
        return string(b);
    }
}
