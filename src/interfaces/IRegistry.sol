// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRegistry {

    struct ChamberData {
        address chamber;
        address memberToken;
        address govToken;
        string version;
    }

    /**
     * @notice Emitted when a new Chamber is deployed
     * @param chamber       The address of the new Chamber.
     * @param govToken      Address of the ERC20 governance token.
     * @param memberToken   Address of the NFT membership token.
     */
    event ChamberDeployed(
        address indexed chamber,
        address indexed deployer,
        address memberToken,
        address govToken,
        string version
    );

    /**************************************************
        Errors
     **************************************************/

    error deployFailed();

    /**************************************************
        Functions
     **************************************************/

    /// @notice Returns the Chamber implmentation address
    function chamberVersion() external returns (address);
    
    /**
     * @notice Sets the Chamber version
     * @param _chamberVersion The address of the Chamber version
     */
    function setChamberVersion(address _chamberVersion) external;

    /** 
     * @notice deploy Deploys a new Chamber
     * @param  _memberToken The Membership (NFT) token
     * @param  _govToken    The Governance (ERC20) token 

     */ 
    function deploy(address _memberToken, address _govToken) external returns (address);
}