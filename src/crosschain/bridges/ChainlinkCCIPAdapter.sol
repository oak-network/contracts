// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGlobalParams} from "../../interfaces/IGlobalParams.sol";
import {ICrossChainExecutor} from "../../interfaces/ICrossChainExecutor.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {CrossChainRegistryKeys} from "../../constants/CrossChainRegistryKeys.sol";

/**
 * @title ChainlinkCCIPAdapter
 * @notice Destination-chain adapter for CCIP token delivery and refund sending.
 */
contract ChainlinkCCIPAdapter is CCIPReceiver, IBridgeAdapter {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_ID = keccak256("CCIP");

    IGlobalParams public immutable GLOBAL_PARAMS;

    error ChainlinkCCIPAdapterUnauthorized();
    error ChainlinkCCIPAdapterInvalidSender();
    error ChainlinkCCIPAdapterUnexpectedTokenCount();
    error ChainlinkCCIPAdapterTokenMismatch();
    error ChainlinkCCIPAdapterAmountMismatch();
    error ChainlinkCCIPAdapterUnknownChainSelector();
    error ChainlinkCCIPAdapterSourceChainIdMismatch(uint256 payloadChainId, uint64 provenanceSelector, uint64 expected);
    error ChainlinkCCIPAdapterExecutorNotSet();
    error ChainlinkCCIPAdapterIntentExpired();

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

        if (block.timestamp > intent.deadline) {
            revert ChainlinkCCIPAdapterIntentExpired();
        }
        
        uint64 expectedSelector = _getCcipSelector(intent.sourceChainId);
        if (expectedSelector == 0) {
            revert ChainlinkCCIPAdapterUnknownChainSelector();
        }
        if (expectedSelector != message.sourceChainSelector) {
            revert ChainlinkCCIPAdapterSourceChainIdMismatch(
                intent.sourceChainId, message.sourceChainSelector, expectedSelector
            );
        }

        address allowedSender = _getAllowedSender(intent.sourceChainId);
        if (allowedSender == address(0) || allowedSender != sourceSender) {
            revert ChainlinkCCIPAdapterInvalidSender();
        }

        if (message.destTokenAmounts.length != 1) {
            revert ChainlinkCCIPAdapterUnexpectedTokenCount();
        }

        address receivedToken = message.destTokenAmounts[0].token;
        uint256 receivedAmount = message.destTokenAmounts[0].amount;

        if (intent.destinationToken != receivedToken) {
            revert ChainlinkCCIPAdapterTokenMismatch();
        }
        if (intent.amount != receivedAmount) {
            revert ChainlinkCCIPAdapterAmountMismatch();
        }

        address executor = _getExecutor();
        if (executor == address(0)) {
            revert ChainlinkCCIPAdapterExecutorNotSet();
        }

        IERC20(receivedToken).safeTransfer(executor, receivedAmount);
        ICrossChainExecutor(executor).executeIntent(BRIDGE_ID, intent);
    }

    /**
     * @notice Sends a refund back to the source chain using CCIP.
     * @param destinationChainId The source chainId of the original intent.
     * @param recipient The recipient address on the source chain.
     * @param token The token on destination chain to refund.
     * @param amount The amount to refund.
     * @return messageId The CCIP message ID.
     */
    function sendRefund(uint256 destinationChainId, address recipient, address token, uint256 amount)
        external
        payable
        override
        returns (bytes32 messageId)
    {
        if (msg.sender != _getExecutor()) {
            revert ChainlinkCCIPAdapterUnauthorized();
        }

        uint64 destinationSelector = _getCcipSelector(destinationChainId);
        if (destinationSelector == 0) {
            revert ChainlinkCCIPAdapterUnknownChainSelector();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        Client.EVM2AnyMessage memory ccipMessage = _buildRefundMessage(destinationSelector, recipient, token, amount);
        IRouterClient router = IRouterClient(getRouter());

        IERC20(token).forceApprove(address(router), amount);
        messageId = router.ccipSend{value: msg.value}(destinationSelector, ccipMessage);
        IERC20(token).forceApprove(address(router), 0);

        emit RefundSent(messageId, destinationChainId, recipient, amount);
    }

    /**
     * @notice Quotes the CCIP fee for a refund.
     * @param destinationChainId The source chainId of the original intent.
     * @param token The token to refund.
     * @param amount The amount to refund.
     * @return fee The native fee required by CCIP.
     */
    function quoteRefundFee(uint256 destinationChainId, address token, uint256 amount)
        external
        view
        override
        returns (uint256 fee)
    {
        uint64 destinationSelector = _getCcipSelector(destinationChainId);
        if (destinationSelector == 0) {
            revert ChainlinkCCIPAdapterUnknownChainSelector();
        }

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

    function _getExecutor() internal view returns (address) {
        bytes32 value = GLOBAL_PARAMS.getFromRegistry(CrossChainRegistryKeys.executor());
        return address(uint160(uint256(value)));
    }

    function _getCcipSelector(uint256 chainId) internal view returns (uint64) {
        return uint64(uint256(GLOBAL_PARAMS.getFromRegistry(CrossChainRegistryKeys.ccipSelector(chainId))));
    }

    function _getAllowedSender(uint256 chainId) internal view returns (address) {
        bytes32 value = GLOBAL_PARAMS.getFromRegistry(CrossChainRegistryKeys.allowedSender(chainId, BRIDGE_ID));
        return address(uint160(uint256(value)));
    }

    receive() external payable {}
}
