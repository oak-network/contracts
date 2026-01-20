// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ICrossChainExecutor
 * @notice Interface for the Executor that handles cross-chain intents and refunds.
 */
interface ICrossChainExecutor {
    enum Status {
        None,
        Ongoing,
        Executed,
        RefundRequested,
        Failed
    }

    /**
     * @notice Cross-chain intent payload.
     * @param intentId Unique identifier for this intent.
     * @param sourceChainId EVM chainId of the source chain.
     * @param status Current status of the intent.
     * @param treasury Target treasury on destination chain.
     * @param account The account associated with this intent (sender on source, recipient on refund).
     * @param token The token for this intent (source token initially, updated to destination token by adapter).
     * @param amount Amount (token decimals).
     */
    struct Intent {
        bytes32 intentId;
        uint256 sourceChainId;
        Status status;
        address treasury;
        address account;
        address token;
        uint256 amount;
    }

    /**
     * @notice Execute a cross-chain intent on the destination chain.
     * @param bridgeId Bridge identifier.
     * @param intent Cross-chain intent payload.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     */
    function executeIntent(bytes32 bridgeId, Intent memory intent, bytes calldata payload) external;

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
     * @param amount Refund amount.
     * @param recipient Source-chain recipient.
     */
    function requestRefund(bytes32 intentId, uint256 amount, address recipient) external;

    /**
     * @notice Bridge a refund back to the source chain via CCIP.
     * @dev Callable only by the configured off-chain agent.
     * @param intentId Intent identifier.
     * @return refundId CCIP message ID.
     */
    function sendRefundCCIP(bytes32 intentId) external payable returns (bytes32 refundId);

    /**
     * @notice Bridge a refund back to the source chain via LayerZero/Stargate.
     * @dev Callable only by the configured off-chain agent.
     * @param intentId Intent identifier.
     * @param stargate Stargate contract address on the destination chain used for refund bridging.
     * @return refundId LayerZero GUID.
     */
    function sendRefundLZStargate(bytes32 intentId, address stargate) external payable returns (bytes32 refundId);

    /// @notice Returns the status of a given intent.
    function getIntentStatus(bytes32 intentId) external view returns (Status status);

    /// @notice Returns the full intent for a given intent ID.
    function getIntent(bytes32 intentId) external view returns (Intent memory intent);


    event IntentExecuted(
        bytes32 indexed bridgeId,
        bytes32 indexed intentId,
        address indexed account,
        address token,
        uint256 amount,
        address treasury
    );
    event RefundRequested(bytes32 indexed intentId, address token, uint256 amount, address recipient);
    event RefundExecuted(bytes32 indexed intentId, bytes32 indexed refundMessageId);
    event TreasurySelectorAllowed(address indexed treasury, bytes4 indexed selector, bool allowed);
    event AgentSet(address indexed agent);
}
