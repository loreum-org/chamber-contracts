// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import { Chamber } from "../src/Chamber.sol";
import "forge-std/console2.sol";

contract DeployChamber is Script {

    function run() external {
        vm.startBroadcast();
        Chamber chamberImpl = new Chamber();
        vm.stopBroadcast();
        console2.log("Chamber Implementation: ", address(chamberImpl));
    }
}
