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
 * @notice Source-chain sender for cross-chain payment intents.
 * @dev Pulls tokens from the account and forwards intents to Ethereum via CCIP or LayerZero/Stargate.
 */
contract IntentSender is Ownable {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    uint128 internal constant DEFAULT_GAS_AMOUNT = 500_000;

    /**
     * @notice LayerZero/Stargate send parameters.
     * @param stargate Stargate contract address.
     * @param minAmount Minimum amount to receive on destination.
     * @param gasLimit Gas limit to use on destination (0 => default 500_000).
     */
    struct LZStargateParams {
        address stargate;
        uint256 minAmount;
        uint128 gasLimit;
    }

    IRouterClient public immutable CCIP_ROUTER;
    uint64 public immutable CCIP_DESTINATION_SELECTOR;
    address public immutable CCIP_DESTINATION_ADAPTER;

    uint32 public immutable LZ_DESTINATION_EID;
    address public immutable LZ_DESTINATION_ADAPTER;

    address public agent;

    // =============================================================
    //                             ERRORS
    // =============================================================

    error IntentSenderInvalidAmount();
    error IntentSenderInvalidReceiver();
    error IntentSenderInvalidToken();
    error IntentSenderInsufficientFee();
    error IntentSenderFeeRefundFailed();
    error IntentSenderUnauthorized();
    error IntentSenderInvalidStargate();
    error IntentSenderUnsupportedLzFeeToken();
    error IntentSenderUnexpectedReceivedAmount(uint256 expected, uint256 actual);
    error IntentSenderInvalidPayload();
    error IntentSenderInvalidIntentStatus();

    // =============================================================
    //                             EVENTS
    // =============================================================

    event AgentSet(address indexed agent);
    event IntentSentCCIP(
        bytes32 indexed messageId,
        bytes32 indexed intentId,
        uint64 destinationChainSelector,
        address account,
        address token,
        uint256 amount
    );
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
     * @notice Modifier to ensure the caller is the authorized agent.
     */
    modifier onlyAgent() {
        if (msg.sender != agent) {
            revert IntentSenderUnauthorized();
        }
        _;
    }

    /**
     * @notice Creates a new IntentSender.
     * @param _agent The off-chain agent address.
     * @param ccipRouter Chainlink CCIP router address on the source chain.
     * @param ccipDestinationSelector Destination chain selector (destination is Ethereum).
     * @param ccipDestinationAdapter Destination-chain CCIP adapter address (on Ethereum).
     * @param lzDestinationEid LayerZero destination endpoint id (destination is Ethereum).
     * @param lzDestinationAdapter Destination-chain LayerZero/Stargate adapter address (on Ethereum).
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

    /**
     * @notice Sets the single authorized agent.
     * @param newAgent The agent address allowed to submit intents.
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
     * @notice Quotes the CCIP fee for a given intent.
     * @param intent The cross-chain intent to send.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     * @param gasLimit Gas limit to use on destination (0 => default 500_000).
     * @return ccipFee The native fee required by CCIP.
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
     * @notice Quotes the LayerZero messaging fee for Stargate.
     * @param params Stargate parameters.
     * @param intent The cross-chain intent to send.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     * @return nativeFee The native fee required.
     */
    function quoteFeeLayerZeroStargate(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    )
        external
        view
        returns (uint256 nativeFee)
    {
        _sanitizeIntent(intent, payload);
        MessagingFee memory lzFee =
            IStargate(params.stargate).quoteSend(_buildStargateSendParam(params, intent, payload), false);
        return lzFee.nativeFee;
    }

    /**
     * @notice Quotes the delivered amount for a LayerZero/Stargate send.
     * @param params Stargate parameters.
     * @param intent The cross-chain intent to send.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     * @return limit OFT limits for the route.
     * @return feeDetails OFT fee breakdown.
     * @return receipt Quote containing amountSentLD and amountReceivedLD.
     */
    function quoteLayerZeroStargateOFT(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    )
        external
        view
        returns (OFTLimit memory limit, OFTFeeDetail[] memory feeDetails, OFTReceipt memory receipt)
    {
        _sanitizeIntent(intent, payload);
        return IStargate(params.stargate).quoteOFT(_buildStargateSendParam(params, intent, payload));
    }

    // =============================================================
    //                          SEND INTENT
    // =============================================================

    /**
     * @notice Sends a cross-chain intent via CCIP.
     * @dev Pulls `intent.amount` of `intent.token` from `intent.account`.
     * @param intent The cross-chain intent to send.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     * @param gasLimit Gas limit to use on destination (0 => default 500_000).
     * @return messageId The CCIP message ID.
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
            messageId,
            intent.intentId,
            CCIP_DESTINATION_SELECTOR,
            intent.account,
            intent.token,
            intent.amount
        );
    }

    /**
     * @notice Sends a cross-chain intent via LayerZero/Stargate.
     * @dev Pulls `intent.amount` of `intent.token` from `intent.account`.
     * @param params Stargate parameters.
     * @param intent The cross-chain intent to send.
     * @param payload ABI-encoded calldata for the treasury entrypoint.
     * @return guid The LayerZero GUID for tracking.
     */
    function sendIntentLZStargate(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    )
        external
        payable
        onlyAgent
        returns (bytes32 guid)
    {
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
            (, , OFTReceipt memory receipt) = IStargate(params.stargate).quoteOFT(sendParam);
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
            sendParam,
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            payable(msg.sender)
        );

        IERC20(intent.token).forceApprove(params.stargate, 0);

        guid = msgReceipt.guid;
        emit IntentSentLayerZeroStargate(
            guid,
            intent.intentId,
            LZ_DESTINATION_EID,
            intent.account,
            params.stargate,
            intent.token,
            amountReceivedLD
        );
    }

    // =============================================================
    //                       INTERNAL HELPERS
    // =============================================================

    /**
     * @dev Validates intent fields, sets sourceChainId and status.
     * @dev Reverts if status is not None, amount is zero, required addresses are zero, or payload is empty.
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
     * @dev Builds a CCIP message for the intent, including token transfer and destination gas limit.
     */
    function _buildCCIPIntentMessage(
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload,
        uint256 gasLimit
    )
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
     * @dev Builds Stargate SendParam for delivery to the destination adapter using compose.
     */
    function _buildStargateSendParam(
        LZStargateParams calldata params,
        ICrossChainExecutor.Intent memory intent,
        bytes calldata payload
    )
        internal
        view
        returns (SendParam memory)
    {
        uint128 gas = params.gasLimit == 0 ? DEFAULT_GAS_AMOUNT : params.gasLimit;
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, gas, 0);
        bytes memory composeMsg = abi.encodePacked(
            bytes32(uint256(uint160(address(this)))),
            abi.encode(intent, payload)
        );
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
