// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ICampaignInfo
 * @notice An interface for managing campaign information in a crowdfunding system.
 */
interface ICampaignInfo {
    /**
     * @notice Returns the owner of the contract.
     * @return The address of the contract owner.
     */
    function owner() external view returns (address);

    /**
     * @notice Checks if a platform has been selected for the campaign.
     * @param platformHash The bytes32 identifier of the platform to check.
     * @return True if the platform is selected, false otherwise.
     */
    function checkIfPlatformSelected(
        bytes32 platformHash
    ) external view returns (bool);

    /**
     * @notice Retrieves the total amount raised in the campaign.
     * @return The total amount raised in the campaign.
     */
    function getTotalRaisedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the address of the protocol administrator.
     * @return The address of the protocol administrator.
     */
    function getProtocolAdminAddress() external view returns (address);

    /**
     * @notice Retrieves the address of the platform administrator for a specific platform.
     * @param platformHash The bytes32 identifier of the platform.
     * @return The address of the platform administrator.
     */
    function getPlatformAdminAddress(
        bytes32 platformHash
    ) external view returns (address);

    /**
     * @notice Retrieves the campaign's launch time.
     * @return The timestamp when the campaign was launched.
     */
    function getLaunchTime() external view returns (uint256);

    /**
     * @notice Retrieves the campaign's deadline.
     * @return The timestamp when the campaign ends.
     */
    function getDeadline() external view returns (uint256);

    /**
     * @notice Retrieves the campaign's funding goal amount.
     * @return The funding goal amount of the campaign.
     */
    function getGoalAmount() external view returns (uint256);

    /**
     * @notice Retrieves the address of the token used in the campaign.
     * @return The address of the campaign's token.
     */
    function getTokenAddress() external view returns (address);

    /**
     * @notice Retrieves the protocol fee percentage for the campaign.
     * @return The protocol fee percentage applied to the campaign.
     */
    function getProtocolFeePercent() external view returns (uint256);

    /**
     * @notice Retrieves the platform fee percentage for a specific platform.
     * @param platformHash The bytes32 identifier of the platform.
     * @return The platform fee percentage applied to the campaign on the platform.
     */
    function getPlatformFeePercent(
        bytes32 platformHash
    ) external view returns (uint256);

    /**
     * @notice Retrieves platform-specific data for the campaign.
     * @param platformDataKey The bytes32 identifier of the platform-specific data.
     * @return The platform-specific data associated with the given key.
     */
    function getPlatformData(
        bytes32 platformDataKey
    ) external view returns (bytes32);

    /**
     * @notice Retrieves the unique identifier hash of the campaign.
     * @return The bytes32 hash that uniquely identifies the campaign.
     */
    function getIdentifierHash() external view returns (bytes32);

    /**
     * @notice Transfers ownership of the contract to a new owner.
     * @param newOwner The address of the new contract owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Updates the campaign's launch time.
     * @param launchTime The new launch timestamp.
     */
    function updateLaunchTime(uint256 launchTime) external;

    /**
     * @notice Updates the campaign's deadline.
     * @param deadline The new deadline timestamp.
     */
    function updateDeadline(uint256 deadline) external;

    /**
     * @notice Updates the campaign's funding goal amount.
     * @param goalAmount The new funding goal amount.
     */
    function updateGoalAmount(uint256 goalAmount) external;

    /**
     * @notice Updates the selection status of a platform for the campaign.
     * @dev It can only be called for a platform if its not approved i.e. the platform treasury is not deployed
     * @param platformHash The bytes32 identifier of the platform.
     * @param selection The new selection status (true or false).
     */
    function updateSelectedPlatform(
        bytes32 platformHash,
        bool selection
    ) external;

    /**
     * @dev Returns true if the campaign is paused, and false otherwise.
     */
    function paused() external view returns (bool);

    /**
     * @dev Returns true if the campaign is cancelled, and false otherwise.
     */
    function cancelled() external view returns (bool);
}
