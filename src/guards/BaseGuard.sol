// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGuard,IERC165 } from "../interfaces/IGuard.sol";

abstract contract BaseGuard is IGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool){
        return 
        interfaceId == type(IGuard).interfaceId || // 0x945b8148
        interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}