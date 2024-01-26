// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import "./interfaces/IERC165.sol";

interface Guard is IERC165{
    function checkTransaction(
        address[] memory to,
        uint256[] memory value,
        bytes[] memory data,
        uint8[5] memory voters,
        IChamber.State state,
        bytes memory signature,
        address msgSender,
        uint8 proposalId,
        uint8 tokenId
    )external;
    
    function checkAfterExecution(bytes32 txHash, bool success) external;
}

contract SelfAuthorized {
    function requireSelfCall() private view{
        require (msg.sender == address(this), "Method can only be called form this contract");
    }
    modifier authorized {
        requireSelfCall();
        _;
    }
}

abstract contract BaseGuard is Guard {
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool){
        return 
        interfaceId == type(Guard).interfaceId || 
        interfaceId == type(IERC165).interfaceId;
    }
}

contract GuardManager is SelfAuthorized{
    event ChangedGuard(address indexed guard);
    // keccak256("guard_manager.guard.address")
    bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    
    function setGuard(address guard) external authorized{
        bytes32 slot = GUARD_STORAGE_SLOT;
        assembly {
            sstore(slot, guard)
        }
        emit ChangedGuard(guard);
    }

    function getGuard() internal view returns (address guard){
        bytes32 slot = GUARD_STORAGE_SLOT;
        assembly {
            guard := sload(slot)
        }
    }
}