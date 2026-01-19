// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IChainlinkCCIPAdapter
 * @notice Interface for Chainlink CCIP adapters used for refunds.
 */
interface IChainlinkCCIPAdapter {
    /**
     * @notice Sends a refund to the source chain via CCIP.
     * @param destinationChainId Source chainId of the original intent.
     * @param recipient Recipient on the source chain.
     * @param token Token on destination chain to refund.
     * @param amount Amount to refund.
     * @param feeRefundRecipient Address to refund any excess native fee to.
     * @return refundId CCIP message ID.
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address feeRefundRecipient
    )
        external
        payable
        returns (bytes32 refundId);

    /**
     * @notice Quotes the fee required to send a refund via CCIP.
     * @param destinationChainId Source chainId of the original intent.
     * @param token Token to refund.
     * @param amount Amount to refund.
     * @return fee Native fee required by CCIP.
     */
    function quoteRefundFee(uint256 destinationChainId, address token, uint256 amount)
        external
        view
        returns (uint256 fee);
}

