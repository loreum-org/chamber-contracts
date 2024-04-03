// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC721, IERC20 } from "src/Common.sol";
import { MultiProxy } from "src/proxy/MultiProxy.sol";
import { IChamber } from "src/interfaces/IChamber.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { Initializable } from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract Registry is IRegistry, Initializable, Ownable {

    /// @notice totalChamber The total number of Chambers
    uint256 public totalChambers;

    /// @notice chambers The Deployed Chambers
    /// @dev serial index -> ChamberData Struct
    mapping(uint256 => ChamberData) public chambers;

    /// @notice chamberBeacon is the beacon address for the Chamber contract
    address public chamberBeacon;

    /// @notice contructor disables initializers
    constructor() { _disableInitializers(); }

    /// @inheritdoc IRegistry
    function initialize(address _chamberBeacon, address _owner) external initializer {
        require(_owner != address(0),"The address is zero");
        require(_chamberBeacon != address(0),"The address is zero");
        super._transferOwnership(_owner);
        chamberBeacon = _chamberBeacon;
    }

    /// @inheritdoc IRegistry
    function setChamberBeacon(address _chamberBeacon) external onlyOwner {
        require(_chamberBeacon != address(0), "The address is zero");
        chamberBeacon = _chamberBeacon;
    }

    /// @inheritdoc IRegistry
    function getChambers(uint256 limit, uint256 skip) external view returns (ChamberData[] memory) {
        if (limit > totalChambers && totalChambers <= 255) limit = uint256(totalChambers);
        ChamberData[] memory _chambers = new ChamberData[](limit);
        for (uint256 i = 0; i < limit; i++) {
            _chambers[i] = chambers[i + skip];
        }
        return _chambers;
    }

    /// @inheritdoc IRegistry
    function deploy(address erc721, address erc20) external returns (address) {

        if(IERC20(erc20).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        if(IERC721(erc721).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        
        bytes memory data = abi.encodeWithSelector(IChamber.initialize.selector, erc721, erc20);
        MultiProxy chamber = new MultiProxy(chamberBeacon, data, msg.sender);

        ChamberData memory chamberData = ChamberData({
            chamber: address(chamber),
            memberToken: erc721,
            govToken: erc20
        });
        
        chambers[totalChambers] = chamberData;
        totalChambers++;

        emit ChamberDeployed(address(chamber), totalChambers, msg.sender, erc721, erc20);
        return address(chamber);
    }
}

