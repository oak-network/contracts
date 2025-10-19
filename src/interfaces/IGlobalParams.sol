// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IGlobalParams
 * @notice An interface for accessing and managing global parameters of the protocol.
 */
interface IGlobalParams {
    /**
     * @notice Checks if a platform is listed in the protocol.
     * @param _platformHash The unique identifier of the platform.
     * @return True if the platform is listed; otherwise, false.
     */
    function checkIfPlatformIsListed(
        bytes32 _platformHash
    ) external view returns (bool);

    /**
     * @notice Retrieves the admin address of a platform.
     * @param _platformHash The unique identifier of the platform.
     * @return The admin address of the platform.
     */
    function getPlatformAdminAddress(
        bytes32 _platformHash
    ) external view returns (address);

    /**
     * @notice Retrieves the number of listed platforms in the protocol.
     * @return The number of listed platforms.
     */
    function getNumberOfListedPlatforms() external view returns (uint256);

    /**
     * @notice Retrieves the admin address of the protocol.
     * @return The admin address of the protocol.
     */
    function getProtocolAdminAddress() external view returns (address);

    /**
     * @notice Retrieves the protocol fee percentage.
     * @return The protocol fee percentage as a uint256 value.
     */
    function getProtocolFeePercent() external view returns (uint256);

    /**
     * @notice Retrieves the owner of platform-specific data.
     * @param platformDataKey The key of the platform-specific data.
     * @return platformHash The platform identifier associated with the data.
     */
    function getPlatformDataOwner(
        bytes32 platformDataKey
    ) external view returns (bytes32 platformHash);

    /**
     * @notice Retrieves the platform fee percentage for a specific platform.
     * @param platformHash The unique identifier of the platform.
     * @return The platform fee percentage as a uint256 value.
     */
    function getPlatformFeePercent(
        bytes32 platformHash
    ) external view returns (uint256);

    /**
     * @notice Checks if a platform-specific data key is valid.
     * @param platformDataKey The key of the platform-specific data.
     * @return isValid True if the data key is valid; otherwise, false.
     */
    function checkIfPlatformDataKeyValid(
        bytes32 platformDataKey
    ) external view returns (bool isValid);

    /**
     * @notice Updates the admin address of the protocol.
     * @param _protocolAdminAddress The new admin address of the protocol.
     */
    function updateProtocolAdminAddress(address _protocolAdminAddress) external;

    /**
     * @notice Updates the protocol fee percentage.
     * @param _protocolFeePercent The new protocol fee percentage as a uint256 value.
     */
    function updateProtocolFeePercent(uint256 _protocolFeePercent) external;

    /**
     * @notice Updates the admin address of a platform.
     * @param _platformHash The unique identifier of the platform.
     * @param _platformAdminAddress The new admin address of the platform.
     */
    function updatePlatformAdminAddress(
        bytes32 _platformHash,
        address _platformAdminAddress
    ) external;

    /**
     * @notice Adds a token to a currency.
     * @param currency The currency identifier.
     * @param token The token address to add.
     */
    function addTokenToCurrency(bytes32 currency, address token) external;

    /**
     * @notice Removes a token from a currency.
     * @param currency The currency identifier.
     * @param token The token address to remove.
     */
    function removeTokenFromCurrency(bytes32 currency, address token) external;

    /**
     * @notice Retrieves all tokens accepted for a specific currency.
     * @param currency The currency identifier.
     * @return An array of token addresses accepted for the currency.
     */
    function getTokensForCurrency(
        bytes32 currency
    ) external view returns (address[] memory);
}
