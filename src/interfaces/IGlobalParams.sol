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
    function checkIfPlatformIsListed(bytes32 _platformHash) external view returns (bool);

    /**
     * @notice Retrieves the admin address of a platform.
     * @param _platformHash The unique identifier of the platform.
     * @return The admin address of the platform.
     */
    function getPlatformAdminAddress(bytes32 _platformHash) external view returns (address);

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
    function getPlatformDataOwner(bytes32 platformDataKey) external view returns (bytes32 platformHash);

    /**
     * @notice Retrieves the platform fee percentage for a specific platform.
     * @param platformHash The unique identifier of the platform.
     * @return The platform fee percentage as a uint256 value.
     */
    function getPlatformFeePercent(bytes32 platformHash) external view returns (uint256);

    /**
     * @notice Retrieves the claim delay (in seconds) for a specific platform.
     * @param platformHash The unique identifier of the platform.
     * @return The claim delay in seconds.
     */
    function getPlatformClaimDelay(bytes32 platformHash) external view returns (uint256);

    /**
     * @notice Checks if a platform-specific data key is valid.
     * @param platformDataKey The key of the platform-specific data.
     * @return isValid True if the data key is valid; otherwise, false.
     */
    function checkIfPlatformDataKeyValid(bytes32 platformDataKey) external view returns (bool isValid);

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
    function updatePlatformAdminAddress(bytes32 _platformHash, address _platformAdminAddress) external;

    /**
     * @notice Updates the claim delay for a specific platform.
     * @param platformHash The unique identifier of the platform.
     * @param claimDelay The claim delay in seconds.
     */
    function updatePlatformClaimDelay(bytes32 platformHash, uint256 claimDelay) external;

    /**
     * @notice Retrieves the adapter (trusted forwarder) address for a platform.
     * @param platformHash The unique identifier of the platform.
     * @return The adapter address for ERC-2771 meta-transactions.
     */
    function getPlatformAdapter(bytes32 platformHash) external view returns (address);

    /**
     * @notice Sets the adapter (trusted forwarder) address for a platform.
     * @dev Only callable by the protocol admin (owner).
     * @param platformHash The unique identifier of the platform.
     * @param adapter The address of the adapter contract.
     */
    function setPlatformAdapter(bytes32 platformHash, address adapter) external;

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
    function getTokensForCurrency(bytes32 currency) external view returns (address[] memory);

    /**
     * @notice Retrieves a value from the data registry.
     * @param key The registry key.
     * @return value The registry value.
     */
    function getFromRegistry(bytes32 key) external view returns (bytes32 value);

    /**
     * @notice Sets or updates a platform-specific line item type configuration.
     * @param platformHash The identifier of the platform.
     * @param typeId The identifier of the line item type.
     * @param label The label identifier for the line item type.
     * @param countsTowardGoal Whether this line item counts toward the campaign goal.
     * @param applyProtocolFee Whether this line item is included in protocol fee calculation.
     * @param canRefund Whether this line item can be refunded.
     * @param instantTransfer Whether this line item amount can be instantly transferred.
     */
    function setPlatformLineItemType(
        bytes32 platformHash,
        bytes32 typeId,
        string calldata label,
        bool countsTowardGoal,
        bool applyProtocolFee,
        bool canRefund,
        bool instantTransfer
    ) external;

    /**
     * @notice Removes a platform-specific line item type by setting its exists flag to false.
     * @param platformHash The identifier of the platform.
     * @param typeId The identifier of the line item type to remove.
     */
    function removePlatformLineItemType(bytes32 platformHash, bytes32 typeId) external;

    /**
     * @notice Retrieves a platform-specific line item type configuration.
     * @param platformHash The identifier of the platform.
     * @param typeId The identifier of the line item type.
     * @return exists Whether this line item type exists and is active.
     * @return label The label identifier for the line item type.
     * @return countsTowardGoal Whether this line item counts toward the campaign goal.
     * @return applyProtocolFee Whether this line item is included in protocol fee calculation.
     * @return canRefund Whether this line item can be refunded.
     * @return instantTransfer Whether this line item amount can be instantly transferred.
     */
    function getPlatformLineItemType(bytes32 platformHash, bytes32 typeId)
        external
        view
        returns (
            bool exists,
            string memory label,
            bool countsTowardGoal,
            bool applyProtocolFee,
            bool canRefund,
            bool instantTransfer
        );
}
