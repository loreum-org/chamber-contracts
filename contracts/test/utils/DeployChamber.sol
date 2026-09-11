// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Chamber} from "src/Chamber.sol";
import {Factory} from "src/Factory.sol";
import {
    TransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

library DeployChamber {
    function deploy(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol,
        address admin
    ) internal returns (Chamber) {
        // Deploy implementation
        Chamber implementation = new Chamber();

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(admin),
            abi.encodeWithSelector(Chamber.initialize.selector, erc20Token, erc721Token, seats, name, symbol)
        );

        return Chamber(payable(address(proxy)));
    }

    /// @notice Product create path (PMN-M03 A): Factory deploys the proxy and transfers ProxyAdmin.
    function deployViaFactory(
        address erc20Token,
        address erc721Token,
        uint256 seats,
        string memory name,
        string memory symbol,
        address admin
    ) internal returns (Chamber) {
        Chamber implementation = new Chamber();
        Factory factory = new Factory(address(implementation), admin);
        return Chamber(factory.createChamber(erc20Token, erc721Token, seats, name, symbol));
    }
}
