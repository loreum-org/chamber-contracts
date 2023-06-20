// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LinkedList {

    // State variables.

    uint internal constant _NULL = 0;
    bool internal constant _PREV = false;
    bool internal constant _NEXT = true;

    uint public head;
    uint public size;

    // list[tokenId][direction] = tokenId
    mapping(uint => mapping(bool => uint)) public list;

    struct Data {
        uint stake;
    }

    mapping(uint => Data) public tokenIdData;

    // Constructor.

    constructor() { }
    

    // Checkers.

    function isInitialized() public view returns (bool initialized) {
        return list[head][_PREV] != _NULL || list[head][_NEXT] != _NULL;
    }

    function inList(uint tokenId) public view returns (bool exists) {
        if (list[tokenId][_PREV] == _NULL && list[tokenId][_NEXT] == _NULL) {
            return head == tokenId;
            // return list[head][_NEXT] == tokenId;
        }
        else { return true; }
    }

    // Getters.

    function getData(uint tokenId) public view returns (bool exists, uint prev, uint next) {
        return (inList(tokenId), list[tokenId][_PREV], list[tokenId][_PREV]);
    }

    function getPrev(uint tokenId) public view returns (bool exists, uint prev) {
        return (inList(tokenId), list[tokenId][_PREV]);
    }

    function getNext(uint tokenId) public view returns (bool exists, uint next) {
        return (inList(tokenId), list[tokenId][_NEXT]);
    }

    function getAdjacent(uint tokenId, bool direction) public view returns (bool, uint) {
        return inList(tokenId) ? (false, 0) : (true, list[tokenId][direction]);
    }

    function getNextNode(uint tokenId) public view returns (bool, uint) {
        return getAdjacent(tokenId, _NEXT);
    }

    function getPreviousNode(uint tokenId) public view returns (bool, uint) {
        return getAdjacent(tokenId, _PREV);
    }

    // Insert.

    function insertAfter(uint byTokenId, uint newTokenId) internal {
        _insert(byTokenId, newTokenId, _NEXT);
    }

    function insertBefore(uint byTokenId, uint newTokenId) internal {
        _insert(byTokenId, newTokenId, _PREV);
    }

    function _insert(uint byTokenId, uint newTokenId, bool direction) private {
        if (!inList(newTokenId) && inList(byTokenId)) {
            uint id = list[byTokenId][direction];
            _createLink(byTokenId, newTokenId, direction);
            _createLink(newTokenId, id, direction);
            size += 1;
            return;
        }
        revert();
    }

    function _createLink(uint tokenId, uint link, bool direction) private {
        list[link][!direction] = tokenId;
        list[tokenId][direction] = link;
    }

    // Remove.

    function remove(uint tokenId) internal {
        if ((tokenId == _NULL) || (!inList(tokenId)) && size != 1) {
            revert();
        }
        _createLink(list[tokenId][_PREV], list[tokenId][_NEXT], _NEXT);
        delete list[tokenId][_PREV];
        delete list[tokenId][_NEXT];

        size -= 1;
    }

    // Push and pop.

    function pushFront(uint tokenId) internal {
        _push(tokenId, _NEXT);
    }

    function pushBack(uint tokenId) internal {
        _push(tokenId, _PREV);
    }

    function popFront() internal {
        _pop(_NEXT);
    }

    function popBack() internal {
        _pop(_PREV);
    }

    function _push(uint tokenId, bool direction) private {
        _insert(head, tokenId, direction);
    }

    function _pop(bool direction) private {
        (, uint adj) = getAdjacent(head, direction);
        remove(adj);
    }

}
