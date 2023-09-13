// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { ProxyChamber } from "./ProxyChamber.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Registry is IRegistry, Ownable {

    /// @notice totalChamber The tsotal number of Chambers
    uint256 public totalChambers;

    /// @notice chambers The Deployed Chambers
    /// @dev serial index -> ChamberData Struct
    mapping(uint256 => ChamberData) public chambers;

    /// @notice chamerVersion is the latest version of the Chamber contract
    address public chamberVersion;

    /// @notice contructor receives the base Chamber implementation address
    constructor(address _chamberVersion) Ownable() {
        chamberVersion = _chamberVersion;
    }

    /// @inheritdoc IRegistry
    function setChamberVersion(address _chamberVersion) external onlyOwner {
        chamberVersion = _chamberVersion;
    }

    /// @inheritdoc IRegistry
    function getChambers(uint8 limit, uint8 skip) external view returns (ChamberData[] memory) {
        ChamberData[] memory _chambers = new ChamberData[](limit);
        for (uint8 i = 0; i < limit; i++) {
            _chambers[i] = chambers[i + skip];
        }
        return _chambers;
    }

    /// @inheritdoc IRegistry
    function deploy(address _memberToken, address _govToken) external returns (address) {
        
        bytes memory data = abi.encodeWithSelector(IChamber.initialize.selector, _memberToken, _govToken);
        ProxyChamber proxyChamber = new ProxyChamber(chamberVersion, data, msg.sender);

        ChamberData memory chamberData = ChamberData({
            chamber: address(proxyChamber),
            memberToken: _memberToken,
            govToken: _govToken
        });
        
        chambers[totalChambers] = chamberData;
        totalChambers++;

        emit ChamberDeployed(address(proxyChamber), totalChambers, msg.sender, _memberToken, _govToken);
        return address(proxyChamber);
    }
}

