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

import {ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";

/**
 * @title IntentSender
 * @notice Source-chain sender for cross-chain payment intents (agent-only).
 * @dev Pulls tokens from the backer and forwards intents to Ethereum via CCIP or LayerZero/Stargate.
 */
contract IntentSender is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice LayerZero/Stargate send parameters for source-chain delivery.
     */
    struct LzStargateSendParams {
        address stargate;
        address sourceToken;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
    }

    IRouterClient public immutable CCIP_ROUTER;
    uint64 public immutable CCIP_DESTINATION_SELECTOR;
    address public immutable CCIP_DESTINATION_ADAPTER;

    uint32 public immutable LZ_DESTINATION_EID;
    address public immutable LZ_DESTINATION_ADAPTER;

    address public agent;

    error IntentSenderInvalidAmount();
    error IntentSenderInvalidReceiver();
    error IntentSenderInvalidToken();
    error IntentSenderIntentExpired();
    error IntentSenderInsufficientFee();
    error IntentSenderFeeRefundFailed();
    error IntentSenderUnauthorized();
    error IntentSenderInvalidStargate();
    error IntentSenderUnsupportedLzFeeToken();
    error IntentSenderUnexpectedReceivedAmount(uint256 expected, uint256 actual);

    event AgentSet(address indexed agent);
    event IntentSentCCIP(
        bytes32 indexed messageId,
        bytes32 indexed intentId,
        uint64 destinationChainSelector,
        address sender,
        address sourceToken,
        address destinationToken,
        uint256 amount
    );
    event IntentSentLayerZeroStargate(
        bytes32 indexed guid,
        bytes32 indexed intentId,
        uint32 dstEid,
        address sender,
        address stargate,
        address sourceToken,
        address destinationToken,
        uint256 amountReceivedLD
    );

    modifier onlyAgent() {
        if (msg.sender != agent) {
            revert IntentSenderUnauthorized();
        }
        _;
    }

    constructor(
        address ccipRouter,
        uint64 ccipDestinationSelector,
        address ccipDestinationAdapter,
        uint32 lzDestinationEid,
        address lzDestinationAdapter
    ) Ownable(msg.sender) {
        CCIP_ROUTER = IRouterClient(ccipRouter);
        CCIP_DESTINATION_SELECTOR = ccipDestinationSelector;
        CCIP_DESTINATION_ADAPTER = ccipDestinationAdapter;
        LZ_DESTINATION_EID = lzDestinationEid;
        LZ_DESTINATION_ADAPTER = lzDestinationAdapter;
    }

    /// @notice Sets the single authorized agent.
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

    /**
     * @notice Quotes the CCIP fee for a given intent.
     * @param intent The cross-chain intent to send.
     * @return fee The native fee required by CCIP.
     */
    function quoteFeeCCIP(ICrossChainExecutor.CrossChainIntent memory intent) external view returns (uint256 fee) {
        _sanitizeIntent(intent);
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPIntentMessage(intent);
        fee = CCIP_ROUTER.getFee(CCIP_DESTINATION_SELECTOR, ccipMessage);
    }

    /**
     * @notice Sends a cross-chain intent via CCIP.
     * @param intent The cross-chain intent to send.
     * @return messageId The CCIP message ID.
     */
    function sendIntentCCIP(ICrossChainExecutor.CrossChainIntent memory intent)
        external
        payable
        onlyAgent
        returns (bytes32 messageId)
    {
        _sanitizeIntent(intent);

        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPIntentMessage(intent);
        uint256 fee = CCIP_ROUTER.getFee(CCIP_DESTINATION_SELECTOR, ccipMessage);
        if (msg.value < fee) {
            revert IntentSenderInsufficientFee();
        }

        IERC20(intent.sourceToken).safeTransferFrom(intent.sender, address(this), intent.amount);
        IERC20(intent.sourceToken).forceApprove(address(CCIP_ROUTER), intent.amount);

        messageId = CCIP_ROUTER.ccipSend{value: fee}(CCIP_DESTINATION_SELECTOR, ccipMessage);
        IERC20(intent.sourceToken).forceApprove(address(CCIP_ROUTER), 0);

        if (msg.value > fee) {
            (bool success,) = msg.sender.call{value: msg.value - fee}("");
            if (!success) {
                revert IntentSenderFeeRefundFailed();
            }
        }

        emit IntentSentCCIP(
            messageId,
            intent.intentId,
            CCIP_DESTINATION_SELECTOR,
            intent.sender,
            intent.sourceToken,
            intent.destinationToken,
            intent.amount
        );
    }

    /**
     * @notice Quotes the LayerZero messaging fee for Stargate.
     * @param p Stargate parameters.
     * @param payInLzToken Whether to pay fees in LZ token (unsupported).
     * @return nativeFee The native fee required.
     */
    function quoteFeeLayerZeroStargate(LzStargateSendParams calldata p, bool payInLzToken)
        external
        view
        returns (uint256 nativeFee)
    {
        MessagingFee memory fee = IStargate(p.stargate).quoteSend(_buildStargateSendParam(p, bytes("")), payInLzToken);
        return fee.nativeFee;
    }

    /**
     * @notice Quotes the delivered amount for a LayerZero/Stargate send.
     * @param p Stargate parameters.
     */
    function quoteLayerZeroStargateOFT(LzStargateSendParams calldata p)
        external
        view
        returns (OFTLimit memory limit, OFTFeeDetail[] memory feeDetails, OFTReceipt memory receipt)
    {
        return IStargate(p.stargate).quoteOFT(_buildStargateSendParam(p, bytes("")));
    }

    /**
     * @notice Sends a cross-chain intent via LayerZero/Stargate.
     * @param p Stargate parameters.
     * @param intent The cross-chain intent to send.
     * @return guid The LayerZero GUID for tracking.
     */
    function sendIntentLayerZeroStargate(LzStargateSendParams calldata p, ICrossChainExecutor.CrossChainIntent memory intent)
        external
        payable
        onlyAgent
        returns (bytes32 guid)
    {
        _sanitizeIntent(intent);

        if (IStargate(p.stargate).token() != p.sourceToken || p.sourceToken != intent.sourceToken) {
            revert IntentSenderInvalidStargate();
        }

        bytes memory composeMsg = abi.encodePacked(bytes32(uint256(uint160(address(this)))), abi.encode(intent));
        SendParam memory sendParam = _buildStargateSendParam(p, composeMsg);

        uint256 amountReceivedLD;
        {
            (, , OFTReceipt memory receipt) = IStargate(p.stargate).quoteOFT(sendParam);
            amountReceivedLD = receipt.amountReceivedLD;
        }
        if (amountReceivedLD != intent.amount) {
            revert IntentSenderUnexpectedReceivedAmount(intent.amount, amountReceivedLD);
        }

        MessagingFee memory fee = IStargate(p.stargate).quoteSend(sendParam, false);
        if (fee.lzTokenFee != 0) {
            revert IntentSenderUnsupportedLzFeeToken();
        }
        if (msg.value < fee.nativeFee) {
            revert IntentSenderInsufficientFee();
        }

        IERC20(p.sourceToken).safeTransferFrom(intent.sender, address(this), p.amountLD);
        IERC20(p.sourceToken).forceApprove(p.stargate, p.amountLD);

        (MessagingReceipt memory msgReceipt,) = IStargate(p.stargate).send{value: msg.value}(
            sendParam,
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            payable(msg.sender)
        );

        IERC20(p.sourceToken).forceApprove(p.stargate, 0);

        guid = msgReceipt.guid;
        emit IntentSentLayerZeroStargate(
            guid,
            intent.intentId,
            LZ_DESTINATION_EID,
            intent.sender,
            p.stargate,
            p.sourceToken,
            intent.destinationToken,
            amountReceivedLD
        );
    }

    function _sanitizeIntent(ICrossChainExecutor.CrossChainIntent memory intent) internal view {
        if (intent.amount == 0) {
            revert IntentSenderInvalidAmount();
        }
        if (intent.treasury == address(0)) {
            revert IntentSenderInvalidReceiver();
        }
        if (intent.sender == address(0)) {
            revert IntentSenderInvalidReceiver();
        }
        if (intent.sourceToken == address(0) || intent.destinationToken == address(0)) {
            revert IntentSenderInvalidToken();
        }
        if (block.timestamp >= intent.deadline) {
            revert IntentSenderIntentExpired();
        }

        intent.sourceChainId = block.chainid;
    }

    function _buildCCIPIntentMessage(ICrossChainExecutor.CrossChainIntent memory intent)
        internal
        view
        returns (Client.EVM2AnyMessage memory)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: intent.sourceToken, amount: intent.amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(CCIP_DESTINATION_ADAPTER),
            data: abi.encode(intent),
            tokenAmounts: tokenAmounts,
            feeToken: address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: true}))
        });
    }

    function _buildStargateSendParam(LzStargateSendParams calldata p, bytes memory composeMsg)
        internal
        view
        returns (SendParam memory)
    {
        return SendParam({
            dstEid: LZ_DESTINATION_EID,
            to: bytes32(uint256(uint160(LZ_DESTINATION_ADAPTER))),
            amountLD: p.amountLD,
            minAmountLD: p.minAmountLD,
            extraOptions: p.extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });
    }

    receive() external payable {}
}
