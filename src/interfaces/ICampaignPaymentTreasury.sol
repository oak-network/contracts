// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICampaignPaymentTreasury
 * @notice An interface for managing campaign payment treasury contracts.
 */
interface ICampaignPaymentTreasury {

    /**
     * @notice Creates a new payment entry with the specified details.
     * @param paymentId A unique identifier for the payment.
     * @param buyerAddress The address of the buyer initiating the payment.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     */
    function createPayment(
        bytes32 paymentId,
        address buyerAddress,
        bytes32 itemId,
        uint256 amount,
        uint256 expiration
    ) external;

    /**
     * @notice Cancels an existing payment with the given payment ID.
     * @param paymentId The unique identifier of the payment to cancel.
     */
    function cancelPayment(
        bytes32 paymentId
    ) external;

    /**
     * @notice Confirms and finalizes the payment associated with the given payment ID.
     * @param paymentId The unique identifier of the payment to confirm.
     */
    function confirmPayment(
        bytes32 paymentId
    ) external;

    /**
     * @notice Confirms and finalizes multiple payments in a single transaction.
     * @param paymentIds An array of unique payment identifiers to be confirmed.
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds
    ) external;

    /**
     * @notice Disburses fees collected by the treasury.
     */
    function disburseFees() external;

    /**
     * @notice Withdraws funds from the treasury.
     */
    function withdraw() external;

    /**
     * @notice Claims a refund for a specific payment ID.
     * @param paymentId The unique identifier of the refundable payment.
     * @param refundAddress The address where the refunded amount should be sent.
     */
    function claimRefund(bytes32 paymentId, address refundAddress) external;

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
     * @notice Retrieves the currently available raised amount in the treasury.
     * @return The current available raised amount as a uint256 value.
     */
    function getAvailableRaisedAmount() external view returns (uint256);
}
