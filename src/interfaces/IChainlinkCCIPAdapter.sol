// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IChainlinkCCIPAdapter
 * @notice Interface for the Chainlink CCIP bridge adapter that handles refund operations.
 * @dev The adapter receives cross-chain intents via CCIP and can send refunds back to source chains.
 *      Intent reception is handled internally via CCIPReceiver; this interface exposes refund functionality.
 */
interface IChainlinkCCIPAdapter {
    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Caller is not authorized for this operation.
    error ChainlinkCCIPAdapterUnauthorized();

    /// @dev Message sender does not match the registered IntentSender for the source chain.
    error ChainlinkCCIPAdapterInvalidIntentSender();

    /// @dev Intent status is not Ongoing (soft failure).
    error ChainlinkCCIPAdapterInvalidIntentStatus();

    /// @dev CCIP chain selector does not match the expected selector for the source chain (soft failure).
    error ChainlinkCCIPAdapterChainSelectorMismatch();

    /// @dev Received token amount does not match the intent amount (soft failure).
    error ChainlinkCCIPAdapterAmountMismatch();

    /// @dev No CCIP chain selector configured for the destination chain.
    error ChainlinkCCIPAdapterUnknownChainSelector();

    /// @dev Provided native fee is insufficient for the CCIP operation.
    error ChainlinkCCIPAdapterInsufficientFee(uint256 required, uint256 provided);

    /// @dev Failed to refund excess native fee.
    error ChainlinkCCIPAdapterFeeRefundFailed();

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when a refund is sent via CCIP.
     * @param messageId CCIP message ID for tracking.
     * @param destinationChainId EVM chain ID of the refund destination.
     * @param recipient Address receiving the refund on the destination chain.
     * @param amount Amount of tokens refunded.
     */
    event RefundSentCCIP(bytes32 indexed messageId, uint256 destinationChainId, address recipient, uint256 amount);

    /**
     * @notice Sends a token refund to the source chain via Chainlink CCIP.
     * @dev Only callable by the CrossChainExecutor. Excess native fees are returned to feeRefundRecipient.
     * @param destinationChainId EVM chain ID of the refund destination (original source chain).
     * @param recipient Address on the destination chain to receive the refunded tokens.
     * @param token Token address on this chain to bridge back.
     * @param amount Amount of tokens to refund.
     * @param feeRefundRecipient Address to receive any excess native fee.
     * @return messageId CCIP message ID for tracking the refund.
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address feeRefundRecipient
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Quotes the native fee required to send a refund via CCIP.
     * @param destinationChainId EVM chain ID of the refund destination.
     * @param recipient Address on the destination chain to receive the refund.
     * @param token Token address to refund.
     * @param amount Amount of tokens to refund.
     * @return fee Native token fee required by CCIP.
     */
    function quoteRefundFee(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount
    ) external view returns (uint256 fee);
}
