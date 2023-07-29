//One array with bubble sort

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC721_Chamber {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC20_Chamber {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Chamber {
    struct Staker {
        address stakerAddress;
        uint256 tokenId;
        uint256 amount;
    }

    uint256 public leaders;

    mapping(uint256 => uint256) public totalStake;

    mapping(address => mapping(uint256 => Staker)) memberNftStake;

    Staker[] public leaderboard;

    constructor(uint16 _leaders) {
        leaders = _leaders;
    }

    function getUserStakeIndividualNFT(address _member, uint256 _tokenId) public view returns (uint256) {
        Staker memory s = memberNftStake[_member][_tokenId];
        return s.amount;
    }

    function LeaderboardList(uint256 index) public view returns (Staker memory) {
        return leaderboard[index];
    }

    function leaderboardLength() public view returns (uint256) {
        return leaderboard.length;
    }

    function stakeTokens(uint256 _tokenId, uint256 _amount) public {
        address stakerAddress = msg.sender;

        totalStake[_tokenId] += _amount;

        if (memberNftStake[stakerAddress][_tokenId].stakerAddress != address(0)) {
            memberNftStake[stakerAddress][_tokenId].amount += _amount;
            _updateLeaderboard(memberNftStake[stakerAddress][_tokenId]);
        } else {
            Staker storage staker = memberNftStake[stakerAddress][_tokenId];
            staker.stakerAddress = stakerAddress;
            staker.tokenId = _tokenId;
            staker.amount = _amount;
            _updateLeaderboard(staker);
        }
    }

    function _updateLeaderboard(Staker memory _newStaker) private {
        bool found = false;
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (
                leaderboard[i].stakerAddress == _newStaker.stakerAddress && leaderboard[i].tokenId == _newStaker.tokenId
            ) {
                leaderboard[i] = _newStaker;
                found = true;
                break;
            }
        }
        if (!found) {
            leaderboard.push(_newStaker);
        }
        sortLeaderboard();
    }

    function sortLeaderboard() private {
        for (uint256 i = 0; i < leaderboard.length - 1; i++) {
            for (uint256 j = 0; j < (leaderboard.length - 1) - i; j++) {
                if (leaderboard[j].amount > leaderboard[j + 1].amount) {
                    Staker memory temp = leaderboard[j];
                    leaderboard[j] = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                }
            }
        }
    }

    function unstakeTokens(uint256 _tokenId, uint256 _amount) public {
        address stakerAddress = msg.sender;
        require(
            memberNftStake[stakerAddress][_tokenId].amount >= _amount, "Unstaking amount is more than staked amount"
        );
        memberNftStake[stakerAddress][_tokenId].amount -= _amount;

        if (memberNftStake[stakerAddress][_tokenId].amount == 0) {
            delete memberNftStake[stakerAddress][_tokenId];
            _removeFromLeaderboard(stakerAddress, _tokenId);
        } else {
            _updateLeaderboard(memberNftStake[stakerAddress][_tokenId]);
        }
    }

    function _removeFromLeaderboard(address _stakerAddress, uint256 _tokenId) private {
        for (uint256 i = 0; i < leaders; i++) {
            if (leaderboard[i].stakerAddress == _stakerAddress && leaderboard[i].tokenId == _tokenId) {
                delete leaderboard[i];
                _shiftLeaderboard(i);
                return;
            }
        }
    }

    function _shiftLeaderboard(uint256 index) private {
        for (uint256 i = index; i < leaders - 1; i++) {
            leaderboard[i] = leaderboard[i + 1];
        }
        delete leaderboard[leaders - 1];
    }

    function _msgSender() private view returns (address) {
        return msg.sender;
    }
}
