// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Chamber } from "./Chamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

contract Registry is IRegistry {

    uint8 public version = 1;

    /// @notice Total number of Chambers
    uint256 public totalChambers;

    /// @notice Deployed Chambers
    mapping(address => ChamberData) public chambers;

    /// @notice Chamber deployer addresses
    mapping(address => ChamberData[]) public deployers;

    /**
     * @notice Emitted when a new Chamber is created
     * @param chamber       The address of the new Chamber.
     * @param govToken      Address of the ERC20 governance token.
     * @param memberToken   Address of the NFT membership token.
     */
    event ChamberCreated(
        address indexed chamber,
        address indexed deployer,
        address memberToken,
        address govToken,
        uint8 version
    );

    /// @inheritdoc IRegistry
    function create(
        address _memberToken,
        address _govToken
        ) external returns (address) {
            Chamber chamber;
            chamber = new Chamber(_memberToken, _govToken);
            ChamberData memory chamberData = ChamberData({ 
                chamber: address(chamber), 
                memberToken: _memberToken,
                govToken: _govToken, 
                version: version
        });
        
        chambers[address(chamber)] = chamberData;
        deployers[msg.sender].push(chamberData);
        totalChambers++;
        
        emit ChamberCreated(address(chamber), msg.sender, _memberToken, _govToken, version);
        return address(chamber);
    }
}

