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
}
