// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ICampaignPaymentTreasury
 * @notice An interface for managing campaign payment treasury contracts.
 */
interface ICampaignPaymentTreasury {

    /**
     * @notice Creates a new payment entry with the specified details.
     * @param paymentId A unique identifier for the payment.
     * @param buyerId The id of the buyer initiating the payment.
     * @param itemId The identifier of the item being purchased.
     * @param paymentToken The token to use for the payment.
     * @param amount The amount to be paid for the item.
     * @param expiration The timestamp after which the payment expires.
     */
    function createPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        address paymentToken,
        uint256 amount,
        uint256 expiration
    ) external;

    /**
     * @notice Creates multiple payment entries in a single transaction to prevent nonce conflicts.
     * @param paymentIds An array of unique identifiers for the payments.
     * @param buyerIds An array of buyer IDs corresponding to each payment.
     * @param itemIds An array of item identifiers corresponding to each payment.
     * @param paymentTokens An array of tokens corresponding to each payment.
     * @param amounts An array of amounts corresponding to each payment.
     * @param expirations An array of expiration timestamps corresponding to each payment.
     */
    function createPaymentBatch(
        bytes32[] calldata paymentIds,
        bytes32[] calldata buyerIds,
        bytes32[] calldata itemIds,
        address[] calldata paymentTokens,
        uint256[] calldata amounts,
        uint256[] calldata expirations
    ) external;

    /**
     * @notice Allows a buyer to make a direct crypto payment for an item.
     * @dev This function transfers tokens directly from the buyer's wallet and confirms the payment immediately.
     * @param paymentId The unique identifier of the payment.
     * @param itemId The identifier of the item being purchased.
     * @param buyerAddress The address of the buyer making the payment.
     * @param paymentToken The token to use for the payment.
     * @param amount The amount to be paid for the item.
     */
    function processCryptoPayment(
        bytes32 paymentId,
        bytes32 itemId,
        address buyerAddress,
        address paymentToken,
        uint256 amount
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
     * @param buyerAddress Optional buyer address to mint NFT to. Pass address(0) to skip NFT minting.
     */
    function confirmPayment(
        bytes32 paymentId,
        address buyerAddress
    ) external;

    /**
     * @notice Confirms and finalizes multiple payments in a single transaction.
     * @param paymentIds An array of unique payment identifiers to be confirmed.
     * @param buyerAddresses Array of buyer addresses to mint NFTs to. Must match paymentIds length. Pass address(0) to skip NFT minting for specific payments.
     */
    function confirmPaymentBatch(
        bytes32[] calldata paymentIds,
        address[] calldata buyerAddresses
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
    function claimRefund(
        bytes32 paymentId
    ) external;

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
     * @notice Checks if the treasury has been cancelled.
     * @return True if the treasury is cancelled, false otherwise.
     */
    function cancelled() external view returns (bool);
}
