// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ICrossChainExecutor
 * @notice Interface for the cross-chain executor that processes payment intents and manages refunds.
 * @dev The executor serves as the destination-chain entry point for cross-chain payment flows.
 *      It validates incoming intents from bridge adapters, dispatches calls to treasury contracts,
 *      and coordinates refund operations back to source chains.
 */
interface ICrossChainExecutor {
    // =============================================================
    //                            ENUMS
    // =============================================================

    /**
     * @notice Lifecycle status of a cross-chain intent.
     * @dev Status transitions:
     *      None -> Ongoing (set by IntentSender on source chain)
     *      Ongoing -> Executed (successful treasury call)
     *      Ongoing -> Failed (validation or call failure)
     *      Executed -> RefundRequested (treasury requests refund)
     *      Failed -> [refund sent] (agent bridges funds back)
     *      RefundRequested -> [refund sent] (agent bridges funds back)
     */
    enum Status {
        None,
        Ongoing,
        Executed,
        RefundRequested,
        Failed
    }

    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @notice Cross-chain intent payload representing a payment operation.
     * @param intentId Unique identifier for this intent, generated on the source chain.
     * @param sourceChainId EVM chain ID where the intent originated.
     * @param status Current lifecycle status of the intent.
     * @param treasury Target treasury contract on the destination chain.
     * @param account The account associated with this intent (payer on source, refund recipient if applicable).
     * @param token Token address (source token initially, updated to destination token by the adapter).
     * @param amount Token amount in the token's native decimals.
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

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when an intent is successfully executed on the treasury.
     * @param bridgeId Identifier of the bridge that delivered the intent.
     * @param intentId Unique identifier of the executed intent.
     * @param account The account that initiated the payment.
     * @param token Token address on the destination chain.
     * @param amount Amount transferred to the treasury.
     * @param treasury Treasury contract that received the funds.
     */
    event IntentExecuted(
        bytes32 indexed bridgeId,
        bytes32 indexed intentId,
        address indexed account,
        address token,
        uint256 amount,
        address treasury
    );

    /**
     * @notice Emitted when an intent fails during validation or execution.
     * @param intentId Unique identifier of the failed intent.
     * @param errorSelector The 4-byte selector of the error that caused the failure.
     */
    event IntentFailed(bytes32 indexed intentId, bytes4 errorSelector);

    /**
     * @notice Emitted when a treasury requests a refund for an executed intent.
     * @param intentId Unique identifier of the intent being refunded.
     * @param token Token to be refunded.
     * @param amount Amount to be refunded.
     * @param recipient Address on the source chain to receive the refund.
     */
    event RefundRequested(bytes32 indexed intentId, address token, uint256 amount, address recipient);

    /**
     * @notice Emitted when a refund is bridged back to the source chain.
     * @param intentId Unique identifier of the refunded intent.
     * @param refundMessageId Bridge message ID for tracking the refund (CCIP messageId or LZ guid).
     */
    event RefundExecuted(bytes32 indexed intentId, bytes32 indexed refundMessageId);

    /**
     * @notice Emitted when a function selector is allowlisted or removed.
     * @param selector Function selector that was updated.
     * @param allowed Whether the selector is now allowed.
     */
    event SelectorAllowed(bytes4 indexed selector, bool allowed);

    /**
     * @notice Emitted when the authorized agent address is updated.
     * @param agent New agent address.
     */
    event AgentSet(address indexed agent);

    // =============================================================
    //                       EXTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Executes a cross-chain intent by forwarding the call to the target treasury.
     * @dev Only callable by registered bridge adapters. If the intent arrives with Failed status,
     *      it records the failure for refund processing without attempting execution.
     * @param bridgeId Identifier of the bridge delivering this intent (e.g., keccak256("CCIP")).
     * @param intent The cross-chain intent payload with updated destination token.
     * @param payload ABI-encoded calldata to forward to the treasury contract.
     */
    function executeIntent(bytes32 bridgeId, Intent memory intent, bytes calldata payload) external;

    /**
     * @notice Records a refund request initiated by a treasury contract.
     * @dev Only callable by the treasury that originally received the intent funds.
     * @param intentId Unique identifier of the intent to refund.
     * @param amount Amount to refund (may be less than original if partial refund).
     * @param recipient Address on the source chain to receive the refund.
     */
    function requestRefund(bytes32 intentId, uint256 amount, address recipient) external;

    /**
     * @notice Bridges a refund back to the source chain via Chainlink CCIP.
     * @dev Only callable by the authorized off-chain agent. Requires native token for bridge fees.
     * @param intentId Unique identifier of the intent to refund.
     * @return refundId CCIP message ID for tracking the refund.
     */
    function sendRefundCCIP(bytes32 intentId) external payable returns (bytes32 refundId);

    /**
     * @notice Bridges a refund back to the source chain via LayerZero Stargate.
     * @dev Only callable by the authorized off-chain agent. Requires native token for bridge fees.
     * @param intentId Unique identifier of the intent to refund.
     * @param stargate Stargate pool contract address for the token being refunded.
     * @return refundId LayerZero GUID for tracking the refund.
     */
    function sendRefundLZStargate(bytes32 intentId, address stargate) external payable returns (bytes32 refundId);

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Returns the registered IntentSender contract for a source chain.
     * @param chainId EVM chain ID of the source chain.
     * @return The IntentSender contract address, or zero if not configured.
     */
    function getIntentSender(uint256 chainId) external view returns (address);

    /**
     * @notice Returns the CCIP chain selector mapped to an EVM chain ID.
     * @param chainId EVM chain ID.
     * @return The CCIP chain selector, or zero if not configured.
     */
    function getCcipChainSelector(uint256 chainId) external view returns (uint64);

    /**
     * @notice Returns the LayerZero endpoint ID mapped to an EVM chain ID.
     * @param chainId EVM chain ID.
     * @return The LayerZero endpoint ID (eid), or zero if not configured.
     */
    function getLayerZeroEid(uint256 chainId) external view returns (uint32);

    /**
     * @notice Returns the current status of an intent.
     * @param intentId Unique identifier of the intent.
     * @return status The intent's lifecycle status.
     */
    function getIntentStatus(bytes32 intentId) external view returns (Status status);

    /**
     * @notice Returns the full intent data for a given intent ID.
     * @param intentId Unique identifier of the intent.
     * @return intent The complete intent struct.
     */
    function getIntent(bytes32 intentId) external view returns (Intent memory intent);
}
