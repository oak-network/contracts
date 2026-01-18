// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ICrossChainExecutor
 * @notice Interface for the Executor that handles cross-chain intents and refunds.
 */
interface ICrossChainExecutor {
    enum IntentStatus {
        Unseen,
        Executed,
        RefundRequested,
        Refunded
    }

    /**
     * @notice Cross-chain intent payload delivered to Ethereum.
     * @param intentId Unique identifier for this intent.
     * @param sourceChainId EVM chainId of the source chain.
     * @param treasury Target treasury on Ethereum.
     * @param sender Original sender on source chain.
     * @param sourceToken Token on the source chain.
     * @param amount Amount delivered (token decimals).
     * @param deadline Expiration timestamp.
     * @param data ABI-encoded calldata for the treasury entrypoint.
     */
    struct CrossChainIntent {
        bytes32 intentId;
        uint256 sourceChainId;
        address treasury;
        address sender;
        address sourceToken;
        uint256 amount;
        uint256 deadline;
        bytes data;
    }

    /**
     * @notice Refund intent recorded by the executor.
     * @param destinationToken Token to refund on Ethereum.
     * @param amount Amount to refund.
     * @param recipient Recipient on the source chain.
     * @param sourceChainId Source chainId for routing.
     */
    struct RefundIntent {
        address destinationToken;
        uint256 amount;
        address recipient;
        uint256 sourceChainId;
    }

    /**
     * @notice Execute a cross-chain intent on the destination chain.
     * @param bridgeId Bridge identifier.
     * @param intent Cross-chain intent payload.
     * @param receivedToken Token received on the destination chain for this intent.
     */
    function executeIntent(bytes32 bridgeId, CrossChainIntent calldata intent, address receivedToken) external;

    /**
     * @notice Returns the registered IntentSender for a given source chainId.
     */
    function getIntentSender(uint256 chainId) external view returns (address);

    /**
     * @notice Returns the stored CCIP chain selector for a given source chainId.
     */
    function getCcipChainSelector(uint256 chainId) external view returns (uint64);

    /**
     * @notice Returns the stored LayerZero eid for a given source chainId.
     */
    function getLayerZeroEid(uint256 chainId) external view returns (uint32);

    /**
     * @notice Record a refund request for an executed intent.
     * @param intentId Intent identifier.
     * @param destinationToken Token to refund.
     * @param amount Refund amount.
     * @param recipient Source-chain recipient.
     */
    function requestRefund(bytes32 intentId, address destinationToken, uint256 amount, address recipient) external;

    /**
     * @notice Bridge a refund back to the source chain via CCIP.
     * @dev Callable only by the configured off-chain agent.
     * @param intentId Intent identifier.
     * @return refundId CCIP message ID.
     */
    function executeRefundCCIP(bytes32 intentId) external payable returns (bytes32 refundId);

    /**
     * @notice Bridge a refund back to the source chain via LayerZero/Stargate.
     * @dev Callable only by the configured off-chain agent.
     * @param intentId Intent identifier.
     * @return refundId LayerZero GUID.
     */
    function executeRefundLZStargate(bytes32 intentId) external payable returns (bytes32 refundId);

    /// @notice Returns the status of a given intent.
    function getIntentStatus(bytes32 intentId) external view returns (IntentStatus status);

    /// @notice Returns the refund intent for a given intent ID.
    function getRefundIntent(bytes32 intentId) external view returns (RefundIntent memory refundIntent);


    event IntentExecuted(
        bytes32 indexed bridgeId,
        bytes32 indexed intentId,
        address indexed sender,
        address token,
        uint256 amount,
        address treasury
    );
    event RefundRequested(bytes32 indexed intentId, address token, uint256 amount, address recipient);
    event RefundExecuted(bytes32 indexed intentId, bytes32 indexed refundMessageId);
    event TreasurySelectorAllowed(address indexed treasury, bytes4 indexed selector, bool allowed);
    event AgentSet(address indexed agent);
}
