// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ILayerZeroStargateAdapter
 * @notice Interface for the LayerZero Stargate bridge adapter that handles refund operations.
 * @dev The adapter receives cross-chain intents via Stargate's OFT compose mechanism and can send
 *      refunds back to source chains. Intent reception is handled via lzCompose; this interface
 *      exposes refund functionality.
 */
interface ILayerZeroStargateAdapter {
    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Caller is not authorized for this operation.
    error LayerZeroStargateAdapterUnauthorized();

    /// @dev Compose message sender does not match the registered IntentSender for the source chain.
    error LayerZeroStargateAdapterInvalidPeer();

    /// @dev Intent status is not Ongoing (soft failure).
    error LayerZeroStargateAdapterInvalidIntentStatus();

    /// @dev LayerZero endpoint ID does not match the expected ID for the source chain (soft failure).
    error LayerZeroStargateAdapterEidMismatch();

    /// @dev Stargate pool is not configured or does not match the token.
    error LayerZeroStargateAdapterTokenNotConfigured();

    /// @dev No LayerZero endpoint ID configured for the destination chain.
    error LayerZeroStargateAdapterUnknownDestinationChainId();

    /// @dev CrossChainExecutor is not configured in GlobalParams.
    error LayerZeroStargateAdapterExecutorNotSet();

    /// @dev Provided native fee is insufficient for the LayerZero operation.
    error LayerZeroStargateAdapterInsufficientFee(uint256 required, uint256 provided);

    /// @dev Compose message is too short to contain composeFrom.
    error LayerZeroStargateAdapterInvalidComposeMsg();

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when an intent is received and processed via lzCompose.
     * @param guid LayerZero GUID of the incoming message.
     * @param srcEid Source chain's LayerZero endpoint ID.
     * @param intentId Unique intent identifier.
     * @param amount Token amount received.
     */
    event IntentComposed(bytes32 indexed guid, uint32 indexed srcEid, bytes32 indexed intentId, uint256 amount);

    /**
     * @notice Emitted when a refund is sent via Stargate.
     * @param guid LayerZero GUID for tracking.
     * @param destinationChainId EVM chain ID of the refund destination.
     * @param recipient Address receiving the refund on the destination chain.
     * @param token Token being refunded.
     * @param amount Amount of tokens refunded.
     */
    event RefundSentLZStargate(
        bytes32 indexed guid, uint256 destinationChainId, address recipient, address token, uint256 amount
    );

    /**
     * @notice Emitted when protocol admin rescues tokens.
     * @param token Token address rescued.
     * @param recipient Address receiving the rescued tokens.
     * @param amount Amount of tokens rescued.
     */
    event TokensRescued(address indexed token, address indexed recipient, uint256 amount);

    /**
     * @notice Sends a token refund to the source chain via LayerZero Stargate.
     * @dev Only callable by the CrossChainExecutor. Excess native fees are handled by Stargate
     *      and returned to feeRefundRecipient.
     * @param destinationChainId EVM chain ID of the refund destination (original source chain).
     * @param recipient Address on the destination chain to receive the refunded tokens.
     * @param token Token address on this chain to bridge back.
     * @param amount Amount of tokens to refund.
     * @param stargate Stargate pool contract address that supports the token being refunded.
     * @param feeRefundRecipient Address to receive any excess native fee.
     * @return refundId LayerZero GUID for tracking the refund.
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate,
        address feeRefundRecipient
    ) external payable returns (bytes32 refundId);

    /**
     * @notice Quotes the native fee required to send a refund via LayerZero Stargate.
     * @param destinationChainId EVM chain ID of the refund destination.
     * @param recipient Address on the destination chain to receive the refund.
     * @param token Token address to refund.
     * @param amount Amount of tokens to refund.
     * @param stargate Stargate pool contract address that supports the token.
     * @return fee Native token fee required by LayerZero.
     */
    function quoteRefundFee(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate
    ) external view returns (uint256 fee);

    /**
     * @notice Rescues tokens held by the adapter.
     * @param token Token address to rescue.
     * @param recipient Address receiving the rescued tokens.
     * @param amount Amount of tokens to rescue.
     */
    function rescueTokens(address token, address recipient, uint256 amount) external;
}
