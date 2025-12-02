// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ICampaignPaymentTreasury
 * @notice An interface for managing campaign payment treasury contracts.
 */
interface ICampaignPaymentTreasury {
    /**
     * @notice Represents a stored line item with its configuration snapshot.
     * @param typeId The type identifier of the line item.
     * @param amount The amount of the line item.
     * @param label The human-readable label of the line item type.
     * @param countsTowardGoal Whether this line item counts toward the campaign goal.
     * @param applyProtocolFee Whether protocol fee applies to this line item.
     * @param canRefund Whether this line item can be refunded.
     * @param instantTransfer Whether this line item is transferred instantly.
     */
    struct PaymentLineItem {
        bytes32 typeId;
        uint256 amount;
        string label;
        bool countsTowardGoal;
        bool applyProtocolFee;
        bool canRefund;
        bool instantTransfer;
    }

    /**
     * @notice Comprehensive payment data structure containing all payment information.
     * @param buyerAddress The address of the buyer who made the payment.
     * @param buyerId The ID of the buyer.
     * @param itemId The identifier of the item being purchased.
     * @param amount The amount to be paid for the item (in token's native decimals).
     * @param expiration The timestamp after which the payment expires.
     * @param isConfirmed Boolean indicating whether the payment has been confirmed.
     * @param isCryptoPayment Boolean indicating whether the payment is made using direct crypto payment.
     * @param lineItemCount The number of line items associated with this payment.
     * @param paymentToken The token address used for this payment.
     * @param lineItems Array of stored line items with their configuration snapshots.
     * @param externalFees Array of external fee metadata associated with this payment (informational only).
     */
    struct PaymentData {
        address buyerAddress;
        bytes32 buyerId;
        bytes32 itemId;
        uint256 amount;
        uint256 expiration;
        bool isConfirmed;
        bool isCryptoPayment;
        uint256 lineItemCount;
        address paymentToken;
        PaymentLineItem[] lineItems;
        ExternalFees[] externalFees;
    }

    /**
     * @notice Represents a line item in a payment.
     * @param typeId The type identifier of the line item (must exist in GlobalParams).
     * @param amount The amount of the line item (denominated in pledge token).
     */
    struct LineItem {
        bytes32 typeId;
        uint256 amount;
    }

    /**
     * @notice Represents metadata about external fees associated with a payment.
     * @dev These values are informational only and do not affect treasury balances or transfers.
     * @param feeType The type identifier of the external fee.
     * @param feeAmount The amount of the external fee.
     */
    struct ExternalFees {
        bytes32 feeType;
        uint256 feeAmount;
    }

    /**
     * @notice Creates a new payment entry with the specified details.
     * @param paymentId A unique identifier for the payment.
     * @param buyerId The id of the buyer initiating the payment.
     * @param itemId The identifier of the item being purchased.
     * @param paymentToken The token to use for the payment.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     * @param lineItems Array of line items associated with this payment.
     * @param externalFees Array of external fee metadata captured for this payment (informational only).
     */
    function createPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        address paymentToken,
        uint256 amount,
        uint256 expiration,
        LineItem[] calldata lineItems,
        ExternalFees[] calldata externalFees
    ) external;

    /**
     * @notice Creates multiple payment entries in a single transaction to prevent nonce conflicts.
     * @param paymentIds An array of unique identifiers for the payments.
     * @param buyerIds An array of buyer IDs corresponding to each payment.
     * @param itemIds An array of item identifiers corresponding to each payment.
     * @param paymentTokens An array of tokens corresponding to each payment.
     * @param amounts An array of amounts corresponding to each payment.
     * @param expirations An array of expiration timestamps corresponding to each payment.
     * @param lineItemsArray An array of line item arrays, one for each payment.
     * @param externalFeesArray An array of external fee metadata arrays, one for each payment (informational only).
     */
    function createPaymentBatch(
        bytes32[] calldata paymentIds,
        bytes32[] calldata buyerIds,
        bytes32[] calldata itemIds,
        address[] calldata paymentTokens,
        uint256[] calldata amounts,
        uint256[] calldata expirations,
        LineItem[][] calldata lineItemsArray,
        ExternalFees[][] calldata externalFeesArray
    ) external;

    /**
     * @notice Allows a buyer to make a direct crypto payment for an item.
     * @dev This function transfers tokens directly from the buyer's wallet and confirms the payment immediately.
     * @param paymentId The unique identifier of the payment.
     * @param itemId The identifier of the item being purchased.
     * @param buyerAddress The address of the buyer making the payment.
     * @param paymentToken The token to use for the payment.
     * @param amount The amount to be paid for the item.
     * @param lineItems Array of line items associated with this payment.
     * @param externalFees Array of external fee metadata captured for this payment (informational only).
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        address paymentToken,
        uint256 amount,
        LineItem[] calldata lineItems,
        ExternalFees[] calldata externalFees
    ) external;

    /**
     * @notice Cancels an existing payment with the given payment ID.
     * @param paymentId The unique identifier of the payment to cancel.
     */
    function cancelPayment(bytes32 paymentId) external;

    /**
     * @notice Confirms and finalizes the payment associated with the given payment ID.
     * @param paymentId The unique identifier of the payment to confirm.
     * @param buyerAddress Optional buyer address to mint NFT to. Pass address(0) to skip NFT minting.
     */
    function confirmPayment(bytes32 paymentId, address buyerAddress) external;

    /**
     * @notice Confirms and finalizes multiple payments in a single transaction.
     * @param paymentIds An array of unique payment identifiers to be confirmed.
     * @param buyerAddresses Array of buyer addresses to mint NFTs to. Must match paymentIds length. Pass address(0) to skip NFT minting for specific payments.
     */
    function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses) external;

    /**
     * @notice Disburses fees collected by the treasury.
     */
    function disburseFees() external;

    /**
     * @notice Withdraws funds from the treasury.
     */
    function withdraw() external;

    /**
     * @notice Claims a refund for non-NFT payments (payments without minted NFTs).
     * @dev Only callable by platform admin. Used for payments confirmed without a buyer address.
     * @param paymentId The unique identifier of the refundable payment (must NOT have an NFT).
     * @param refundAddress The address where the refunded amount should be sent.
     */
    function claimRefund(bytes32 paymentId, address refundAddress) external;

    /**
     * @notice Claims a refund for NFT payments (payments with minted NFTs).
     * @dev Burns the NFT associated with the payment. Caller must have approved the treasury for the NFT.
     * Used for processCryptoPayment and confirmPayment (with buyer address) transactions.
     * @param paymentId The unique identifier of the refundable payment (must have an NFT).
     */
    function claimRefund(bytes32 paymentId) external;

    /**
     * @notice Allows platform admin to claim all remaining funds once the claim window has opened.
     */
    function claimExpiredFunds() external;

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

    /**
     * @notice Retrieves comprehensive payment data including payment info, token, line items, and external fees.
     * @param paymentId The unique identifier of the payment.
     * @return A PaymentData struct containing all payment information.
     */
    function getPaymentData(bytes32 paymentId) external view returns (PaymentData memory);

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
     * @notice Retrieves the total expected (pending) amount in the treasury.
     * @dev This represents payments that have been created but not yet confirmed.
     * @return The total expected amount as a uint256 value.
     */
    function getExpectedAmount() external view returns (uint256);

    /**
     * @notice Checks if the treasury has been cancelled.
     * @return True if the treasury is cancelled, false otherwise.
     */
    function cancelled() external view returns (bool);
}
