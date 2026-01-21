// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IGlobalParams} from "../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";
import {IChainlinkCCIPAdapter} from "../interfaces/IChainlinkCCIPAdapter.sol";
import {ILayerZeroStargateAdapter} from "../interfaces/ILayerZeroStargateAdapter.sol";

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
    // Source chain configuration
    mapping(uint256 => address) private _intentSenders;
    mapping(uint256 => uint64) private _ccipChainSelectors;
    mapping(uint256 => uint32) private _layerZeroEids;

    mapping(bytes32 => Intent) private _intents;
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
    error ExecutorInsufficientBalance();

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
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     */
    function executeIntent(bytes32 bridgeId, Intent memory intent, bytes calldata payload)
        external
        override
        whenNotPaused
    {
        // Validate caller is a registered adapter first
        address expectedAdapter = _bridgeAdapters[bridgeId];
        if (expectedAdapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(bridgeId);
        }
        if (msg.sender != expectedAdapter) {
            revert ExecutorAdapterMismatch(bridgeId, msg.sender);
        }

        if (_intents[intent.intentId].status != Status.None) {
            revert ExecutorIntentAlreadyProcessed(intent.intentId);
        }
        if (payload.length < 4) {
            revert ExecutorInvalidData();
        }

        bytes4 selector = bytes4(payload);
        if (!allowedTreasurySelectors[intent.treasury][selector]) {
            revert ExecutorSelectorNotAllowed(intent.treasury, selector);
        }

        intent.status = Status.Executed;
        _intents[intent.intentId] = intent;

        IERC20(intent.token).safeTransfer(intent.treasury, intent.amount);

        (bool success, bytes memory returndata) = intent.treasury.call(payload);
        if (!success) {
            revert ExecutorCallFailed(intent.intentId, returndata);
        }

        emit IntentExecuted(bridgeId, intent.intentId, intent.account, intent.token, intent.amount, intent.treasury);
    }

    /**
     * @notice Records a refund request initiated by the treasury.
     * @dev Updates the intent's amount and account for the refund.
     * @param intentId The cross-chain intent ID.
     * @param amount The amount to refund.
     * @param recipient The recipient on the source chain.
     */
    function requestRefund(bytes32 intentId, uint256 amount, address recipient)
        external
        override
        whenNotPaused
    {
        Intent storage storedIntent = _intents[intentId];
        if (storedIntent.status != Status.Executed) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (msg.sender != storedIntent.treasury) {
            revert ExecutorUnauthorized();
        }
        if (recipient == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (amount == 0) {
            revert ExecutorInvalidRefund(intentId);
        }
        if (IERC20(storedIntent.token).balanceOf(address(this)) < amount) {
            revert ExecutorInsufficientBalance();
        }

        storedIntent.status = Status.RefundRequested;
        storedIntent.amount = amount;
        storedIntent.account = recipient;

        emit RefundRequested(intentId, storedIntent.token, amount, recipient);
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function sendRefundCCIP(bytes32 intentId)
        external
        payable
        override(ICrossChainExecutor)
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        Intent memory intent = _intents[intentId];
        if (intent.status != Status.RefundRequested) {
            revert ExecutorRefundNotRequested(intentId);
        }
        if (intent.amount == 0 || intent.account == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }

        address adapter = _bridgeAdapters[BRIDGE_ID_CCIP];
        if (adapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(BRIDGE_ID_CCIP);
        }

        delete _intents[intentId];

        IERC20(intent.token).forceApprove(adapter, intent.amount);
        refundId = IChainlinkCCIPAdapter(adapter).sendRefund{value: msg.value}(
            intent.sourceChainId,
            intent.account,
            intent.token,
            intent.amount,
            msg.sender
        );
        IERC20(intent.token).forceApprove(adapter, 0);

        emit RefundExecuted(intentId, refundId);
    }

    /**
     * @inheritdoc ICrossChainExecutor
     */
    function sendRefundLZStargate(bytes32 intentId, address stargate)
        external
        payable
        override(ICrossChainExecutor)
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        Intent memory intent = _intents[intentId];
        if (intent.status != Status.RefundRequested) {
            revert ExecutorRefundNotRequested(intentId);
        }
        if (intent.amount == 0 || intent.account == address(0)) {
            revert ExecutorInvalidRefund(intentId);
        }

        address adapter = _bridgeAdapters[BRIDGE_ID_LAYERZERO];
        if (adapter == address(0)) {
            revert ExecutorBridgeAdapterNotSet(BRIDGE_ID_LAYERZERO);
        }

        delete _intents[intentId];

        IERC20(intent.token).forceApprove(adapter, intent.amount);
        refundId = ILayerZeroStargateAdapter(adapter).sendRefund{value: msg.value}(
            intent.sourceChainId,
            intent.account,
            intent.token,
            intent.amount,
            stargate,
            msg.sender
        );
        IERC20(intent.token).forceApprove(adapter, 0);

        emit RefundExecuted(intentId, refundId);
    }

    function getIntentStatus(bytes32 intentId) external view override returns (Status status) {
        return _intents[intentId].status;
    }

    function getIntent(bytes32 intentId) external view override returns (Intent memory intent) {
        return _intents[intentId];
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
