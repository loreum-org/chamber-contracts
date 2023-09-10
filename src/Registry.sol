// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Chamber } from "./Chamber.sol";
import { IChamber } from "./interfaces/IChamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Registry is IRegistry, Ownable {

    /// @notice Total number of Chambers
    uint256 public totalChambers;

    /// @notice Deployed Chambers
    mapping(address => ChamberData) public chambers;

    /// @notice Chamber deployer addresses
    mapping(address => ChamberData[]) public deployers;

    address public chamberVersion;

    constructor(address _chamberVersion) Ownable() {
        chamberVersion = _chamberVersion;
    }

    /// @inheritdoc IRegistry
    function setChamberVersion(address _chamberVersion) external onlyOwner {
        chamberVersion = _chamberVersion;
    }

    /// @inheritdoc IRegistry
    function deploy(address _memberToken, address _govToken) external returns (address) {
        
        bytes memory data = abi.encodeWithSelector(Chamber.initialize.selector, _memberToken, _govToken);
        ERC1967Proxy chamberProxy = new ERC1967Proxy(chamberVersion, data);

        IChamber chamber = IChamber(address(chamberProxy));

        ChamberData memory chamberData = ChamberData({ 
            chamber: address(chamberProxy),
            memberToken: _memberToken,
            govToken: _govToken, 
            version: chamber.version()
        });
        
        chambers[address(chamberProxy)] = chamberData;
        deployers[msg.sender].push(chamberData);
        totalChambers++;
        
        emit ChamberDeployed(address(chamberProxy), msg.sender, _memberToken, _govToken, chamber.version());
        return address(chamberProxy);
    }
}

