// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Board} from "src/Board.sol";
import {BoardTypes} from "src/types/BoardTypes.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

contract MockBoard is Board {
    function exposed_delegate(uint256 tokenId, uint256 amount) public nonReentrant {
        _delegate(tokenId, amount, IERC721(address(0)));
    }

    function exposed_undelegate(uint256 tokenId, uint256 amount) public nonReentrant {
        _undelegate(tokenId, amount, IERC721(address(0)));
    }

    function insert(uint256 tokenId, uint256 amount) public {
        _insert(tokenId, amount);
    }

    function remove(uint256 tokenId) public {
        _remove(tokenId);
    }

    function reposition(uint256 tokenId) public {
        _reposition(tokenId);
    }

    function getNode(uint256 tokenId) public view returns (Node memory) {
        return _getNode(tokenId);
    }

    function getSize() public view returns (uint256) {
        return _getBoardStorage().size;
    }

    function getHead() public view returns (uint256) {
        return _getBoardStorage().head;
    }

    function getTop(uint256 count) public view returns (uint256[] memory, uint256[] memory) {
        return _getTop(count);
    }

    function setSeats(uint256 tokenId, uint256 numOfSeats) public {
        _setSeats(tokenId, numOfSeats);
    }

    function executeSeatsUpdate(uint256 tokenId) public {
        _executeSeatsUpdate(tokenId, IERC721(address(0)));
    }

    function cancelSeatUpdate(uint256 tokenId) public {
        _cancelSeatUpdate(tokenId);
    }

    function getQuorum() public view returns (uint256) {
        return _getQuorum();
    }

    function getSeats() public view returns (uint256) {
        return _getSeats();
    }

    function getSeatUpdate() public view returns (uint256, uint256, uint256, uint256[] memory) {
        BoardTypes.SeatUpdate storage proposal = _getBoardStorage().seatUpdate;
        return (proposal.proposedSeats, proposal.timestamp, proposal.requiredQuorum, proposal.supporters);
    }

    function getSeatedAt(uint256 tokenId) public view returns (uint256) {
        return _getSeatedAt(tokenId);
    }

    function isSeatingMature(uint256 tokenId) public view returns (bool) {
        return _isSeatingMature(tokenId);
    }

    function topTokenIds() public view returns (uint256[] memory) {
        return _topTokenIds();
    }

    /**
     * @notice Holds the shared OZ lock and immediately calls `exposed_delegate`.
     *         Simulates reentrancy so the second `nonReentrant` entry reverts.
     */
    function lockAndDelegate(uint256 tokenId, uint256 amount) public nonReentrant {
        this.exposed_delegate(tokenId, amount);
    }

    /**
     * @notice Holds the shared OZ lock and immediately calls `exposed_undelegate`.
     *         Simulates reentrancy so the second `nonReentrant` entry reverts.
     */
    function lockAndUndelegate(uint256 tokenId, uint256 amount) public nonReentrant {
        this.exposed_undelegate(tokenId, amount);
    }
}
