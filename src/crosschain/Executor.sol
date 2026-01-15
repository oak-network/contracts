// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IGlobalParams} from "../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {CrossChainRegistryKeys} from "../constants/CrossChainRegistryKeys.sol";

/**
 * @title Executor
 * @notice Destination-chain executor that dispatches cross-chain intents to treasuries.
 */
contract Executor is ICrossChainExecutor, Pausable {
    using SafeERC20 for IERC20;

    IGlobalParams public immutable GLOBAL_PARAMS;

    struct IntentRecord {
        IntentStatus status;
        uint256 sourceChainId;
        bytes32 inboundBridgeId;
        address sourceToken;
        address destinationToken;
        uint256 escrowedAmount;
        address sender;
        address treasury;
    }

    mapping(bytes32 => IntentRecord) public intents;
    mapping(bytes32 => RefundIntent) private _refundIntents;
    mapping(address => mapping(bytes4 => bool)) public allowedTreasurySelectors;
    address public agent;

    error ExecutorUnauthorized();
    error ExecutorIntentAlreadyProcessed(bytes32 intentId);
    error ExecutorAdapterMismatch(bytes32 bridgeId, address caller);
    error ExecutorInvalidData();
    error ExecutorSelectorNotAllowed(address treasury, bytes4 selector);
    error ExecutorRefundNotRequested(bytes32 intentId);
    error ExecutorInvalidRefund(bytes32 intentId);
    error ExecutorInsufficientFee(uint256 required, uint256 provided);
    error ExecutorCallFailed(bytes32 intentId, bytes data);

    modifier onlyProtocolAdmin() {
        if (msg.sender != GLOBAL_PARAMS.getProtocolAdminAddress()) {
            revert ExecutorUnauthorized();
        }
        _;
    }

    modifier onlyAgent() {
        if (msg.sender != agent) {
            revert ExecutorUnauthorized();
        }
        _;
    }

    constructor(IGlobalParams globalParams) {
        GLOBAL_PARAMS = globalParams;
    }

    /**
     * @notice Executes an adapter-authenticated intent by forwarding calldata to the treasury.
     * @param bridgeId Bridge identifier (e.g. keccak256("CCIP")).
     * @param intent The cross-chain intent payload.
     */
    function executeIntent(bytes32 bridgeId, CrossChainIntent calldata intent)
        external
        override
        whenNotPaused
    {
        // Adapter-authenticated intent dispatch; selector allowlist prevents arbitrary calls.
        if (intents[intent.intentId].status != IntentStatus.Unseen) {
            revert ExecutorIntentAlreadyProcessed(intent.intentId);
        }
        if (intent.data.length < 4) {
            revert ExecutorInvalidData();
        }

        address expectedAdapter = _getBridgeAdapter(bridgeId);
        if (expectedAdapter == address(0) || msg.sender != expectedAdapter) {
            revert ExecutorAdapterMismatch(bridgeId, msg.sender);
        }

        bytes4 selector = bytes4(intent.data);
        if (!allowedTreasurySelectors[intent.treasury][selector]) {
            revert ExecutorSelectorNotAllowed(intent.treasury, selector);
        }

        intents[intent.intentId] = IntentRecord({
            status: IntentStatus.Executed,
            sourceChainId: intent.sourceChainId,
            inboundBridgeId: bridgeId,
            sourceToken: intent.sourceToken,
            destinationToken: intent.destinationToken,
            escrowedAmount: intent.amount,
            sender: intent.sender,
            treasury: intent.treasury
        });

        IERC20(intent.destinationToken).safeTransfer(intent.treasury, intent.amount);

        (bool success, bytes memory returndata) = intent.treasury.call(intent.data);
        if (!success) {
            revert ExecutorCallFailed(intent.intentId, returndata);
        }

        emit IntentExecuted(intent.intentId, intent.sender, intent.destinationToken, intent.amount, intent.treasury);
    }

    /**
     * @notice Records a refund request initiated by the treasury.
     * @param intentId The cross-chain intent ID.
     * @param destinationToken The token to refund on destination.
     * @param amount The amount to refund.
     * @param recipient The recipient on the source chain.
     */
    function requestRefund(bytes32 intentId, address destinationToken, uint256 amount, address recipient)
        external
        override
        whenNotPaused
    {
        // Called by treasury after refund state updates; executor only records the request.
        IntentRecord storage record = intents[intentId];
        if (record.status != IntentStatus.Executed) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (msg.sender != record.treasury) {
            revert ExecutorUnauthorized();
        }
        if (recipient == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (amount == 0 || amount > record.escrowedAmount) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (destinationToken != record.destinationToken) {
            revert ExecutorInvalidRefund(intentId);
        }

        record.status = IntentStatus.RefundRequested;
        _refundIntents[intentId] = RefundIntent({
            destinationToken: destinationToken,
            amount: amount,
            recipient: recipient,
            sourceChainId: record.sourceChainId
        });

        emit RefundRequested(intentId, destinationToken, amount, recipient);
    }

    /**
     * @notice Bridges refund funds back to the source chain.
     * @param intentId The cross-chain intent ID.
     * @param refundBridgeId Bridge identifier to use for the refund.
     * @return refundId The bridge-specific refund message ID.
     */
    function executeRefund(bytes32 intentId, bytes32 refundBridgeId)
        external
        payable
        override
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        // Agent-triggered refund bridging using configured adapter.
        IntentRecord storage record = intents[intentId];
        if (record.status != IntentStatus.RefundRequested) {
            revert ExecutorRefundNotRequested(intentId);
        }
        RefundIntent memory refundIntent = _refundIntents[intentId];
        if (refundIntent.amount == 0 || refundIntent.recipient == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }

        address adapter = _getBridgeAdapter(refundBridgeId);
        if (adapter == address(0)) {
            revert ExecutorAdapterMismatch(refundBridgeId, address(0));
        }

        uint256 requiredFee = IBridgeAdapter(adapter).quoteRefundFee(
            refundIntent.sourceChainId, refundIntent.destinationToken, refundIntent.amount
        );
        if (msg.value < requiredFee) {
            revert ExecutorInsufficientFee(requiredFee, msg.value);
        }

        record.status = IntentStatus.Refunded;

        IERC20(refundIntent.destinationToken).forceApprove(adapter, refundIntent.amount);
        refundId = IBridgeAdapter(adapter).sendRefund{value: msg.value}(
            refundIntent.sourceChainId, refundIntent.recipient, refundIntent.destinationToken, refundIntent.amount
        );
        IERC20(refundIntent.destinationToken).forceApprove(adapter, 0);

        emit RefundExecuted(intentId, refundId);
    }

    function getIntentStatus(bytes32 intentId) external view override returns (IntentStatus status) {
        return intents[intentId].status;
    }

    function getRefundIntent(bytes32 intentId) external view override returns (RefundIntent memory refundIntent) {
        return _refundIntents[intentId];
    }

    /**
     * @notice Allowlists a treasury selector for cross-chain calls.
     * @param treasury The treasury address.
     * @param selector The function selector to allow.
     * @param allowed Whether the selector is allowed.
     */
    function setTreasurySelector(address treasury, bytes4 selector, bool allowed) external onlyProtocolAdmin {
        allowedTreasurySelectors[treasury][selector] = allowed;
        emit TreasurySelectorAllowed(treasury, selector, allowed);
    }

    /// @notice Sets the single off-chain agent authorized to execute refunds.
    function setAgent(address newAgent) external onlyProtocolAdmin {
        if (newAgent == address(0)) {
            revert ExecutorUnauthorized();
        }
        agent = newAgent;
        emit AgentSet(newAgent);
    }

    /// @notice Pauses executor operations.
    function pause() external onlyProtocolAdmin {
        _pause();
    }

    /// @notice Unpauses executor operations.
    function unpause() external onlyProtocolAdmin {
        _unpause();
    }

    function _getBridgeAdapter(bytes32 bridgeId) internal view returns (address) {
        bytes32 value = GLOBAL_PARAMS.getFromRegistry(CrossChainRegistryKeys.bridgeAdapter(bridgeId));
        return address(uint160(uint256(value)));
    }

}
