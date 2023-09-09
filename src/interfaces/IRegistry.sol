// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRegistry {

    struct ChamberData {
        address chamber;
        address memberToken;
        address govToken;
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
     * @param  _memberToken The Membership (NFT) token
     * @param  _govToken    The Governance (ERC20) token 

     */ 
    function create(address _memberToken, address _govToken) external returns (address);
}