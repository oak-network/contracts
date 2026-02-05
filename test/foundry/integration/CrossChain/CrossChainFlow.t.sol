// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BasePaymentTreasury} from "src/utils/BasePaymentTreasury.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {IChainlinkCCIPAdapter} from "src/interfaces/IChainlinkCCIPAdapter.sol";
import {ICrossChainExecutor} from "src/interfaces/ICrossChainExecutor.sol";
import {ILayerZeroStargateAdapter} from "src/interfaces/ILayerZeroStargateAdapter.sol";
import {CrossChainExecutor} from "src/crosschain/CrossChainExecutor.sol";
import {IntentSender} from "src/crosschain/IntentSender.sol";
import {ChainlinkCCIPAdapter} from "src/crosschain/bridges/ChainlinkCCIPAdapter.sol";
import {LayerZeroStargateAdapter} from "src/crosschain/bridges/LayerZeroStargateAdapter.sol";

import {CCIPLocalSimulator, IRouterClient} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {MockCCIPRouter} from "@chainlink/local/src/vendor/chainlink-ccip/test/mocks/MockRouter.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {MockStargate} from "../../../mocks/MockStargate.sol";
import {PaymentTreasury_Integration_Shared_Test} from "../PaymentTreasury/PaymentTreasury.t.sol";

contract CrossChainFlowTest is PaymentTreasury_Integration_Shared_Test {
    uint32 internal constant SRC_EID = 1;
    uint32 internal constant DST_EID = 2;

    CCIPLocalSimulator internal ccipLocalSimulator;
    IRouterClient internal ccipRouter;
    uint64 internal ccipChainSelector;

    CrossChainExecutor internal executor;
    IntentSender internal intentSender;
    ChainlinkCCIPAdapter internal ccipAdapter;
    LayerZeroStargateAdapter internal lzAdapter;
    MockStargate internal stargate;
    EndpointV2Mock internal endpoint;

    address internal agent;

    function setUp() public override(PaymentTreasury_Integration_Shared_Test) {
        PaymentTreasury_Integration_Shared_Test.setUp();
        endpoint = new EndpointV2Mock(DST_EID, address(this));
        ILayerZeroEndpointV2 endpointDst = ILayerZeroEndpointV2(address(endpoint));

        agent = makeAddr("agent");
        executor = new CrossChainExecutor(agent, globalParams);

        vm.prank(users.protocolAdminAddress);
        globalParams.setCrossChainExecutor(address(executor));

        ccipLocalSimulator = new CCIPLocalSimulator();
        (uint64 chainSelector, IRouterClient sourceRouter,,,,,) = ccipLocalSimulator.configuration();
        ccipChainSelector = chainSelector;
        ccipRouter = sourceRouter;

        ccipAdapter = new ChainlinkCCIPAdapter(address(ccipRouter), globalParams);
        lzAdapter = new LayerZeroStargateAdapter(address(endpointDst), globalParams);

        intentSender = new IntentSender(
            agent,
            address(ccipRouter),
            ccipChainSelector,
            address(ccipAdapter),
            DST_EID,
            address(lzAdapter)
        );

        stargate = new MockStargate(IERC20(address(testToken)), endpointDst, SRC_EID);

        _configureExecutor();
    }

    function _configureExecutor() internal {
        vm.startPrank(users.protocolAdminAddress);

        bytes32[] memory bridgeIds = new bytes32[](2);
        bridgeIds[0] = executor.BRIDGE_ID_CCIP();
        bridgeIds[1] = executor.BRIDGE_ID_LAYERZERO();

        address[] memory adapters = new address[](2);
        adapters[0] = address(ccipAdapter);
        adapters[1] = address(lzAdapter);

        executor.setBridgeAdapters(bridgeIds, adapters);
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;

        address[] memory intentSenders = new address[](1);
        intentSenders[0] = address(intentSender);
        executor.setIntentSenders(chainIds, intentSenders);

        uint64[] memory selectors = new uint64[](1);
        selectors[0] = ccipChainSelector;
        executor.setCcipChainSelectors(chainIds, selectors);

        uint32[] memory eids = new uint32[](1);
        eids[0] = SRC_EID;
        executor.setLayerZeroEids(chainIds, eids);

        bytes4[] memory allowed = new bytes4[](1);
        allowed[0] = BasePaymentTreasury.processCrossChainPayment.selector;
        executor.setSelectors(allowed, true);

        vm.stopPrank();
    }

    function _buildIntent(
        bytes32 intentId,
        address account,
        address token,
        uint256 amount
    ) internal view returns (ICrossChainExecutor.Intent memory) {
        return ICrossChainExecutor.Intent({
            intentId: intentId,
            sourceChainId: 0,
            status: ICrossChainExecutor.Status.None,
            treasury: treasuryAddress,
            account: account,
            token: token,
            amount: amount
        });
    }

    function _buildPayload(
        bytes32 intentId,
        bytes32 paymentId,
        bytes32 itemId,
        address buyer,
        address token,
        uint256 amount
    ) internal pure returns (bytes memory) {
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](0);
        ICampaignPaymentTreasury.ExternalFees[] memory externalFees = new ICampaignPaymentTreasury.ExternalFees[](0);

        return abi.encodeWithSelector(
            BasePaymentTreasury.processCrossChainPayment.selector,
            intentId,
            paymentId,
            itemId,
            buyer,
            token,
            amount,
            lineItems,
            externalFees
        );
    }

    function _sendIntentCCIP(ICrossChainExecutor.Intent memory intent, bytes memory payload) internal {
        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        intentSender.sendIntentCCIP(intent, payload, 0);
    }

    function _sendIntentLZ(ICrossChainExecutor.Intent memory intent, bytes memory payload) internal {
        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(stargate), minAmount: intent.amount, gasLimit: 0});

        vm.prank(agent);
        intentSender.sendIntentLZStargate(params, intent, payload);
    }

    function _sendIntentLZWithParams(
        ICrossChainExecutor.Intent memory intent,
        bytes memory payload,
        IntentSender.LZStargateParams memory params,
        uint256 feeValue
    ) internal {
        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        intentSender.sendIntentLZStargate{value: feeValue}(params, intent, payload);
    }

    function _routeCcipMessage(
        ICrossChainExecutor.Intent memory intent,
        bytes memory payload,
        uint64 sourceSelector,
        uint256 receivedAmount
    ) internal {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(testToken), amount: receivedAmount});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sourceSelector,
            sender: abi.encode(address(intentSender)),
            data: abi.encode(intent, payload),
            destTokenAmounts: tokenAmounts
        });

        MockCCIPRouter(address(ccipRouter)).routeMessage(
            message,
            5_000,
            200_000,
            address(ccipAdapter)
        );
    }

    function test_ccip_flow_executes_payment() public {
        bytes32 intentId = keccak256("ccip-intent");
        bytes32 paymentId = keccak256("ccip-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Executed));

        ICampaignPaymentTreasury.PaymentData memory payment = paymentTreasury.getPaymentData(paymentId);
        assertEq(payment.amount, amount);
        assertEq(payment.buyerAddress, users.backer1Address);
        assertEq(payment.paymentToken, address(testToken));
        assertTrue(payment.isConfirmed);
        assertTrue(payment.isCryptoPayment);

        assertEq(IERC20(address(testToken)).balanceOf(treasuryAddress), amount);
    }

    function test_ccip_fails_when_selector_not_allowlisted() public {
        bytes32 intentId = keccak256("ccip-selector-fail");
        bytes32 paymentId = keccak256("ccip-payment-fail");
        uint256 amount = PAYMENT_AMOUNT_1;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = BasePaymentTreasury.processCrossChainPayment.selector;
        vm.prank(users.protocolAdminAddress);
        executor.setSelectors(selectors, false);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), amount);

        vm.expectRevert();
        paymentTreasury.getPaymentData(paymentId);
    }

    function test_ccip_fails_when_treasury_reverts() public {
        bytes32 intentId = keccak256("ccip-revert");
        bytes32 paymentId = bytes32(0);
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), amount);
    }

    function test_ccip_refund_flow_after_execution() public {
        bytes32 intentId = keccak256("ccip-refund");
        bytes32 paymentId = keccak256("ccip-payment-refund");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        uint256 refundAmount = claimRefund(users.backer1Address, paymentId, 1);
        assertEq(refundAmount, amount);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.RefundRequested));
        assertEq(stored.amount, refundAmount);
        assertEq(stored.account, users.backer1Address);
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), refundAmount);

        uint256 buyerBalanceBefore = IERC20(address(testToken)).balanceOf(users.backer1Address);
        vm.prank(agent);
        bytes32 refundId = executor.sendRefundCCIP(intentId);
        assertTrue(refundId != bytes32(0));

        uint256 buyerBalanceAfter = IERC20(address(testToken)).balanceOf(users.backer1Address);
        assertEq(buyerBalanceAfter, buyerBalanceBefore + refundAmount);

        ICrossChainExecutor.Intent memory cleared = executor.getIntent(intentId);
        assertEq(uint8(cleared.status), uint8(ICrossChainExecutor.Status.None));
    }

    function test_ccip_refund_flow_after_failed_intent() public {
        bytes32 intentId = keccak256("ccip-failed-refund");
        bytes32 paymentId = keccak256("ccip-payment-failed");
        uint256 amount = PAYMENT_AMOUNT_1;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = BasePaymentTreasury.processCrossChainPayment.selector;
        vm.prank(users.protocolAdminAddress);
        executor.setSelectors(selectors, false);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));

        uint256 buyerBalanceBefore = IERC20(address(testToken)).balanceOf(users.backer1Address);
        vm.prank(agent);
        executor.sendRefundCCIP(intentId);

        uint256 buyerBalanceAfter = IERC20(address(testToken)).balanceOf(users.backer1Address);
        assertEq(buyerBalanceAfter, buyerBalanceBefore + amount);
    }

    function test_ccip_send_reverts_on_insufficient_fee() public {
        bytes32 intentId = keccak256("ccip-insufficient-fee");
        bytes32 paymentId = keccak256("ccip-insufficient-fee-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        MockCCIPRouter(address(ccipRouter)).setFee(1 ether);

        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        vm.expectRevert(IntentSender.IntentSenderInsufficientFee.selector);
        intentSender.sendIntentCCIP(intent, payload, 0);
    }

    function test_ccip_refund_reverts_on_insufficient_fee() public {
        bytes32 intentId = keccak256("ccip-refund-fee");
        bytes32 paymentId = keccak256("ccip-refund-fee-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = BasePaymentTreasury.processCrossChainPayment.selector;
        vm.prank(users.protocolAdminAddress);
        executor.setSelectors(selectors, false);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentCCIP(intent, payload);

        MockCCIPRouter(address(ccipRouter)).setFee(1 ether);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IChainlinkCCIPAdapter.ChainlinkCCIPAdapterInsufficientFee.selector, 1 ether, 0)
        );
        executor.sendRefundCCIP(intentId);
    }

    function test_ccip_adapter_amount_mismatch_soft_fails() public {
        bytes32 intentId = keccak256("ccip-amount-mismatch");
        bytes32 paymentId = keccak256("ccip-amount-mismatch-payment");
        uint256 amount = PAYMENT_AMOUNT_1;
        uint256 received = amount - 1e18;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        intent.sourceChainId = block.chainid;
        intent.status = ICrossChainExecutor.Status.Ongoing;

        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        vm.prank(users.contractOwner);
        testToken.mint(address(ccipAdapter), received);

        _routeCcipMessage(intent, payload, ccipChainSelector, received);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(stored.amount, received);
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), received);
    }

    function test_ccip_adapter_chain_selector_mismatch_soft_fails() public {
        bytes32 intentId = keccak256("ccip-selector-mismatch");
        bytes32 paymentId = keccak256("ccip-selector-mismatch-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        intent.sourceChainId = block.chainid;
        intent.status = ICrossChainExecutor.Status.Ongoing;

        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        vm.prank(users.contractOwner);
        testToken.mint(address(ccipAdapter), amount);

        _routeCcipMessage(intent, payload, ccipChainSelector + 1, amount);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), amount);
    }

    function test_layerzero_flow_executes_payment() public {
        bytes32 intentId = keccak256("lz-intent");
        bytes32 paymentId = keccak256("lz-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentLZ(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Executed));

        ICampaignPaymentTreasury.PaymentData memory payment = paymentTreasury.getPaymentData(paymentId);
        assertEq(payment.amount, amount);
        assertEq(payment.buyerAddress, users.backer1Address);
        assertEq(payment.paymentToken, address(testToken));
        assertTrue(payment.isConfirmed);
        assertTrue(payment.isCryptoPayment);

        assertEq(IERC20(address(testToken)).balanceOf(treasuryAddress), amount);
    }

    function test_layerzero_fails_on_eid_mismatch() public {
        bytes32 intentId = keccak256("lz-eid-fail");
        bytes32 paymentId = keccak256("lz-payment-fail");
        uint256 amount = PAYMENT_AMOUNT_1;

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid;
        uint32[] memory eids = new uint32[](1);
        eids[0] = SRC_EID + 1;

        vm.prank(users.protocolAdminAddress);
        executor.setLayerZeroEids(chainIds, eids);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentLZ(intent, payload);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), amount);

        vm.expectRevert();
        paymentTreasury.getPaymentData(paymentId);
    }

    function test_layerzero_refund_flow_after_execution() public {
        bytes32 intentId = keccak256("lz-refund");
        bytes32 paymentId = keccak256("lz-payment-refund");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentLZ(intent, payload);

        uint256 refundAmount = claimRefund(users.backer1Address, paymentId, 1);
        assertEq(refundAmount, amount);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.RefundRequested));

        uint256 buyerBalanceBefore = IERC20(address(testToken)).balanceOf(users.backer1Address);
        vm.prank(agent);
        bytes32 refundId = executor.sendRefundLZStargate(intentId, address(stargate));
        assertTrue(refundId != bytes32(0));

        uint256 buyerBalanceAfter = IERC20(address(testToken)).balanceOf(users.backer1Address);
        assertEq(buyerBalanceAfter, buyerBalanceBefore + refundAmount);
    }

    function test_layerzero_reverts_when_min_amount_exceeds_quote() public {
        bytes32 intentId = keccak256("lz-min-amount");
        bytes32 paymentId = keccak256("lz-min-amount-payment");
        uint256 amount = PAYMENT_AMOUNT_1;
        uint256 received = amount - 1e18;

        stargate.setAmountReceivedOverride(received);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(stargate), minAmount: amount, gasLimit: 0});

        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IntentSender.IntentSenderUnexpectedReceivedAmount.selector, amount, received)
        );
        intentSender.sendIntentLZStargate(params, intent, payload);
    }

    function test_layerzero_payload_amount_too_high_soft_fails() public {
        bytes32 intentId = keccak256("lz-payload-too-high");
        bytes32 paymentId = keccak256("lz-payload-too-high-payment");
        uint256 amount = PAYMENT_AMOUNT_1;
        uint256 received = amount - 1e18;

        stargate.setAmountReceivedOverride(received);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(stargate), minAmount: received, gasLimit: 0});

        _sendIntentLZWithParams(intent, payload, params, 0);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Failed));
        assertEq(IERC20(address(testToken)).balanceOf(address(executor)), received);

        vm.expectRevert();
        paymentTreasury.getPaymentData(paymentId);
    }

    function test_layerzero_payload_amount_matches_quote_executes() public {
        bytes32 intentId = keccak256("lz-quote-amount");
        bytes32 paymentId = keccak256("lz-quote-payment");
        uint256 amount = PAYMENT_AMOUNT_1;
        uint256 received = amount - 1e18;

        stargate.setAmountReceivedOverride(received);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(stargate), minAmount: received, gasLimit: 0});

        (uint256 nativeFee,, , OFTReceipt memory receipt) =
            intentSender.quoteFeeLZStargate(params, intent, abi.encodePacked(BasePaymentTreasury.processCrossChainPayment.selector));

        bytes memory payload = _buildPayload(
            intentId,
            paymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            receipt.amountReceivedLD
        );

        _sendIntentLZWithParams(intent, payload, params, nativeFee);

        ICrossChainExecutor.Intent memory stored = executor.getIntent(intentId);
        assertEq(uint8(stored.status), uint8(ICrossChainExecutor.Status.Executed));

        ICampaignPaymentTreasury.PaymentData memory payment = paymentTreasury.getPaymentData(paymentId);
        assertEq(payment.amount, receipt.amountReceivedLD);
        assertEq(IERC20(address(testToken)).balanceOf(treasuryAddress), receipt.amountReceivedLD);
    }

    function test_layerzero_send_reverts_on_insufficient_fee() public {
        bytes32 intentId = keccak256("lz-insufficient-fee");
        bytes32 paymentId = keccak256("lz-insufficient-fee-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        stargate.setNativeFee(1 ether);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(stargate), minAmount: amount, gasLimit: 0});

        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        vm.expectRevert(IntentSender.IntentSenderInsufficientFee.selector);
        intentSender.sendIntentLZStargate(params, intent, payload);
    }

    function test_layerzero_invalid_stargate_token_reverts() public {
        bytes32 intentId = keccak256("lz-invalid-stargate");
        bytes32 paymentId = keccak256("lz-invalid-stargate-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        MockStargate otherStargate =
            new MockStargate(IERC20(address(usdcToken)), ILayerZeroEndpointV2(address(endpoint)), SRC_EID);

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        IntentSender.LZStargateParams memory params =
            IntentSender.LZStargateParams({stargate: address(otherStargate), minAmount: amount, gasLimit: 0});

        vm.prank(intent.account);
        IERC20(intent.token).approve(address(intentSender), intent.amount);

        vm.prank(agent);
        vm.expectRevert(IntentSender.IntentSenderInvalidStargate.selector);
        intentSender.sendIntentLZStargate(params, intent, payload);
    }

    function test_layerzero_refund_reverts_on_insufficient_fee() public {
        bytes32 intentId = keccak256("lz-refund-fee");
        bytes32 paymentId = keccak256("lz-refund-fee-payment");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        bytes memory payload = _buildPayload(intentId, paymentId, ITEM_ID_1, users.backer1Address, address(testToken), amount);

        _sendIntentLZ(intent, payload);
        claimRefund(users.backer1Address, paymentId, 1);

        stargate.setNativeFee(1 ether);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(ILayerZeroStargateAdapter.LayerZeroStargateAdapterInsufficientFee.selector, 1 ether, 0)
        );
        executor.sendRefundLZStargate(intentId, address(stargate));
    }

    function test_layerzero_invalid_peer_reverts() public {
        bytes32 intentId = keccak256("lz-invalid-peer");
        uint256 amount = PAYMENT_AMOUNT_1;

        ICrossChainExecutor.Intent memory intent =
            _buildIntent(intentId, users.backer1Address, address(testToken), amount);
        intent.sourceChainId = block.chainid;
        intent.status = ICrossChainExecutor.Status.Ongoing;

        bytes memory payload = _buildPayload(intentId, keccak256("lz-invalid-peer-payment"), ITEM_ID_1, users.backer1Address, address(testToken), amount);

        bytes32 fakePeer = bytes32(uint256(uint160(address(0xBEEF))));
        bytes memory inner = abi.encode(intent, payload);
        bytes memory composeMsg = abi.encodePacked(fakePeer, inner);
        bytes memory fullMsg = OFTComposeMsgCodec.encode(1, SRC_EID, amount, composeMsg);

        bytes32 guid = keccak256("lz-invalid-peer-guid");

        vm.prank(address(stargate));
        endpoint.sendCompose(address(lzAdapter), guid, 0, fullMsg);

        vm.expectRevert(ILayerZeroStargateAdapter.LayerZeroStargateAdapterInvalidPeer.selector);
        endpoint.lzCompose(address(stargate), address(lzAdapter), guid, 0, fullMsg, bytes(""));
    }

    function test_send_refund_ccip_only_agent() public {
        vm.expectRevert(ICrossChainExecutor.ExecutorUnauthorized.selector);
        executor.sendRefundCCIP(bytes32("nope"));
    }
}
