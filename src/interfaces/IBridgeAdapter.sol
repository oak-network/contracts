// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IBridgeAdapter
 * @notice Interface that bridge adapters must implement to send refunds.
 */
interface IBridgeAdapter {
    /**
     * @notice Sends a refund to the source chain.
     * @param destinationChainId Source chainId of the original intent.
     * @param recipient Recipient on the source chain.
     * @param token Token on destination chain to refund.
     * @param amount Amount to refund.
     * @return refundId Bridge message ID.
     */
    function sendRefund(uint256 destinationChainId, address recipient, address token, uint256 amount)
        external
        payable
        returns (bytes32 refundId);

    /**
     * @notice Quotes the fee required to send a refund.
     * @param destinationChainId Source chainId of the original intent.
     * @param token Token to refund.
     * @param amount Amount to refund.
     * @return fee Native fee required by the bridge.
     */
    function quoteRefundFee(uint256 destinationChainId, address token, uint256 amount)
        external
        view
        returns (uint256 fee);
}
