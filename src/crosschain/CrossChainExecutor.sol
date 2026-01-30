// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";
import {IChainlinkCCIPAdapter} from "../interfaces/IChainlinkCCIPAdapter.sol";
import {ILayerZeroStargateAdapter} from "../interfaces/ILayerZeroStargateAdapter.sol";

/**
 * @title CrossChainExecutor
 * @notice Destination-chain executor that processes cross-chain payment intents and manages refunds.
 * @dev This contract serves as the central coordinator on the destination chain for:
 *      - Receiving and validating intents from bridge adapters (CCIP, LayerZero/Stargate)
 *      - Dispatching approved calls to treasury contracts
 *      - Recording intent states and handling failures gracefully
 *      - Coordinating refund operations back to source chains
 *
 *      The executor implements a soft-failure pattern where validation errors do not revert
 *      but instead mark the intent as Failed, allowing funds to be refunded to the source chain.
 */
contract CrossChainExecutor is ICrossChainExecutor, Ownable, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Bridge identifier for Chainlink CCIP: keccak256("CCIP")
    bytes32 public constant BRIDGE_ID_CCIP = 0x5fa42365004d29017b6e1fff462c90ecf163a6f09987e7af7e4b8c324fc7cc5f;

    /// @notice Bridge identifier for LayerZero: keccak256("LAYERZERO")
    bytes32 public constant BRIDGE_ID_LAYERZERO = 0xe34d309d2a3947d08baad60196a07f69352ed61cce4b781f48c19141173b2894;

    // =============================================================
    //                             STATE
    // =============================================================

    /// @dev Registered bridge adapters by bridge identifier.
    mapping(bytes32 bridgeId => address adapter) private _bridgeAdapters;

    /// @dev Registered IntentSender contracts by source chain ID.
    mapping(uint256 chainId => address sender) private _intentSenders;

    /// @dev CCIP chain selectors mapped from EVM chain IDs.
    mapping(uint256 chainId => uint64 selector) private _ccipChainSelectors;

    /// @dev LayerZero endpoint IDs mapped from EVM chain IDs.
    mapping(uint256 chainId => uint32 eid) private _layerZeroEids;

    /// @dev Intent storage by intent ID.
    mapping(bytes32 intentId => Intent) private _intents;

    /// @dev Allowlisted function selectors per treasury.
    mapping(address treasury => mapping(bytes4 selector => bool allowed)) private _allowedSelectors;

    /// @notice Authorized off-chain agent for executing refunds.
    address public agent;

    /**
     * @notice Validates that caller is the authorized off-chain agent.
     */
    modifier onlyAgent() {
        if (msg.sender != agent) {
            revert ExecutorUnauthorized();
        }
        _;
    }

    /**
     * @notice Initializes the CrossChainExecutor.
     * @param _agent Address of the authorized off-chain agent for refund operations.
     */
    constructor(address _agent) Ownable(msg.sender) {
        agent = _agent;
    }

    /// @inheritdoc ICrossChainExecutor
    function executeIntent(bytes32 bridgeId, Intent memory intent, bytes calldata payload)
        external
        override
        whenNotPaused
    {
        address expectedAdapter = _bridgeAdapters[bridgeId];

        if (msg.sender != expectedAdapter) {
            revert ExecutorAdapterMismatch(bridgeId, msg.sender);
        }

        if (intent.status == Status.Failed) {
            _intents[intent.intentId] = intent;
            return;
        }

        _executeIntent(bridgeId, intent, payload);
    }

    /// @inheritdoc ICrossChainExecutor
    function requestRefund(bytes32 intentId, uint256 amount, address recipient) external override whenNotPaused {
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

    /// @inheritdoc ICrossChainExecutor
    function sendRefundCCIP(bytes32 intentId)
        external
        payable
        override(ICrossChainExecutor)
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        Intent memory intent = _intents[intentId];
        if (intent.status != Status.RefundRequested && intent.status != Status.Failed) {
            revert ExecutorRefundNotAllowed(intentId);
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
            intent.sourceChainId, intent.account, intent.token, intent.amount, msg.sender
        );
        IERC20(intent.token).forceApprove(adapter, 0);

        emit RefundExecuted(intentId, refundId);
    }

    /// @inheritdoc ICrossChainExecutor
    function sendRefundLZStargate(bytes32 intentId, address stargate)
        external
        payable
        override(ICrossChainExecutor)
        whenNotPaused
        onlyAgent
        returns (bytes32 refundId)
    {
        Intent memory intent = _intents[intentId];
        if (intent.status != Status.RefundRequested && intent.status != Status.Failed) {
            revert ExecutorRefundNotAllowed(intentId);
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
            intent.sourceChainId, intent.account, intent.token, intent.amount, stargate, msg.sender
        );
        IERC20(intent.token).forceApprove(adapter, 0);

        emit RefundExecuted(intentId, refundId);
    }

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    /// @inheritdoc ICrossChainExecutor
    function getIntent(bytes32 intentId) external view override returns (Intent memory intent) {
        return _intents[intentId];
    }

    /// @inheritdoc ICrossChainExecutor
    function getIntentSender(uint256 chainId) external view override returns (address) {
        return _intentSenders[chainId];
    }

    /// @inheritdoc ICrossChainExecutor
    function getCcipChainSelector(uint256 chainId) external view override returns (uint64) {
        return _ccipChainSelectors[chainId];
    }

    /// @inheritdoc ICrossChainExecutor
    function getLayerZeroEid(uint256 chainId) external view override returns (uint32) {
        return _layerZeroEids[chainId];
    }

    /**
     * @notice Checks if a function selector is allowlisted for a specific treasury.
     * @param treasury The treasury address to check.
     * @param selector Function selector to check.
     * @return True if the selector is allowed.
     */
    function isSelectorAllowed(address treasury, bytes4 selector) external view returns (bool) {
        return _allowedSelectors[treasury][selector];
    }

    // =============================================================
    //                        ADMIN FUNCTIONS
    // =============================================================

    /**
     * @notice Allowlists or removes function selectors for a specific treasury.
     * @param treasury The treasury address to configure.
     * @param selectors Array of function selectors to configure.
     * @param allowed Whether the selectors should be allowed.
     */
    function setSelectors(address treasury, bytes4[] calldata selectors, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < selectors.length;) {
            _allowedSelectors[treasury][selectors[i]] = allowed;
            emit SelectorAllowed(treasury, selectors[i], allowed);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets the authorized off-chain agent for refund operations.
     * @param newAgent Address of the new agent.
     */
    function setAgent(address newAgent) external onlyOwner {
        if (newAgent == address(0)) {
            revert ExecutorUnauthorized();
        }
        agent = newAgent;
        emit AgentSet(newAgent);
    }

    /**
     * @notice Registers an IntentSender contract for a source chain.
     * @param chainId EVM chain ID of the source chain.
     * @param intentSender Address of the IntentSender contract.
     */
    function setIntentSender(uint256 chainId, address intentSender) external onlyOwner {
        if (intentSender == address(0)) {
            revert ExecutorInvalidSenderConfig(chainId);
        }
        _intentSenders[chainId] = intentSender;
    }

    /**
     * @notice Batch registers bridge adapters for bridge identifiers.
     * @param bridgeIds Array of bridge identifiers (e.g., BRIDGE_ID_CCIP).
     * @param adapters Array of corresponding bridge adapter contract addresses.
     */
    function setBridgeAdapters(bytes32[] calldata bridgeIds, address[] calldata adapters) external onlyOwner {
        if (bridgeIds.length != adapters.length) {
            revert ExecutorInvalidData();
        }
        for (uint256 i = 0; i < bridgeIds.length;) {
            if (adapters[i] == address(0)) {
                revert ExecutorInvalidBridgeAdapter(bridgeIds[i]);
            }
            _bridgeAdapters[bridgeIds[i]] = adapters[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch maps EVM chain IDs to CCIP chain selectors.
     * @param chainIds Array of EVM chain IDs.
     * @param selectors Array of corresponding CCIP chain selectors.
     */
    function setCcipChainSelectors(uint256[] calldata chainIds, uint64[] calldata selectors)
        external
        onlyOwner
    {
        if (chainIds.length != selectors.length) {
            revert ExecutorInvalidData();
        }
        for (uint256 i = 0; i < chainIds.length;) {
            if (selectors[i] == 0) {
                revert ExecutorInvalidChainSelector(chainIds[i]);
            }
            _ccipChainSelectors[chainIds[i]] = selectors[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch maps EVM chain IDs to LayerZero endpoint IDs.
     * @param chainIds Array of EVM chain IDs.
     * @param eids Array of corresponding LayerZero endpoint IDs.
     */
    function setLayerZeroEids(uint256[] calldata chainIds, uint32[] calldata eids) external onlyOwner {
        if (chainIds.length != eids.length) {
            revert ExecutorInvalidData();
        }
        for (uint256 i = 0; i < chainIds.length;) {
            if (eids[i] == 0) {
                revert ExecutorInvalidLayerZeroEid(chainIds[i]);
            }
            _layerZeroEids[chainIds[i]] = eids[i];
            
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Pauses all executor operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses executor operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @dev Executes the intent with soft-failure handling.
     *      Validation failures and call failures result in Failed status rather than reverts,
     *      allowing the funds to be refunded to the source chain.
     */
    function _executeIntent(bytes32 bridgeId, Intent memory intent, bytes calldata payload) internal {
        bytes4 errorSelector;

        if (_intents[intent.intentId].status != Status.None) {
            errorSelector = ExecutorIntentAlreadyProcessed.selector;
        } else if (!_allowedSelectors[intent.treasury][bytes4(payload)]) {
            errorSelector = ExecutorSelectorNotAllowed.selector;
        }

        if (errorSelector != bytes4(0)) {
            intent.status = Status.Failed;
            _intents[intent.intentId] = intent;
            emit IntentFailed(intent.intentId, errorSelector);
            return;
        }

        IERC20(intent.token).forceApprove(intent.treasury, intent.amount);

        (bool success,) = intent.treasury.call(payload);

        IERC20(intent.token).forceApprove(intent.treasury, 0);

        if (!success) {
            intent.status = Status.Failed;
            _intents[intent.intentId] = intent;
            emit IntentFailed(intent.intentId, ExecutorCallFailed.selector);
            return;
        }

        intent.status = Status.Executed;
        _intents[intent.intentId] = intent;

        emit IntentExecuted(bridgeId, intent.intentId, intent.account, intent.token, intent.amount, intent.treasury);
    }
}
