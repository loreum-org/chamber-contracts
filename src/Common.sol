// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.24;

import { Context } from "lib/openzeppelin-contracts/contracts/utils/Context.sol";
import { ECDSA } from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { ERC1155Holder } from "lib/openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC721Holder } from "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import { GuardManager } from "src/guards/GuardManager.sol";
import { IERC165 } from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC721 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { Initializable } from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { TransparentUpgradeableProxy } from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract Common is Initializable, ReentrancyGuard, Context, ERC721Holder, ERC1155Holder, GuardManager {
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
    bytes4 internal constant CANCEL_PROPOSAL_SELECTOR = bytes4(abi.encodeWithSignature("cancel(uint256)"));

    // Function to get the signature of a message hash. (EIP-191)
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }
}