// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
 * @title ICampaignTreasury
 * @notice An interface for managing campaign treasury contracts.
 */
interface ICampaignTreasury {
    /**
     * @notice Disburses fees collected by the treasury.
     */
    function disburseFees() external;

    /**
     * @notice Withdraws funds from the treasury.
     */
    function withdraw() external;

    /**
     * @notice Claims a refund for a specific token ID.
     * @param tokenId The unique identifier of the refundable token.
     */
    function claimRefund(uint256 tokenId) external;

    /**
     * @notice Retrieves the platform identifier associated with the treasury.
     * @return The platform identifier as a bytes32 value.
     */
    function getplatformBytes() external view returns (bytes32);

    /**
     * @notice Retrieves the platform fee percentage for the treasury.
     * @return The platform fee percentage as a uint256 value.
     */
    function getplatformFeePercent() external view returns (uint256);

    /**
     * @notice Retrieves the total raised amount in the treasury.
     * @return The total raised amount as a uint256 value.
     */
    function getRaisedAmount() external view returns (uint256);
}
