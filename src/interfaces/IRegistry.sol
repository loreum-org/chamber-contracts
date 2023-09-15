// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRegistry {

    struct ChamberData {
        address chamber;
        address memberToken;
        address govToken;
    }

    /// @notice Emitted when a new Chamber is deployed
    /// @param chamber       The address of the new Chamber.
    /// @param govToken      Address of the ERC20 governance token.
    /// @param memberToken   Address of the NFT membership token.
    event ChamberDeployed(
        address indexed chamber,
        uint256 indexed serial,
        address indexed deployer,
        address memberToken,
        address govToken
    );

    /**************************************************
        Errors
     **************************************************/

    error deployFailed();

    /**************************************************
        Functions
     **************************************************/

    function initialize(address _chamberVersion, address _owner) external;

    function totalChambers() external returns (uint256);

    function chambers(uint256 _index) external returns (address chamber, address memberToken, address govToken);

    /// @notice Returns the Chamber implmentation address
    function chamberVersion() external returns (address);
    
    /// @notice Sets the Chamber version
    /// @param _chamberVersion The address of the Chamber version
    function setChamberVersion(address _chamberVersion) external;

    /// @notice getChambers Returns an array of ChamberData structs
    /// @param  limit The maximum number of Chambers to return
    /// @param  skip  The number of Chambers to skip
    /// @return       ChamberData[] An array of ChamberData structs
    function getChambers(uint8 limit, uint8 skip) external view returns (ChamberData[] memory);

    /// @notice deploy Deploys a new Chamber
    /// @param  _memberToken The Membership (NFT) token
    /// @param  _govToken    The Governance (ERC20) token
    /// @return address      The address of the new Chamber
    function deploy(address _memberToken, address _govToken) external returns (address);
}