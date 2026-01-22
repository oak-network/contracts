// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStargate} from "@stargate-v2/interfaces/IStargate.sol";
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt,
    OFTLimit,
    OFTFeeDetail
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";

/**
 * @title IntentSender
 * @notice Source-chain contract for initiating cross-chain payment intents.
 * @dev Deployed on source chains to send payment intents to the destination chain.
 *      Supports two bridging protocols:
 *      - Chainlink CCIP: For token transfers with arbitrary message passing
 *      - LayerZero Stargate: For OFT-based transfers with compose messages
 *
 *      The contract pulls tokens from the payer's account and bridges them along with
 *      the intent payload to the destination chain adapter.
 */
contract IntentSender is Ownable {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @dev Default gas limit for destination chain execution.
    uint128 internal constant DEFAULT_GAS_AMOUNT = 500_000;

    /// @notice Chainlink CCIP router on this chain.
    IRouterClient public immutable CCIP_ROUTER;

    /// @notice CCIP chain selector for the destination chain.
    uint64 public immutable CCIP_DESTINATION_SELECTOR;

    /// @notice CCIP adapter address on the destination chain.
    address public immutable CCIP_DESTINATION_ADAPTER;

    /// @notice LayerZero endpoint ID for the destination chain.
    uint32 public immutable LZ_DESTINATION_EID;

    /// @notice LayerZero/Stargate adapter address on the destination chain.
    address public immutable LZ_DESTINATION_ADAPTER;

    // =============================================================
    //                             STATE
    // =============================================================

    /// @notice Authorized off-chain agent for submitting intents.
    address public agent;

    /**
     * @notice Parameters for LayerZero/Stargate send operations.
     * @param stargate Stargate pool contract address for the token.
     * @param minAmount Minimum amount to receive on destination after fees.
     * @param gasLimit Gas limit for destination execution (0 uses DEFAULT_GAS_AMOUNT).
     */
    struct LZStargateParams {
        address stargate;
        uint256 minAmount;
        uint128 gasLimit;
    }

    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Intent amount is zero or below minimum.
    error IntentSenderInvalidAmount();

    /// @dev Required address is zero.
    error IntentSenderInvalidReceiver();

    /// @dev Token address is zero.
    error IntentSenderInvalidToken();

    /// @dev Provided native fee is insufficient for the bridge.
    error IntentSenderInsufficientFee();

    /// @dev Failed to refund excess native fee to sender.
    error IntentSenderFeeRefundFailed();

    /// @dev Caller is not the authorized agent.
    error IntentSenderUnauthorized();

    /// @dev Stargate pool does not match the intent token.
    error IntentSenderInvalidStargate();

    /// @dev LayerZero fee token not supported (only native).
    error IntentSenderUnsupportedLzFeeToken();

    /// @dev Quoted received amount is less than minimum.
    error IntentSenderUnexpectedReceivedAmount(uint256 expected, uint256 actual);

    /// @dev Payload is too short (must have function selector).
    error IntentSenderInvalidPayload();

    /// @dev Intent status must be None for new intents.
    error IntentSenderInvalidIntentStatus();

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when the authorized agent is updated.
     * @param agent New agent address.
     */
    event AgentSet(address indexed agent);

    /**
     * @notice Emitted when an intent is sent via Chainlink CCIP.
     * @param messageId CCIP message ID for tracking.
     * @param intentId Unique intent identifier.
     * @param destinationChainSelector CCIP destination chain selector.
     * @param account Payer account that funded the intent.
     * @param token Token being bridged.
     * @param amount Amount being bridged.
     */
    event IntentSentCCIP(
        bytes32 indexed messageId,
        bytes32 indexed intentId,
        uint64 destinationChainSelector,
        address account,
        address token,
        uint256 amount
    );

    /**
     * @notice Emitted when an intent is sent via LayerZero/Stargate.
     * @param guid LayerZero GUID for tracking.
     * @param intentId Unique intent identifier.
     * @param dstEid LayerZero destination endpoint ID.
     * @param account Payer account that funded the intent.
     * @param stargate Stargate pool used for bridging.
     * @param token Token being bridged.
     * @param amountReceivedLD Expected amount to be received on destination.
     */
    event IntentSentLayerZeroStargate(
        bytes32 indexed guid,
        bytes32 indexed intentId,
        uint32 dstEid,
        address account,
        address stargate,
        address token,
        uint256 amountReceivedLD
    );

    /**
     * @notice Validates that caller is the authorized off-chain agent.
     */
    modifier onlyAgent() {
        if (msg.sender != agent) {
            revert IntentSenderUnauthorized();
        }
        _;
    }

    /**
     * @notice Deploys a new IntentSender contract.
     * @param _agent Initial authorized agent address.
     * @param ccipRouter Chainlink CCIP router address on this chain.
     * @param ccipDestinationSelector CCIP chain selector for the destination.
     * @param ccipDestinationAdapter CCIP adapter address on the destination chain.
     * @param lzDestinationEid LayerZero endpoint ID for the destination.
     * @param lzDestinationAdapter LayerZero/Stargate adapter address on the destination chain.
     */
    constructor(
        address _agent,
        address ccipRouter,
        uint64 ccipDestinationSelector,
        address ccipDestinationAdapter,
        uint32 lzDestinationEid,
        address lzDestinationAdapter
    ) Ownable(msg.sender) {
        agent = _agent;
        CCIP_ROUTER = IRouterClient(ccipRouter);
        CCIP_DESTINATION_SELECTOR = ccipDestinationSelector;
        CCIP_DESTINATION_ADAPTER = ccipDestinationAdapter;
        LZ_DESTINATION_EID = lzDestinationEid;
        LZ_DESTINATION_ADAPTER = lzDestinationAdapter;
    }

    // =============================================================
    //                        ADMIN FUNCTIONS
    // =============================================================

    /**
     * @notice Updates the authorized agent address.
     * @param newAgent New agent address (cannot be zero).
     */
    function setAgent(address newAgent) external onlyOwner {
        if (newAgent == address(0)) {
            revert IntentSenderInvalidReceiver();
        }
        agent = newAgent;
        emit AgentSet(newAgent);
    }

    // =============================================================
    //                          QUOTE FEES
    // =============================================================

    /**
     * @notice Quotes the native fee required to send an intent via CCIP.
     * @param intent The intent to send (will be validated).
     * @param payload ABI-encoded treasury calldata.
     * @param gasLimit Destination gas limit (0 uses default 500,000).
     * @return ccipFee Native fee required by CCIP.
     */
    function quoteFeeCCIP(ICrossChainExecutor.Intent memory intent, bytes calldata payload, uint256 gasLimit)
        external
        view
        returns (uint256 ccipFee)
    {
        _sanitizeIntent(intent, payload);
        gasLimit = gasLimit == 0 ? uint256(DEFAULT_GAS_AMOUNT) : gasLimit;
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPIntentMessage(intent, payload, gasLimit);
        ccipFee = CCIP_ROUTER.getFee(CCIP_DESTINATION_SELECTOR, ccipMessage);
    }

    /**
     * @notice Quotes the native fee required to send an intent via LayerZero/Stargate.
     * @param params Stargate send parameters.
     * @param intent The intent to send (will be validated).
     * @param payload ABI-encoded treasury calldata.
     * @return nativeFee Native fee required by LayerZero.
     */
    function quoteFeeLZStargate(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    ) external view returns (uint256 nativeFee) {
        _sanitizeIntent(intent, payload);
        MessagingFee memory lzFee =
            IStargate(params.stargate).quoteSend(_buildStargateSendParam(params, intent, payload), false);
        return lzFee.nativeFee;
    }

    /**
     * @notice Quotes the OFT transfer details for a LayerZero/Stargate send.
     * @param params Stargate send parameters.
     * @param intent The intent to send (will be validated).
     * @param payload ABI-encoded treasury calldata.
     * @return limit OFT transfer limits for the route.
     * @return feeDetails Breakdown of OFT fees.
     * @return receipt Quote containing amountSentLD and amountReceivedLD.
     */
    function quoteLayerZeroStargateOFT(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    ) external view returns (OFTLimit memory limit, OFTFeeDetail[] memory feeDetails, OFTReceipt memory receipt) {
        _sanitizeIntent(intent, payload);
        return IStargate(params.stargate).quoteOFT(_buildStargateSendParam(params, intent, payload));
    }

    // =============================================================
    //                         SEND INTENT
    // =============================================================

    /**
     * @notice Sends a cross-chain payment intent via Chainlink CCIP.
     * @dev Pulls tokens from `intent.account` and bridges them with the intent payload.
     *      Excess native fee is refunded to the caller.
     * @param intent The intent to send (status must be None).
     * @param payload ABI-encoded calldata for the treasury function.
     * @param gasLimit Destination gas limit (0 uses default 500,000).
     * @return messageId CCIP message ID for tracking.
     */
    function sendIntentCCIP(ICrossChainExecutor.Intent memory intent, bytes calldata payload, uint256 gasLimit)
        external
        payable
        onlyAgent
        returns (bytes32 messageId)
    {
        _sanitizeIntent(intent, payload);

        gasLimit = gasLimit == 0 ? uint256(DEFAULT_GAS_AMOUNT) : gasLimit;
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPIntentMessage(intent, payload, gasLimit);

        uint256 ccipFee = CCIP_ROUTER.getFee(CCIP_DESTINATION_SELECTOR, ccipMessage);
        if (msg.value < ccipFee) {
            revert IntentSenderInsufficientFee();
        }

        IERC20(intent.token).safeTransferFrom(intent.account, address(this), intent.amount);
        IERC20(intent.token).forceApprove(address(CCIP_ROUTER), intent.amount);

        messageId = CCIP_ROUTER.ccipSend{value: ccipFee}(CCIP_DESTINATION_SELECTOR, ccipMessage);
        IERC20(intent.token).forceApprove(address(CCIP_ROUTER), 0);

        if (msg.value > ccipFee) {
            (bool success,) = msg.sender.call{value: msg.value - ccipFee}("");
            if (!success) {
                revert IntentSenderFeeRefundFailed();
            }
        }

        emit IntentSentCCIP(
            messageId, intent.intentId, CCIP_DESTINATION_SELECTOR, intent.account, intent.token, intent.amount
        );
    }

    /**
     * @notice Sends a cross-chain payment intent via LayerZero/Stargate.
     * @dev Pulls tokens from `intent.account` and bridges them using Stargate's OFT mechanism.
     *      Excess native fee is handled by Stargate and refunded to the caller.
     * @param params Stargate send parameters including pool address and slippage.
     * @param intent The intent to send (status must be None).
     * @param payload ABI-encoded calldata for the treasury function.
     * @return guid LayerZero GUID for tracking.
     */
    function sendIntentLZStargate(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    ) external payable onlyAgent returns (bytes32 guid) {
        _sanitizeIntent(intent, payload);

        if (params.minAmount > intent.amount) {
            revert IntentSenderInvalidAmount();
        }

        if (IStargate(params.stargate).token() != intent.token) {
            revert IntentSenderInvalidStargate();
        }

        SendParam memory sendParam = _buildStargateSendParam(params, intent, payload);

        uint256 amountReceivedLD;
        {
            (,, OFTReceipt memory receipt) = IStargate(params.stargate).quoteOFT(sendParam);
            amountReceivedLD = receipt.amountReceivedLD;
        }
        if (amountReceivedLD < params.minAmount) {
            revert IntentSenderUnexpectedReceivedAmount(params.minAmount, amountReceivedLD);
        }

        MessagingFee memory lzFee = IStargate(params.stargate).quoteSend(sendParam, false);
        if (msg.value < lzFee.nativeFee) {
            revert IntentSenderInsufficientFee();
        }

        IERC20(intent.token).safeTransferFrom(intent.account, address(this), intent.amount);
        IERC20(intent.token).forceApprove(params.stargate, intent.amount);

        (MessagingReceipt memory msgReceipt,) = IStargate(params.stargate).send{value: msg.value}(
            sendParam, MessagingFee({nativeFee: msg.value, lzTokenFee: 0}), payable(msg.sender)
        );

        IERC20(intent.token).forceApprove(params.stargate, 0);

        guid = msgReceipt.guid;
        emit IntentSentLayerZeroStargate(
            guid, intent.intentId, LZ_DESTINATION_EID, intent.account, params.stargate, intent.token, amountReceivedLD
        );
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @dev Validates and initializes intent fields before sending.
     *      Sets sourceChainId to current chain and status to Ongoing.
     */
    function _sanitizeIntent(ICrossChainExecutor.Intent memory intent, bytes calldata payload) internal view {
        if (intent.status != ICrossChainExecutor.Status.None) {
            revert IntentSenderInvalidIntentStatus();
        }
        if (intent.amount == 0) {
            revert IntentSenderInvalidAmount();
        }
        if (intent.treasury == address(0)) {
            revert IntentSenderInvalidReceiver();
        }
        if (intent.account == address(0)) {
            revert IntentSenderInvalidReceiver();
        }
        if (intent.token == address(0)) {
            revert IntentSenderInvalidToken();
        }
        if (payload.length < 4) {
            revert IntentSenderInvalidPayload();
        }

        intent.sourceChainId = block.chainid;
        intent.status = ICrossChainExecutor.Status.Ongoing;
    }

    /**
     * @dev Constructs a CCIP message for the intent with token transfer.
     */
    function _buildCCIPIntentMessage(ICrossChainExecutor.Intent memory intent, bytes calldata payload, uint256 gasLimit)
        internal
        view
        returns (Client.EVM2AnyMessage memory)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: intent.token, amount: intent.amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(CCIP_DESTINATION_ADAPTER),
            data: abi.encode(intent, payload),
            tokenAmounts: tokenAmounts,
            feeToken: address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: true}))
        });
    }

    /**
     * @dev Constructs Stargate SendParam with compose message for the intent.
     */
    function _buildStargateSendParam(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    ) internal view returns (SendParam memory) {
        uint128 gas = params.gasLimit == 0 ? DEFAULT_GAS_AMOUNT : params.gasLimit;
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, gas, 0);
        bytes memory composeMsg =
            abi.encodePacked(bytes32(uint256(uint160(address(this)))), abi.encode(intent, payload));
        return SendParam({
            dstEid: LZ_DESTINATION_EID,
            to: bytes32(uint256(uint160(LZ_DESTINATION_ADAPTER))),
            amountLD: intent.amount,
            minAmountLD: params.minAmount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });
    }
}
