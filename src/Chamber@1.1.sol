// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract StakeLeadersBoard {
    // Define a Staker with an address, a token ID, and an amount
    struct Staker {
        address stakerAddress;
        uint256 tokenId;
        uint256 amount;
    }

    // Define the number of leaders
    uint256 public constant NumberOfLeaders = 3;

    // Mapping to keep track of each staker's details
    mapping(address => mapping(uint256 => Staker)) public stakerDetails;

    function getStakerAmount(address _stakerAddress, uint256 _tokenId) public view returns (uint256) {
        Staker memory s = stakerDetails[_stakerAddress][_tokenId];
        return s.amount;
    }

    // Array to keep track of the leaderboard
    Staker[NumberOfLeaders] leaderboard;
    // Array to keep track of the member which are not leaders
    Staker[] members;

    // Function to get leader at a specific index
    function leaderboardList(uint256 index) public view returns (Staker memory) {
        return leaderboard[index];
    }
    // Function to get member at a specific index
    function MemberList(uint256 index) public view returns (Staker memory) {
        return members[index];
    }

    // Function to stake tokens
    function stakeTokens(uint256 _tokenId, uint256 _amount) public {
        // Get the address of the staker
        address stakerAddress = msg.sender;

        // If the staker has already staked for this token ID, increase their amount
        // and update the leaderboard
        if (stakerDetails[stakerAddress][_tokenId].stakerAddress != address(0)) {
            stakerDetails[stakerAddress][_tokenId].amount += _amount;
            _updateLeaderboard(stakerDetails[stakerAddress][_tokenId]);
        } else {
            // If the staker has not staked for this token ID, create a new staker
            // and update the leaderboard
            Staker storage staker = stakerDetails[stakerAddress][_tokenId];
            staker.stakerAddress = stakerAddress;
            staker.tokenId = _tokenId;
            staker.amount = _amount;
            _updateLeaderboard(staker);
        }
    }

    // Function to update the leaderboard
    function _updateLeaderboard(Staker memory _newStaker) private {
        // Loop through the leaderboard
        for (uint256 i = 0; i < NumberOfLeaders; i++) {
            // If there is an empty spot on the leaderboard, add the new staker
            // and sort the leaderboard
            if (leaderboard[i].stakerAddress == address(0)) {
                leaderboard[i] = _newStaker;
                sortLeaderboard();
                return;
            } else if (
                // If the new staker is already on the leaderboard, update their details
                // and sort the leaderboard
                leaderboard[i].stakerAddress == _newStaker.stakerAddress && leaderboard[i].tokenId == _newStaker.tokenId
            ) {
                leaderboard[i] = _newStaker;
                sortLeaderboard();
                return;
            }
        }

        // Find the staker with the lowest amount on the leaderboard
        uint256 indexLowest = 0;
        for (uint256 i = 0; i < NumberOfLeaders; i++) {
            if (leaderboard[i].amount < leaderboard[indexLowest].amount) {
                indexLowest = i;
            }
        }

        // If the new staker has a higher amount than the staker with the lowest amount,
        // replace the staker with the lowest amount with the new staker
        if (_newStaker.amount > leaderboard[indexLowest].amount) {
            members.push(leaderboard[indexLowest]);
            leaderboard[indexLowest] = _newStaker;
        }

        // Sort the leaderboard
        sortLeaderboard();
    }

    // Function to sort the leaderboard
    function sortLeaderboard() private {
        // Bubble sort
        for (uint256 i = 0; i < NumberOfLeaders; i++) {
            for (uint256 j = 0; j < NumberOfLeaders - i - 1; j++) {
                // If the staker at position j has a lower amount than the staker at position j+1,
                // swap them
                if (leaderboard[j].amount < leaderboard[j + 1].amount) {
                    Staker memory temp = leaderboard[j];
                    leaderboard[j] = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                }
            }
        }
    }

    // Function to unstake tokens
    function unstakeTokens(uint256 _tokenId, uint256 _amount) public {
        // Get the address of the staker
        address stakerAddress = msg.sender;

        // Make sure the staker has enough tokens to unstake
        require(stakerDetails[stakerAddress][_tokenId].amount >= _amount, "Unstaking amount is more than staked amount");

        // Reduce the staker's amount
        stakerDetails[stakerAddress][_tokenId].amount -= _amount;

        // If the staker's amount is 0 after unstaking, remove them from the staker details
        // and the leaderboard
        if (stakerDetails[stakerAddress][_tokenId].amount == 0) {
            delete stakerDetails[stakerAddress][_tokenId];
            _removeFromLeaderboard(stakerAddress, _tokenId);
        } else {
            // If the staker's amount is not 0 after unstaking, update the leaderboard
            _updateLeaderboard(stakerDetails[stakerAddress][_tokenId]);
        }
    }

    // Function to remove a staker from the leaderboard
    function _removeFromLeaderboard(address _stakerAddress, uint256 _tokenId) private {
        // Loop through the leaderboard
        for (uint256 i = 0; i < NumberOfLeaders; i++) {
            // If the staker is on the leaderboard, remove them
            if (leaderboard[i].stakerAddress == _stakerAddress && leaderboard[i].tokenId == _tokenId) {
                delete leaderboard[i];
                _shiftLeaderboard(i);
                _addPotentialLeader();
                return;
            }
        }
    }
    function _addPotentialLeader() private{
        uint256 LastMemberIndex = members.length;
        uint256 LastLeaderIndex = leaderboard.length;

        if (LastMemberIndex!=0){
            leaderboard[LastLeaderIndex-1]=members[LastMemberIndex-1];
            members.pop();
        }
    }

    // Function to shift the leaderboard after a staker has been removed
    function _shiftLeaderboard(uint256 index) private {
        // Loop through the leaderboard from the index of the removed staker
        for (uint256 i = index; i < NumberOfLeaders - 1; i++) {
            // Move each staker one position up
            leaderboard[i] = leaderboard[i + 1];
        }
        // Remove the last staker
        delete leaderboard[NumberOfLeaders - 1];
    }
}
