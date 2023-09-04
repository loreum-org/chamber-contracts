// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Chamber } from "./Chamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

contract Registry is IRegistry {

    uint8 public version = 1;

    /// @notice Deployed Chambers
    mapping(address => ChamberData) public chambers;

    /// @notice Chamber deployer addresses
    mapping(address => ChamberData[]) public deployers;

    /**
     * @notice Emitted when a new Chamber is created
     * @param chamber       The address of the new Chamber.
     * @param govToken      Address of the ERC20 governance token.
     * @param memberToken   Address of the NFT membership token.
     * @param leaders       The number of leaders in the Chamber
     * @param quorum        The number of leaders required to approve a transaction
     */
    event ChamberCreated(
        address indexed chamber,
        address indexed deployer,
        address govToken,
        address memberToken,
        uint8 leaders,
        uint8 quorum,
        uint8 version
    );

    /// @inheritdoc IRegistry
    function create(
        address _govToken,
        address _memberToken,
        uint8 _leaders,
        uint8 _quorum
        ) external returns (address) {
            Chamber chamber;
            chamber = new Chamber(_govToken, _memberToken, _leaders, _quorum);
            ChamberData memory chamberData = ChamberData({ 
                chamber: address(chamber), 
                govToken: _govToken, 
                memberToken: _memberToken,
                version: version
        });
        
        chambers[address(chamber)] = chamberData;
        deployers[msg.sender].push(chamberData);
        
        emit ChamberCreated(address(chamber), msg.sender, _govToken, _memberToken, _leaders, _quorum, version);
        return address(chamber);
    }
}

