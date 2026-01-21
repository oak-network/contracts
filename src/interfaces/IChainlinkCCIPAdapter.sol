// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IChainlinkCCIPAdapter
 * @notice Interface for the Chainlink CCIP bridge adapter that handles refund operations.
 * @dev The adapter receives cross-chain intents via CCIP and can send refunds back to source chains.
 *      Intent reception is handled internally via CCIPReceiver; this interface exposes refund functionality.
 */
interface IChainlinkCCIPAdapter {
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
