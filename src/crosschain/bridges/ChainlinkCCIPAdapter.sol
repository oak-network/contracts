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

    // Hard revert errors (authentication/critical)
    error ChainlinkCCIPAdapterUnauthorized();
    error ChainlinkCCIPAdapterInvalidIntentSender();

    // Soft failure errors (simplified, no params)
    error ChainlinkCCIPAdapterInvalidIntentStatus();
    error ChainlinkCCIPAdapterChainSelectorMismatch();
    error ChainlinkCCIPAdapterAmountMismatch();

    // Refund-related errors
    error ChainlinkCCIPAdapterUnknownChainSelector();
    error ChainlinkCCIPAdapterInsufficientFee(uint256 required, uint256 provided);
    error ChainlinkCCIPAdapterFeeRefundFailed();

    event RefundSent(bytes32 indexed messageId, uint256 destinationChainId, address recipient, uint256 amount);
    event IntentFailed(bytes32 indexed intentId, bytes4 errorSelector);

    constructor(address router, IGlobalParams globalParams) CCIPReceiver(router) {
        GLOBAL_PARAMS = globalParams;
    }

    /**
     * @dev CCIP receive hook. Validates provenance, updates intent token, forwards funds to executor, and executes intent.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (ICrossChainExecutor.Intent memory intent, bytes memory payload) =
            abi.decode(message.data, (ICrossChainExecutor.Intent, bytes));

        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        address sourceSender = abi.decode(message.sender, (address));
        
        // Validate sender provenance - revert on failure
        address expectedSender = ICrossChainExecutor(executor).getIntentSender(intent.sourceChainId);
        if (expectedSender != sourceSender) {
            revert ChainlinkCCIPAdapterInvalidIntentSender();
        }

        // Soft failure validations 
        bytes4 errorSelector;

        address receivedToken = message.destTokenAmounts[0].token;
        uint256 receivedAmount = message.destTokenAmounts[0].amount;

        if (intent.status != ICrossChainExecutor.Status.Ongoing) {
            errorSelector = ChainlinkCCIPAdapterInvalidIntentStatus.selector;
        } else if (ICrossChainExecutor(executor).getCcipChainSelector(intent.sourceChainId) != message.sourceChainSelector) {
            errorSelector = ChainlinkCCIPAdapterChainSelectorMismatch.selector;
        } else if (intent.amount != receivedAmount) {
            errorSelector = ChainlinkCCIPAdapterAmountMismatch.selector;
        }

        // Update intent token to the received destination token
        intent.token = receivedToken;

        if (errorSelector != bytes4(0)) {
            intent.status = ICrossChainExecutor.Status.Failed;
            emit IntentFailed(intent.intentId, errorSelector);
        }

        // For failed intents, executor will record the failure and hold tokens for refund
        IERC20(receivedToken).safeTransfer(executor, receivedAmount);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent, payload);
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
    function quoteRefundFee(uint256 destinationChainId, address recipient, address token, uint256 amount)
        external
        view
        override
        returns (uint256 fee)
    {
        address executor = GLOBAL_PARAMS.getCrossChainExecutor();
        uint64 destinationSelector = ICrossChainExecutor(executor).getCcipChainSelector(destinationChainId);

        Client.EVM2AnyMessage memory ccipMessage = _buildRefundMessage(destinationSelector, recipient, token, amount);
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
