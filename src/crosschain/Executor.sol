// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IGlobalParams} from "../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

/**
 * @title Executor
 * @notice Destination-chain executor that dispatches cross-chain intents to treasuries.
 */
contract Executor is ICrossChainExecutor, Pausable {
    using SafeERC20 for IERC20;

    IGlobalParams public immutable GLOBAL_PARAMS;

    bytes32 public constant BRIDGE_ID_CCIP = keccak256("CCIP");
    bytes32 public constant BRIDGE_ID_LAYERZERO = keccak256("LAYERZERO");

    // Bridge adapter allowlist (bridgeId => adapter address)
    mapping(bytes32 => address) private _bridgeAdapters;
    // Source chain configuration (owned by Executor per spec)
    mapping(uint256 => address) private _intentSenders;
    mapping(uint256 => uint64) private _ccipChainSelectors;
    mapping(uint256 => uint32) private _layerZeroEids;

    struct IntentRecord {
        IntentStatus status;
        uint256 sourceChainId;
        address sourceToken;
        address destinationToken; // token delivered on destination chain (for refunds)
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
    error ExecutorInvalidSenderConfig(uint256 chainId);
    error ExecutorBridgeAdapterNotSet(bytes32 bridgeId);
    error ExecutorInvalidBridgeAdapter(bytes32 bridgeId);
    error ExecutorInvalidChainSelector(uint256 chainId);
    error ExecutorInvalidLayerZeroEid(uint256 chainId);

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
     * @param receivedToken Token received on destination for this intent.
     */
    function executeIntent(bytes32 bridgeId, CrossChainIntent calldata intent, address receivedToken)
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

        address expectedAdapter = _bridgeAdapters[bridgeId];
        if (expectedAdapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(bridgeId);
        }
        if (msg.sender != expectedAdapter) {
            revert ExecutorAdapterMismatch(bridgeId, msg.sender);
        }

        bytes4 selector = bytes4(intent.data);
        if (!allowedTreasurySelectors[intent.treasury][selector]) {
            revert ExecutorSelectorNotAllowed(intent.treasury, selector);
        }

        intents[intent.intentId] = IntentRecord({
            status: IntentStatus.Executed,
            sourceChainId: intent.sourceChainId,
            sourceToken: intent.sourceToken,
            destinationToken: receivedToken,
            escrowedAmount: intent.amount,
            sender: intent.sender,
            treasury: intent.treasury
        });

        IERC20(receivedToken).safeTransfer(intent.treasury, intent.amount);

        (bool success, bytes memory returndata) = intent.treasury.call(intent.data);
        if (!success) {
            revert ExecutorCallFailed(intent.intentId, returndata);
        }

        emit IntentExecuted(bridgeId, intent.intentId, intent.sender, receivedToken, intent.amount, intent.treasury);
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
     * @inheritdoc ICrossChainExecutor
     */
    function executeRefundCCIP(bytes32 intentId)
        external
        payable
        override
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        IntentRecord storage record = intents[intentId];
        if (record.status != IntentStatus.RefundRequested) {
            revert ExecutorRefundNotRequested(intentId);
        }
        RefundIntent memory refundIntent = _refundIntents[intentId];
        if (refundIntent.amount == 0 || refundIntent.recipient == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }

        address adapter = _bridgeAdapters[BRIDGE_ID_CCIP];
        if (adapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(BRIDGE_ID_CCIP);
        }

        uint256 requiredFee = IBridgeAdapter(adapter).quoteRefundFee(
            refundIntent.sourceChainId, refundIntent.destinationToken, refundIntent.amount
        );
        if (msg.value < requiredFee) {
            revert ExecutorInsufficientFee(requiredFee, msg.value);
        }

        record.status = IntentStatus.Refunded;

        IERC20(refundIntent.destinationToken).forceApprove(adapter, refundIntent.amount);
        refundId = IBridgeAdapter(adapter).sendRefund{value: requiredFee}(
            refundIntent.sourceChainId, refundIntent.recipient, refundIntent.destinationToken, refundIntent.amount
        );
        IERC20(refundIntent.destinationToken).forceApprove(adapter, 0);

        // Refund any excess msg.value back to the agent.
        if (msg.value > requiredFee) {
            (bool ok,) = msg.sender.call{value: msg.value - requiredFee}("");
            if (!ok) {
                revert ExecutorUnauthorized();
            }
        }

        emit RefundExecuted(intentId, refundId);
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function executeRefundLZStargate(bytes32 intentId)
        external
        payable
        override
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        IntentRecord storage record = intents[intentId];
        if (record.status != IntentStatus.RefundRequested) {
            revert ExecutorRefundNotRequested(intentId);
        }
        RefundIntent memory refundIntent = _refundIntents[intentId];
        if (refundIntent.amount == 0 || refundIntent.recipient == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }

        address adapter = _bridgeAdapters[BRIDGE_ID_LAYERZERO];
        if (adapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(BRIDGE_ID_LAYERZERO);
        }

        uint256 requiredFee = IBridgeAdapter(adapter).quoteRefundFee(
            refundIntent.sourceChainId, refundIntent.destinationToken, refundIntent.amount
        );
        if (msg.value < requiredFee) {
            revert ExecutorInsufficientFee(requiredFee, msg.value);
        }

        record.status = IntentStatus.Refunded;

        IERC20(refundIntent.destinationToken).forceApprove(adapter, refundIntent.amount);
        refundId = IBridgeAdapter(adapter).sendRefund{value: requiredFee}(
            refundIntent.sourceChainId, refundIntent.recipient, refundIntent.destinationToken, refundIntent.amount
        );
        IERC20(refundIntent.destinationToken).forceApprove(adapter, 0);

        if (msg.value > requiredFee) {
            (bool ok,) = msg.sender.call{value: msg.value - requiredFee}("");
            if (!ok) {
                revert ExecutorUnauthorized();
            }
        }

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

    /**
     * @notice Registers the source-chain IntentSender contract for a chainId.
     */
    function setIntentSender(uint256 chainId, address intentSender) external onlyProtocolAdmin {
        if (intentSender == address(0)) {
            revert ExecutorInvalidSenderConfig(chainId);
        }
        _intentSenders[chainId] = intentSender;
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function getIntentSender(uint256 chainId) external view override returns (address) {
        return _intentSenders[chainId];
    }

    /**
     * @notice Registers a bridge adapter for a bridgeId.
     */
    function setBridgeAdapter(bytes32 bridgeId, address adapter) external onlyProtocolAdmin {
        if (adapter == address(0)) {
            revert ExecutorInvalidBridgeAdapter(bridgeId);
        }
        _bridgeAdapters[bridgeId] = adapter;
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function getCcipChainSelector(uint256 chainId) external view override returns (uint64) {
        return _ccipChainSelectors[chainId];
    }

    /// @notice Sets the CCIP chain selector for a source chainId. Only protocol admin.
    function setCcipChainSelector(uint256 chainId, uint64 chainSelector) external onlyProtocolAdmin {
        if (chainSelector == 0) {
            revert ExecutorInvalidChainSelector(chainId);
        }
        _ccipChainSelectors[chainId] = chainSelector;
    }

    /// @notice Batch set CCIP chain selectors. Only protocol admin.
    function setCcipChainSelectors(uint256[] calldata chainIds, uint64[] calldata selectors) external onlyProtocolAdmin {
        if (chainIds.length != selectors.length) {
            revert ExecutorInvalidData();
        }
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (selectors[i] == 0) {
                revert ExecutorInvalidChainSelector(chainIds[i]);
            }
            _ccipChainSelectors[chainIds[i]] = selectors[i];
        }
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function getLayerZeroEid(uint256 chainId) external view override returns (uint32) {
        return _layerZeroEids[chainId];
    }

    /// @notice Sets the LayerZero endpoint id (eid) for a source chainId. Only protocol admin.
    function setLayerZeroEid(uint256 chainId, uint32 eid) external onlyProtocolAdmin {
        if (eid == 0) {
            revert ExecutorInvalidLayerZeroEid(chainId);
        }
        _layerZeroEids[chainId] = eid;
    }

    /// @notice Batch set LayerZero eids. Only protocol admin.
    function setLayerZeroEids(uint256[] calldata chainIds, uint32[] calldata eids) external onlyProtocolAdmin {
        if (chainIds.length != eids.length) {
            revert ExecutorInvalidData();
        }
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (eids[i] == 0) {
                revert ExecutorInvalidLayerZeroEid(chainIds[i]);
            }
            _layerZeroEids[chainIds[i]] = eids[i];
        }
    }

    /// @notice Pauses executor operations.
    function pause() external onlyProtocolAdmin {
        _pause();
    }

    /// @notice Unpauses executor operations.
    function unpause() external onlyProtocolAdmin {
        _unpause();
    }

}
