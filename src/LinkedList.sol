// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract LinkedList {

    /**************************************************
        LinkedList State Variables
    **************************************************/

    /// @notice Head is the first tokenId of the Leaderboard
    uint public head;
    
    /// @notice Size is the total number of tokenIds on the leaderboard
    uint public size;

    /** 
     * @notice The Leaderboard is a linked list of NFT tokenIds
     * @dev    1st element -> tokenId, 2nd element -> direction, 3rd element-> tokenId
     * @dev    direction: False -> previous, True -> next
     */
    mapping(uint => mapping(bool => uint)) public list;
    
    // LinkedList constants
    uint internal constant _NULL = 0;
    bool internal constant _PREV = false;
    bool internal constant _NEXT = true;

    /**************************************************
        Functions
    **************************************************/
    
    function isInitialized() public view returns (bool initialized) {
        return list[head][_PREV] != _NULL || list[head][_NEXT] != _NULL;
    }

    function inList(uint _tokenId) public view returns (bool exists) {
        if (list[_tokenId][_PREV] == _NULL && list[_tokenId][_NEXT] == _NULL) {
            return head == _tokenId;
        }
        else { return true; }
    }
    
    function getData(uint _tokenId) public view returns (bool exists, uint prev, uint next) {
        return (inList(_tokenId), list[_tokenId][_PREV], list[_tokenId][_PREV]);
    }

    function getPrev(uint _tokenId) public view returns (bool exists, uint prev) {
        return (inList(_tokenId), list[_tokenId][_PREV]);
    }
    
    function insertAfter(uint _byTokenId, uint _newTokenId) internal {
        _insert(_byTokenId, _newTokenId, _NEXT);
    }

    function _insert(uint _byTokenId, uint _newTokenId, bool _direction) private {
        if (!inList(_newTokenId) && inList(_byTokenId)) {
            uint id = list[_byTokenId][_direction];
            _createLink(_byTokenId, _newTokenId, _direction);
            _createLink(_newTokenId, id, _direction);
            size += 1;
            return;
        }
        revert();
    }

    function _createLink(uint _tokenId, uint _linkTokenId, bool _direction) private {
        list[_linkTokenId][!_direction] = _tokenId;
        list[_tokenId][_direction] = _linkTokenId;
    }
    
    function remove(uint _tokenId) internal {
        if ((_tokenId == _NULL) || (!inList(_tokenId)) && size != 1) {
            revert();
        }
        _createLink(list[_tokenId][_PREV], list[_tokenId][_NEXT], _NEXT);
        delete list[_tokenId][_PREV];
        delete list[_tokenId][_NEXT];

        size -= 1;
    }

    function pushFront(uint _tokenId) internal {
        _push(_tokenId, _NEXT);
    }

    function _push(uint _tokenId, bool _direction) private {
        _insert(head, _tokenId, _direction);
    }
}