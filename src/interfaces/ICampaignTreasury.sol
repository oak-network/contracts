// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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
    function getplatformHash() external view returns (bytes32);

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

    /**
     * @notice Retrieves the lifetime raised amount in the treasury (never decreases with refunds).
     * @return The lifetime raised amount as a uint256 value.
     */
    function getLifetimeRaisedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total refunded amount in the treasury.
     * @return The total refunded amount as a uint256 value.
     */
    function getRefundedAmount() external view returns (uint256);

    /**
     * @notice Checks if the treasury has been cancelled.
     * @return True if the treasury is cancelled, false otherwise.
     */
    function cancelled() external view returns (bool);
}
