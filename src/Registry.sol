// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Proxy } from "./Proxy.sol";
import { IChamber } from "./interfaces/IChamber.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract Registry is IRegistry, Initializable, Ownable {

    /// @notice totalChamber The total number of Chambers
    uint256 public totalChambers;

    /// @notice chambers The Deployed Chambers
    /// @dev serial index -> ChamberData Struct
    mapping(uint256 => ChamberData) public chambers;

    /// @notice chamerVersion is the latest version of the Chamber contract
    address public chamberVersion;

    /// @notice contructor disables initializers
    constructor() { _disableInitializers(); }

    /// @inheritdoc IRegistry
    function initialize(address _chamberVersion, address _owner) external initializer {
        super._transferOwnership(_owner);
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
        Proxy chamber = new Proxy(chamberVersion, data, msg.sender);

        ChamberData memory chamberData = ChamberData({
            chamber: address(chamber),
            memberToken: _memberToken,
            govToken: _govToken
        });
        
        chambers[totalChambers] = chamberData;
        totalChambers++;

        emit ChamberDeployed(address(chamber), totalChambers, msg.sender, _memberToken, _govToken);
        return address(chamber);
    }
}

