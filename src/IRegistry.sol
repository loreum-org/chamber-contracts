// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRegistry {

    struct ChamberData {
        address chamber;
        address govToken;
        address memberToken;
        uint8 version;
    }

    /**************************************************
        Errors
     **************************************************/

    error createFailed();

    /**************************************************
        Functions
     **************************************************/

    /** 
     * @notice create Creates a new Chamber
     * @param  _govToken    The Governance (ERC20) token
     * @param  _memberToken The Membership (NFT) token
     * @param  _leaders     The number of leaders for the chamber
     * @param  _quorum      The number of approvals required to execute a transaction
     */ 
    function create(address _govToken, address _memberToken, uint8 _leaders, uint8 _quorum) external returns (address);
}