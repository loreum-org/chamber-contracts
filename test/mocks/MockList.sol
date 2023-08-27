// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { LinkedList } from "../../src/LinkedList.sol";

contract MockList is LinkedList {

    function insertTest(uint _tokenid, uint _newTokenId) public {
        insertAfter(_tokenid, _newTokenId);
    }

    function removeTest(uint _tokenId) public {
        remove(_tokenId);
    }
}