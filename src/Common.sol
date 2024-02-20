// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC1155Holder } from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

abstract contract Common is Initializable, ReentrancyGuard, Context, ERC721Holder, ERC1155Holder {

      // Importing ECDSA library for bytes32 type
    using ECDSA for bytes32;
    
    /// @notice Flag to indicate contract locking status
    bool public locked;

    /// @notice Modifier to prevent reentrancy attacks
    modifier noReentrancy() {
        require(!locked, "No reentrancy");

        locked = true;
        _;
        locked = false;
    }

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH= 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // Function signature for the cancelProposal function.
    bytes4 internal constant CANCEL_PROPOSAL_SELECTOR = bytes4(abi.encodeWithSignature("cancelProposal(uint256)"));
}