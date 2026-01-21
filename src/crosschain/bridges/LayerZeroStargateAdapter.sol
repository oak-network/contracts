// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IStargate} from "@stargate-v2/interfaces/IStargate.sol";
import {
    SendParam,
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {IGlobalParams} from "../../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../../interfaces/ICrossChainExecutor.sol";
import {ILayerZeroStargateAdapter} from "../../interfaces/ILayerZeroStargateAdapter.sol";

/**
 * @title LayerZeroStargateAdapter
 * @notice Destination-chain adapter for receiving cross-chain intents via LayerZero Stargate.
 * @dev This adapter implements ILayerZeroComposer to receive OFT transfers with compose messages
 *      from Stargate v2. It handles:
 *      - Receiving and validating incoming compose messages containing payment intents
 *      - Forwarding validated intents to the CrossChainExecutor
 *      - Sending refunds back to source chains via Stargate
 *
 *      The adapter implements soft-failure validation: invalid intents are marked as Failed
 *      rather than reverting, allowing funds to be held for refund processing.
 */
contract LayerZeroStargateAdapter is ILayerZeroComposer, ILayerZeroStargateAdapter {
    using SafeERC20 for IERC20;

    /// @notice Bridge identifier: keccak256("LAYERZERO")
    bytes32 public constant BRIDGE_ID = 0xe34d309d2a3947d08baad60196a07f69352ed61cce4b781f48c19141173b2894;

    /// @notice LayerZero endpoint contract on this chain.
    ILayerZeroEndpointV2 public immutable ENDPOINT;

    /// @notice Global parameters contract for protocol configuration.
    IGlobalParams public immutable GLOBAL_PARAMS;

    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Caller is not authorized for this operation.
    error LayerZeroStargateAdapterUnauthorized();

    /// @dev Compose message sender does not match the registered IntentSender for the source chain.
    error LayerZeroStargateAdapterInvalidPeer();

    /// @dev Intent status is not Ongoing (soft failure).
    error LayerZeroStargateAdapterInvalidIntentStatus();

    /// @dev LayerZero endpoint ID does not match the expected ID for the source chain (soft failure).
    error LayerZeroStargateAdapterEidMismatch();

    /// @dev Stargate pool is not configured or does not match the token.
    error LayerZeroStargateAdapterTokenNotConfigured();

    /// @dev No LayerZero endpoint ID configured for the destination chain.
    error LayerZeroStargateAdapterUnknownDestinationChainId();

    /// @dev CrossChainExecutor is not configured in GlobalParams.
    error LayerZeroStargateAdapterExecutorNotSet();

    /// @dev Provided native fee is insufficient for the LayerZero operation.
    error LayerZeroStargateAdapterInsufficientFee(uint256 required, uint256 provided);

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when an intent is received and processed via lzCompose.
     * @param guid LayerZero GUID of the incoming message.
     * @param srcEid Source chain's LayerZero endpoint ID.
     * @param intentId Unique intent identifier.
     * @param amount Token amount received.
     */
    event IntentComposed(bytes32 indexed guid, uint32 indexed srcEid, bytes32 indexed intentId, uint256 amount);

    /**
     * @notice Emitted when a refund is sent via Stargate.
     * @param guid LayerZero GUID for tracking.
     * @param destinationChainId EVM chain ID of the refund destination.
     * @param recipient Address receiving the refund on the destination chain.
     * @param token Token being refunded.
     * @param amount Amount of tokens refunded.
     */
    event RefundSent(
        bytes32 indexed guid, uint256 destinationChainId, address recipient, address token, uint256 amount
    );

    /**
     * @notice Deploys a new LayerZeroStargateAdapter.
     * @param endpoint LayerZero endpoint address on this chain.
     * @param globalParams Global parameters contract address.
     */
    constructor(address endpoint, IGlobalParams globalParams) {
        ENDPOINT = ILayerZeroEndpointV2(endpoint);
        GLOBAL_PARAMS = globalParams;
    }

    /**
     * @notice LayerZero compose callback for receiving Stargate OFT transfers.
     * @dev Called by the LayerZero endpoint after a Stargate transfer with a compose message.
     *      Validates the message provenance and forwards the intent to the executor.
     * @param from The Stargate pool contract that initiated the compose.
     * @param guid LayerZero GUID of the message.
     * @param message The compose message containing the encoded intent and payload.
     */
    function lzCompose(address from, bytes32 guid, bytes calldata message, address, bytes calldata)
        external
        payable
        override
    {
        if (msg.sender != address(ENDPOINT)) {
            revert LayerZeroStargateAdapterUnauthorized();
        }

        uint32 srcEid = OFTComposeMsgCodec.srcEid(message);
        bytes32 composeFrom = OFTComposeMsgCodec.composeFrom(message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(message);

        bytes memory inner = OFTComposeMsgCodec.composeMsg(message);
        (ICrossChainExecutor.Intent memory intent, bytes memory payload) =
            abi.decode(inner, (ICrossChainExecutor.Intent, bytes));

        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        address expectedSender = ICrossChainExecutor(executor).getIntentSender(intent.sourceChainId);
        bytes32 expectedPeer = bytes32(uint256(uint160(expectedSender)));

        if (expectedPeer != composeFrom) {
            revert LayerZeroStargateAdapterInvalidPeer();
        }

        bytes4 errorSelector;

        if (intent.status != ICrossChainExecutor.Status.Ongoing) {
            errorSelector = LayerZeroStargateAdapterInvalidIntentStatus.selector;
        } else if (ICrossChainExecutor(executor).getLayerZeroEid(intent.sourceChainId) != srcEid) {
            errorSelector = LayerZeroStargateAdapterEidMismatch.selector;
        }

        address receivedToken = IStargate(from).token();

        intent.token = receivedToken;
        intent.amount = amountLD;

        if (errorSelector != bytes4(0)) {
            intent.status = ICrossChainExecutor.Status.Failed;
            emit ICrossChainExecutor.IntentFailed(intent.intentId, errorSelector);
        }

        IERC20(receivedToken).safeTransfer(executor, amountLD);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent, payload);

        emit IntentComposed(guid, srcEid, intent.intentId, amountLD);
    }

    /// @inheritdoc ILayerZeroStargateAdapter
    function quoteRefundFee(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate
    ) external view override returns (uint256 fee) {
        if (stargate == address(0) || IStargate(stargate).token() != token) {
            revert LayerZeroStargateAdapterTokenNotConfigured();
        }
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        if (executor == address(0)) {
            revert LayerZeroStargateAdapterExecutorNotSet();
        }
        uint32 dstEid = ICrossChainExecutor(executor).getLayerZeroEid(destinationChainId);
        if (dstEid == 0) {
            revert LayerZeroStargateAdapterUnknownDestinationChainId();
        }

        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: amount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory mfee = IStargate(stargate).quoteSend(sendParam, false);
        return mfee.nativeFee;
    }

    /// @inheritdoc ILayerZeroStargateAdapter
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate,
        address feeRefundRecipient
    ) external payable override returns (bytes32 refundId) {
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        if (executor == address(0) || msg.sender != executor) {
            revert LayerZeroStargateAdapterUnauthorized();
        }

        if (stargate == address(0) || IStargate(stargate).token() != token) {
            revert LayerZeroStargateAdapterTokenNotConfigured();
        }
        uint32 dstEid = ICrossChainExecutor(executor).getLayerZeroEid(destinationChainId);
        if (dstEid == 0) {
            revert LayerZeroStargateAdapterUnknownDestinationChainId();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).forceApprove(stargate, amount);

        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: amount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory requiredFee = IStargate(stargate).quoteSend(sendParam, false);
        if (msg.value < requiredFee.nativeFee) {
            revert LayerZeroStargateAdapterInsufficientFee(requiredFee.nativeFee, msg.value);
        }

        (MessagingReceipt memory msgReceipt,) = IStargate(stargate).send{value: msg.value}(
            sendParam, MessagingFee({nativeFee: msg.value, lzTokenFee: 0}), payable(feeRefundRecipient)
        );

        IERC20(token).forceApprove(stargate, 0);

        refundId = msgReceipt.guid;
        emit RefundSent(refundId, destinationChainId, recipient, token, amount);
    }
}
