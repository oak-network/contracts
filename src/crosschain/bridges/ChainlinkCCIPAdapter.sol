// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGlobalParams} from "../../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../../interfaces/ICrossChainExecutor.sol";
import {IChainlinkCCIPAdapter} from "../../interfaces/IChainlinkCCIPAdapter.sol";

/**
 * @title ChainlinkCCIPAdapter
 * @notice Destination-chain adapter for CCIP token delivery and refund sending.
 */
contract ChainlinkCCIPAdapter is CCIPReceiver, IChainlinkCCIPAdapter {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_ID = keccak256("CCIP");

    IGlobalParams public immutable GLOBAL_PARAMS;

    error ChainlinkCCIPAdapterUnauthorized();
    error ChainlinkCCIPAdapterInvalidSender();
    error ChainlinkCCIPAdapterUnexpectedTokenCount();
    error ChainlinkCCIPAdapterTokenMismatch();
    error ChainlinkCCIPAdapterAmountMismatch();
    error ChainlinkCCIPAdapterUnknownChainSelector();
    error ChainlinkCCIPAdapterChainSelectorMismatch(uint256 sourceChainId, uint64 expected, uint64 actual);
    error ChainlinkCCIPAdapterInvalidIntentSender(uint256 sourceChainId, address expected, address actual);
    error ChainlinkCCIPAdapterExecutorNotSet();
    error ChainlinkCCIPAdapterIntentExpired();
    error ChainlinkCCIPAdapterInsufficientFee(uint256 required, uint256 provided);
    error ChainlinkCCIPAdapterFeeRefundFailed();

    event RefundSent(bytes32 indexed messageId, uint256 destinationChainId, address recipient, uint256 amount);

    constructor(address router, IGlobalParams globalParams) CCIPReceiver(router) {
        GLOBAL_PARAMS = globalParams;
    }

    /**
     * @dev CCIP receive hook. Validates provenance, forwards funds to executor, and executes intent.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        address sourceSender = abi.decode(message.sender, (address));

        ICrossChainExecutor.CrossChainIntent memory intent =
            abi.decode(message.data, (ICrossChainExecutor.CrossChainIntent));

        address executor = GLOBAL_PARAMS.getCrossChainExecutor();

        // Validate sender provenance first.
        address expectedSender = ICrossChainExecutor(executor).getIntentSender(intent.sourceChainId);
        if (expectedSender != sourceSender) {
            revert ChainlinkCCIPAdapterInvalidIntentSender(intent.sourceChainId, expectedSender, sourceSender);
        }

        if (block.timestamp > intent.deadline) {
            revert ChainlinkCCIPAdapterIntentExpired();
        }

        uint64 expectedSelector = ICrossChainExecutor(executor).getCcipChainSelector(intent.sourceChainId);
        if (expectedSelector == 0) {
            revert ChainlinkCCIPAdapterUnknownChainSelector();
        }
        if (expectedSelector != message.sourceChainSelector) {
            revert ChainlinkCCIPAdapterChainSelectorMismatch(
                intent.sourceChainId, expectedSelector, message.sourceChainSelector
            );
        }

        if (message.destTokenAmounts.length != 1) {
            revert ChainlinkCCIPAdapterUnexpectedTokenCount();
        }

        address receivedToken = message.destTokenAmounts[0].token;
        uint256 receivedAmount = message.destTokenAmounts[0].amount;

        if (intent.amount != receivedAmount) {
            revert ChainlinkCCIPAdapterAmountMismatch();
        }

        IERC20(receivedToken).safeTransfer(executor, receivedAmount);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent, receivedToken);
    }

    /**
     * @inheritdoc IChainlinkCCIPAdapter
     */
    function sendRefund(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address feeRefundRecipient
    )
        external
        payable
        override
        returns (bytes32 messageId)
    {
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        if (executor == address(0) || msg.sender != executor) {
            revert ChainlinkCCIPAdapterUnauthorized();
        }

        uint64 destinationSelector = ICrossChainExecutor(executor).getCcipChainSelector(destinationChainId);
        if (destinationSelector == 0) {
            revert ChainlinkCCIPAdapterUnknownChainSelector();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        Client.EVM2AnyMessage memory ccipMessage = _buildRefundMessage(destinationSelector, recipient, token, amount);
        IRouterClient router = IRouterClient(getRouter());

        uint256 requiredFee = router.getFee(destinationSelector, ccipMessage);
        if (msg.value < requiredFee) {
            revert ChainlinkCCIPAdapterInsufficientFee(requiredFee, msg.value);
        }

        IERC20(token).forceApprove(address(router), amount);
        messageId = router.ccipSend{value: requiredFee}(destinationSelector, ccipMessage);
        IERC20(token).forceApprove(address(router), 0);

        if (msg.value > requiredFee) {
            (bool ok,) = feeRefundRecipient.call{value: msg.value - requiredFee}("");
            if (!ok) {
                revert ChainlinkCCIPAdapterFeeRefundFailed();
            }
        }

        emit RefundSent(messageId, destinationChainId, recipient, amount);
    }

    /**
     * @inheritdoc IChainlinkCCIPAdapter
     */
    function quoteRefundFee(uint256 destinationChainId, address token, uint256 amount)
        external
        view
        override
        returns (uint256 fee)
    {
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        uint64 destinationSelector = ICrossChainExecutor(executor).getCcipChainSelector(destinationChainId);

        Client.EVM2AnyMessage memory ccipMessage = _buildRefundMessage(destinationSelector, address(0), token, amount);
        return IRouterClient(getRouter()).getFee(destinationSelector, ccipMessage);
    }

    function _buildRefundMessage(uint64, address recipient, address token, uint256 amount)
        private
        pure
        returns (Client.EVM2AnyMessage memory)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(recipient),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: address(0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true}))
        });
    }

}
