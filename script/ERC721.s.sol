// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "lib/forge-std/src/Script.sol";
import { LoreumNFT } from "lib/loreum-nft/src/LoreumNFT.sol";

contract DeployERC721 is Script {

    function run() external {

        vm.startBroadcast();
        new LoreumNFT(
            "Black Holes",
            "BLKH",
            "ipfs://QmdmSzXAHnQW2ufFp9eApwb1HQQkrZAAnZqtzfb9bbXVqn/",
            0.05 ether,
            500,
            10000,
            100,
            0x345F273fAE2CeC49e944BFBEf4899fA1625803C5
        );
        vm.stopBroadcast();
    }
}