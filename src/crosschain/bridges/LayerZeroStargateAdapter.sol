// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IStargate} from "@stargate-v2/interfaces/IStargate.sol";
import {SendParam, MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {IGlobalParams} from "../../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../../interfaces/ICrossChainExecutor.sol";
import {ILayerZeroStargateAdapter} from "../../interfaces/ILayerZeroStargateAdapter.sol";

/**
 * @title LayerZeroStargateAdapter
 * @notice Destination-chain adapter for LayerZero v2 + Stargate v2 delivery and refunds.
 */
contract LayerZeroStargateAdapter is ILayerZeroComposer, ILayerZeroStargateAdapter {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_ID = keccak256("LAYERZERO");

    ILayerZeroEndpointV2 public immutable ENDPOINT;
    IGlobalParams public immutable GLOBAL_PARAMS;

    // Hard revert errors (authentication/critical)
    error LayerZeroStargateAdapterUnauthorized();
    error LayerZeroStargateAdapterInvalidPeer();

    // Soft failure errors (simplified, no params)
    error LayerZeroStargateAdapterInvalidIntentStatus();
    error LayerZeroStargateAdapterEidMismatch();

    // Refund-related errors
    error LayerZeroStargateAdapterTokenNotConfigured();
    error LayerZeroStargateAdapterUnknownDestinationChainId();
    error LayerZeroStargateAdapterExecutorNotSet();
    error LayerZeroStargateAdapterInsufficientFee(uint256 required, uint256 provided);

    event IntentComposed(bytes32 indexed guid, uint32 indexed srcEid, bytes32 indexed intentId, uint256 amount);
    event RefundSent(bytes32 indexed guid, uint256 destinationChainId, address recipient, address token, uint256 amount);
    event IntentFailed(bytes32 indexed intentId, bytes4 errorSelector);

    constructor(address endpoint, IGlobalParams globalParams) {
        ENDPOINT = ILayerZeroEndpointV2(endpoint);
        GLOBAL_PARAMS = globalParams;
    }

    /**
     * @notice LayerZero compose entrypoint. Validates provenance, updates intent token/amount, and dispatches intent.
     */
    function lzCompose(
        address from,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) external payable override {
        // Validate endpoint and peer - revert on failure
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
        
        // Soft failure validations - use errorSelector pattern
        bytes4 errorSelector;

        // Validate intent status is Ongoing
        if (intent.status != ICrossChainExecutor.Status.Ongoing) {
            errorSelector = LayerZeroStargateAdapterInvalidIntentStatus.selector;
        } else if (ICrossChainExecutor(executor).getLayerZeroEid(intent.sourceChainId) != srcEid) {
            errorSelector = LayerZeroStargateAdapterEidMismatch.selector;
        }

        // Resolve received token from the Stargate contract calling compose
        address receivedToken = IStargate(from).token();

        // Update intent token and amount to reflect what was actually received
        intent.token = receivedToken;
        intent.amount = amountLD;

        // Handle failure case
        if (errorSelector != bytes4(0)) {
            intent.status = ICrossChainExecutor.Status.Failed;
            emit IntentFailed(intent.intentId, errorSelector);
        }

        // For failed intents, executor will record the failure and hold tokens for refund
        IERC20(receivedToken).safeTransfer(executor, amountLD);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent, payload);

        emit IntentComposed(guid, srcEid, intent.intentId, amountLD);
    }

    /**
     * @inheritdoc ILayerZeroStargateAdapter
     */
    function quoteRefundFee(uint256 destinationChainId, address recipient, address token, uint256 amount, address stargate)
        external
        view
        override
        returns (uint256 fee)
    {
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

    /**
     * @inheritdoc ILayerZeroStargateAdapter
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address stargate,
        address feeRefundRecipient
    )
        external
        payable
        override
        returns (bytes32 refundId)
    {
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
            sendParam,
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            payable(feeRefundRecipient)
        );

        IERC20(token).forceApprove(stargate, 0);

        refundId = msgReceipt.guid;
        emit RefundSent(refundId, destinationChainId, recipient, token, amount);
    }

}
