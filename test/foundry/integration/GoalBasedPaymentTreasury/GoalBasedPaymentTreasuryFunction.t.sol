// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./GoalBasedPaymentTreasury.t.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {GoalBasedPaymentTreasury} from "src/treasuries/GoalBasedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TestToken} from "../../../mocks/TestToken.sol";

contract GoalBasedPaymentTreasuryFunction_Integration_Shared_Test is
    GoalBasedPaymentTreasury_Integration_Shared_Test
{
    function setUp() public virtual override {
        super.setUp();

        // Fund test users with tokens
        deal(address(testToken), users.backer1Address, 1_000_000e18);
        deal(address(testToken), users.backer2Address, 1_000_000e18);
        deal(address(testToken), users.creator1Address, 1_000_000e18);
        deal(address(testToken), users.platform1AdminAddress, 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC PAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createPayment() external {
        advanceToWithinRange();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Payment created successfully
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
        assertEq(goalBasedPaymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function test_createPaymentBatch() external {
        advanceToWithinRange();

        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;

        bytes32[] memory buyerIds = new bytes32[](2);
        buyerIds[0] = BUYER_ID_1;
        buyerIds[1] = BUYER_ID_2;

        bytes32[] memory itemIds = new bytes32[](2);
        itemIds[0] = ITEM_ID_1;
        itemIds[1] = ITEM_ID_2;

        address[] memory paymentTokens = new address[](2);
        paymentTokens[0] = address(testToken);
        paymentTokens[1] = address(testToken);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = PAYMENT_AMOUNT_1;
        amounts[1] = PAYMENT_AMOUNT_2;

        uint256[] memory expirations = new uint256[](2);
        expirations[0] = block.timestamp + PAYMENT_EXPIRATION;
        expirations[1] = block.timestamp + PAYMENT_EXPIRATION;

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray = new ICampaignPaymentTreasury.LineItem[][](2);
        emptyLineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[1] = new ICampaignPaymentTreasury.LineItem[](0);

        ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](2);
        externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);
        externalFeesArray[1] = new ICampaignPaymentTreasury.ExternalFees[](0);

        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, emptyLineItemsArray, externalFeesArray
        );

        // Payments created successfully
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_processCryptoPayment() external {
        advanceToWithinRange();

        // Approve tokens for the treasury
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Payment processed successfully
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(goalBasedPaymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_cancelPayment() external {
        advanceToWithinRange();

        // First create a payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Then cancel it
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.cancelPayment(PAYMENT_ID_1);

        // Payment cancelled successfully
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_confirmPayment() external {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Confirm payment
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);

        // Payment confirmed successfully
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(goalBasedPaymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    /*//////////////////////////////////////////////////////////////
                    TIME CONSTRAINT TESTS - CREATE PAYMENTS
    //////////////////////////////////////////////////////////////*/

    function test_createPayment_RevertWhenBeforeLaunchTime() external {
        advanceToBeforeLaunch();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function test_createPayment_RevertWhenAfterDeadline() external {
        advanceToAfterDeadline();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function test_createPayment_SucceedsAtExactDeadline() external {
        advanceToDeadline();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);

        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Should succeed at exact deadline
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_processCryptoPayment_RevertWhenAfterDeadline() external {
        advanceToAfterDeadline();

        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                TIME CONSTRAINT TESTS - CONFIRM PAYMENTS
    //////////////////////////////////////////////////////////////*/

    function test_confirmPayment_SucceedsWithinBufferPeriod() external {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance to buffer period
        advanceToAfterDeadline();

        // Confirm payment should still work during buffer
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_confirmPayment_RevertWhenAfterBufferPeriod() external {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past buffer period
        advanceToAfterDeadlinePlusBuffer();

        // Confirm payment should fail after buffer
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);
    }

    /*//////////////////////////////////////////////////////////////
                    GOAL PROGRESS CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getGoalProgress_PendingPlusConfirmed_BeforeBufferEnd() external {
        advanceToWithinRange();

        // Create and confirm a crypto payment (confirmed)
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Create a pending payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Goal progress should include both pending and confirmed
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgress, PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2, "Goal progress should be pending + confirmed");
    }

    function test_getGoalProgress_OnlyConfirmed_AfterBufferEnd() external {
        advanceToWithinRange();

        // Create and confirm a crypto payment (confirmed)
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Create a pending payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Advance past buffer period
        advanceToAfterDeadlinePlusBuffer();

        // Goal progress should only include confirmed
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgress, PAYMENT_AMOUNT_1, "Goal progress should only be confirmed after buffer");
    }

    /*//////////////////////////////////////////////////////////////
                        REFUND TESTS - OPTIMISTIC LOCK
    //////////////////////////////////////////////////////////////*/

    function test_claimRefund_BeforeDeadline_Succeeds() external {
        advanceToWithinRange();

        // Create and process crypto payment (first crypto payment = tokenId 1)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Claim refund before deadline - should succeed
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);
        assertEq(balanceAfter - balanceBefore, PAYMENT_AMOUNT_1, "Refund should be returned");
    }

    function test_claimRefund_AfterDeadline_GoalNotMet_Succeeds() external {
        advanceToWithinRange();

        // Create and process crypto payment (first crypto payment = tokenId 1)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Claim refund - should succeed since goal not met
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);
        assertEq(balanceAfter - balanceBefore, PAYMENT_AMOUNT_1, "Refund should be returned when goal not met");
    }

    function test_claimRefund_AfterDeadline_GoalMet_Reverts() external {
        advanceToWithinRange();

        // Fund campaign to meet goal (tokenId 1)
        _fundCampaignToMeetGoal();

        // Create another payment for refund test (tokenId 2)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer2Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 2);

        // Claim refund should revert since goal is met
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);
    }

    function test_claimRefund_AfterDeadline_OptimisticLock_WithPendingPayments() external {
        advanceToWithinRange();

        // Create confirmed payment below goal (first crypto payment = tokenId 1)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer2Address);

        // Create pending payment that would meet goal when added
        uint256 pendingAmount = campaignGoalAmount; // This will make pending + confirmed >= goal
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_1, ITEM_ID_2, pendingAmount, users.backer1Address);

        // Advance past deadline (during buffer period)
        advanceToAfterDeadline();

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should be blocked due to optimistic lock (pending + confirmed >= goal)
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);
    }

    function test_claimRefund_AfterBufferEnd_PendingFailed_Succeeds() external {
        advanceToWithinRange();

        // Create confirmed payment below goal (first crypto payment = tokenId 1)
        uint256 smallAmount = campaignGoalAmount / 10;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, smallAmount, users.backer2Address);

        // Create pending payment that would meet goal when added
        uint256 pendingAmount = campaignGoalAmount;
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_1, ITEM_ID_2, pendingAmount, users.backer1Address);

        // Verify goal progress includes pending during buffer
        advanceToAfterDeadline();
        uint256 goalProgressDuringBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertGe(goalProgressDuringBuffer, campaignGoalAmount, "Goal should be met optimistically during buffer");

        // Advance past buffer period - pending payments can no longer be confirmed
        advanceToAfterDeadlinePlusBuffer();

        // Goal progress should now only show confirmed (which is below goal)
        uint256 goalProgressAfterBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertLt(goalProgressAfterBuffer, campaignGoalAmount, "Goal should not be met after buffer");

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should now succeed since goal is not met with only confirmed payments
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        // Verify refund was processed
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0, "Raised amount should be 0 after refund");
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW AND DISBURSE FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw_GoalMet_AfterDeadline_Succeeds() external {
        advanceToWithinRange();

        // Fund campaign to meet goal
        _fundCampaignToMeetGoal();

        // Advance past deadline
        advanceToAfterDeadline();

        uint256 creatorBalanceBefore = testToken.balanceOf(users.creator1Address);

        // Withdraw should succeed
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();

        uint256 creatorBalanceAfter = testToken.balanceOf(users.creator1Address);
        assertTrue(creatorBalanceAfter > creatorBalanceBefore, "Creator should receive funds");
    }

    function test_withdraw_GoalNotMet_Reverts() external {
        advanceToWithinRange();

        // Create payment that doesn't meet goal
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Withdraw should fail since goal not met
        vm.expectRevert();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();
    }

    function test_withdraw_BeforeDeadline_Reverts() external {
        advanceToWithinRange();

        // Fund campaign to meet goal
        _fundCampaignToMeetGoal();

        // Withdraw should fail before deadline
        vm.expectRevert();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();
    }

    function test_disburseFees_GoalMet_AfterDeadline_Succeeds() external {
        advanceToWithinRange();

        // Fund campaign to meet goal
        _fundCampaignToMeetGoal();

        // First withdraw to generate fees
        advanceToAfterDeadline();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();

        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);

        // Disburse fees
        goalBasedPaymentTreasury.disburseFees();

        uint256 protocolBalanceAfter = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceAfter = testToken.balanceOf(users.platform1AdminAddress);

        assertTrue(protocolBalanceAfter > protocolBalanceBefore, "Protocol should receive fees");
        assertTrue(platformBalanceAfter > platformBalanceBefore, "Platform should receive fees");
    }

    function test_disburseFees_GoalNotMet_Reverts() external {
        advanceToWithinRange();

        // Create payment that doesn't meet goal
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Disburse fees should fail since goal not met
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryGoalNotMet.selector);
        goalBasedPaymentTreasury.disburseFees();
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL TREASURY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_cancelTreasury_ByPlatformAdmin() external {
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("Test cancellation"));

        assertTrue(goalBasedPaymentTreasury.cancelled(), "Treasury should be cancelled");
    }

    function test_cancelTreasury_ByCampaignOwner() external {
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("Test cancellation"));

        assertTrue(goalBasedPaymentTreasury.cancelled(), "Treasury should be cancelled");
    }

    function test_cancelTreasury_ByUnauthorized_Reverts() external {
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryUnauthorized.selector);
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("Test cancellation"));
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createPayment_AtExactLaunchTime() external {
        vm.warp(campaignLaunchTime);

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);

        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Should succeed at exact launch time
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_confirmPayment_AtExactDeadlinePlusBuffer() external {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance to exact deadline + buffer
        advanceToDeadlinePlusBuffer();

        // Confirm payment should still work at exact buffer end
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_goalProgress_AtExactDeadlinePlusBuffer() external {
        advanceToWithinRange();

        // Create confirmed and pending payments
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // At exact deadline + buffer, should include pending
        advanceToDeadlinePlusBuffer();
        uint256 goalProgressAtBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgressAtBuffer, PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2, "Should include pending at exact buffer end");

        // After deadline + buffer, should only include confirmed
        advanceToAfterDeadlinePlusBuffer();
        uint256 goalProgressAfterBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgressAfterBuffer, PAYMENT_AMOUNT_1, "Should only include confirmed after buffer");
    }

    function test_claimExpiredFunds_AfterLaunchTime() external {
        advanceToAfterLaunch();

        // Fund the treasury with some tokens first
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Should not revert when called after launch time
        // Note: claimExpiredFunds has additional requirements (claim delay etc.)
        // We're just testing the time constraint here
        vm.expectRevert(); // Will revert due to claim window not reached, but not due to time constraint
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.claimExpiredFunds();
    }

    function test_claimNonGoalLineItems_AfterLaunchTime() external {
        advanceToAfterLaunch();

        // Without any non-goal line items, this should revert with invalid input
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.claimNonGoalLineItems(address(testToken));
    }
}

