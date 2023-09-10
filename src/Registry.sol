// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Chamber } from "./Chamber.sol";
import { IChamber } from "./interfaces/IChamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
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

    function setChamberVersion(address _chamberVersion) external onlyOwner {
        chamberVersion = _chamberVersion;
    }

    /// @inheritdoc IRegistry
    function deploy(address _memberToken, address _govToken) external returns (address) {
        
        address newChamber = Clones.clone(chamberVersion);
        IChamber(newChamber).initialize(_memberToken, _govToken);

        ChamberData memory chamberData = ChamberData({ 
            chamber: newChamber,
            memberToken: _memberToken,
            govToken: _govToken, 
            version: IChamber(newChamber).version()
        });
        
        chambers[newChamber] = chamberData;
        deployers[msg.sender].push(chamberData);
        totalChambers++;
        
        emit ChamberDeployed(newChamber, msg.sender, _memberToken, _govToken, IChamber(newChamber).version());
        return newChamber;
    }
}

