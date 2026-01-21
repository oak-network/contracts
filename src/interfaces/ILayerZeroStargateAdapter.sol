// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ILayerZeroStargateAdapter
 * @notice Interface for LayerZero/Stargate bridge adapters used for refunds.
 */
interface ILayerZeroStargateAdapter {
    /**
     * @notice Sends a refund to the source chain via LayerZero/Stargate.
     * @param destinationChainId Source chainId of the original intent.
     * @param recipient Recipient on the source chain.
     * @param token Token on destination chain to refund.
     * @param amount Amount to refund.
     * @param stargate Stargate contract address on destination chain used for bridging this token.
     * @param feeRefundRecipient Address to refund any excess native fee to.
     * @return refundId LayerZero GUID.
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate,
        address feeRefundRecipient
    )
        external
        payable
        returns (bytes32 refundId);

    /**
     * @notice Quotes the fee required to send a refund via LayerZero/Stargate.
     * @param destinationChainId Source chainId of the original intent.
     * @param recipient Recipient on the source chain.
     * @param token Token to refund.
     * @param amount Amount to refund.
     * @param stargate Stargate contract address on destination chain used for bridging this token.
     * @return fee Native fee required by LayerZero.
     */
    function quoteRefundFee(uint256 destinationChainId, address recipient, address token, uint256 amount, address stargate)
        external
        view
        returns (uint256 fee);
}

