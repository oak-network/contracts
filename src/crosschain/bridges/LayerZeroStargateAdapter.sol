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
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";

/**
 * @title LayerZeroStargateAdapter
 * @notice Destination-chain adapter for LayerZero v2 + Stargate v2 delivery and refunds.
 */
contract LayerZeroStargateAdapter is ILayerZeroComposer, IBridgeAdapter {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_ID = keccak256("LAYERZERO");

    ILayerZeroEndpointV2 public immutable ENDPOINT;
    IGlobalParams public immutable GLOBAL_PARAMS;

    // Needed for refunds: destination token => Stargate contract that can bridge that token.
    mapping(address => address) public stargateForToken;

    error LayerZeroStargateAdapterUnauthorized();
    error LayerZeroStargateAdapterInvalidPeer();
    error LayerZeroStargateAdapterTokenNotConfigured();
    error LayerZeroStargateAdapterAmountMismatch();
    error LayerZeroStargateAdapterUnknownDestinationChainId();
    error LayerZeroStargateAdapterEidMismatch(uint256 sourceChainId, uint32 expected, uint32 actual);
    error LayerZeroStargateAdapterExecutorNotSet();
    error LayerZeroStargateAdapterIntentExpired();

    event IntentComposed(bytes32 indexed guid, uint32 indexed srcEid, bytes32 indexed intentId, uint256 amount);
    event RefundSent(bytes32 indexed guid, uint256 destinationChainId, address recipient, address token, uint256 amount);

    constructor(address endpoint, IGlobalParams globalParams) {
        ENDPOINT = ILayerZeroEndpointV2(endpoint);
        GLOBAL_PARAMS = globalParams;
    }

    modifier onlyProtocolAdmin() {
        if (msg.sender != GLOBAL_PARAMS.getProtocolAdminAddress()) {
            revert LayerZeroStargateAdapterUnauthorized();
        }
        _;
    }

    /// @notice Sets the Stargate contract used to bridge a given destination token for refunds.
    function setStargateForToken(address token, address stargate) external onlyProtocolAdmin {
        if (token == address(0) || stargate == address(0)) {
            revert LayerZeroStargateAdapterTokenNotConfigured();
        }
        stargateForToken[token] = stargate;
    }

    /**
     * @notice LayerZero compose entrypoint. Validates provenance and dispatches intent.
     */
    function lzCompose(
        address from,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) external payable override {
        if (msg.sender != address(ENDPOINT)) {
            revert LayerZeroStargateAdapterUnauthorized();
        }

        uint32 srcEid = OFTComposeMsgCodec.srcEid(message);
        bytes32 composeFrom = OFTComposeMsgCodec.composeFrom(message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(message);

        bytes memory inner = OFTComposeMsgCodec.composeMsg(message);
        ICrossChainExecutor.CrossChainIntent memory intent = abi.decode(inner, (ICrossChainExecutor.CrossChainIntent));
        
        if (block.timestamp > intent.deadline) {
            revert LayerZeroStargateAdapterIntentExpired();
        }

        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        if (executor == address(0)) {
            revert LayerZeroStargateAdapterExecutorNotSet();
        }

        uint32 expectedEid = ICrossChainExecutor(executor).getLayerZeroEid(intent.sourceChainId);
        if (expectedEid == 0) {
            revert LayerZeroStargateAdapterUnknownDestinationChainId();
        }
        if (expectedEid != srcEid) {
            revert LayerZeroStargateAdapterEidMismatch(intent.sourceChainId, expectedEid, srcEid);
        }

        address expectedSender = ICrossChainExecutor(executor).getIntentSender(intent.sourceChainId);
        bytes32 expectedPeer = bytes32(uint256(uint160(expectedSender)));
        if (expectedSender == address(0) || expectedPeer != composeFrom) {
            revert LayerZeroStargateAdapterInvalidPeer();
        }

        if (intent.amount != amountLD) {
            revert LayerZeroStargateAdapterAmountMismatch();
        }

        // Resolve received token from the Stargate contract calling compose.
        address receivedToken = IStargate(from).token();

        IERC20(receivedToken).safeTransfer(executor, amountLD);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent, receivedToken);

        emit IntentComposed(guid, srcEid, intent.intentId, amountLD);
    }

    /**
     * @notice Quotes the LayerZero/Stargate fee for a refund.
     * @param destinationChainId The source chainId of the original intent.
     * @param token The token to refund.
     * @param amount The amount to refund.
     * @return fee The native fee required.
     */
    function quoteRefundFee(uint256 destinationChainId, address token, uint256 amount)
        external
        view
        override
        returns (uint256 fee)
    {
        address stargate = stargateForToken[token];
        if (stargate == address(0)) {
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
            to: bytes32(uint256(uint160(address(0)))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory mfee = IStargate(stargate).quoteSend(sendParam, false);
        return mfee.nativeFee;
    }

    /**
     * @notice Sends a refund back to the source chain using Stargate.
     * @param destinationChainId The source chainId of the original intent.
     * @param recipient The recipient on the source chain.
     * @param token The token on destination chain to refund.
     * @param amount The amount to refund.
     * @return refundId The LayerZero GUID for tracking.
     */
    function sendRefund(uint256 destinationChainId, address recipient, address token, uint256 amount)
        external
        payable
        override
        returns (bytes32 refundId)
    {
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        if (executor == address(0) || msg.sender != executor) {
            revert LayerZeroStargateAdapterUnauthorized();
        }

        address stargate = stargateForToken[token];
        if (stargate == address(0)) {
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
            minAmountLD: amount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (MessagingReceipt memory msgReceipt,) = IStargate(stargate).send{value: msg.value}(
            sendParam,
            MessagingFee({nativeFee: msg.value, lzTokenFee: 0}),
            payable(msg.sender)
        );

        IERC20(token).forceApprove(stargate, 0);

        refundId = msgReceipt.guid;
        emit RefundSent(refundId, destinationChainId, recipient, token, amount);
    }

    receive() external payable {}
}
