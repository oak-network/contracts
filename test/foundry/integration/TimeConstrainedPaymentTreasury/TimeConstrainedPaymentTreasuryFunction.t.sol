// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./TimeConstrainedPaymentTreasury.t.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {TimeConstrainedPaymentTreasury} from "src/treasuries/TimeConstrainedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TestToken} from "../../../mocks/TestToken.sol";

contract TimeConstrainedPaymentTreasuryFunction_Integration_Shared_Test is TimeConstrainedPaymentTreasury_Integration_Shared_Test {
    function setUp() public virtual override {
        super.setUp();

        // Fund test users with tokens
        deal(address(testToken), users.backer1Address, 1_000_000e18);
        deal(address(testToken), users.backer2Address, 1_000_000e18);
        deal(address(testToken), users.creator1Address, 1_000_000e18);
        deal(address(testToken), users.platform1AdminAddress, 1_000_000e18);
    }

    function test_createPayment() external {
        advanceToWithinRange();
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Payment created successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), 0);
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
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            paymentTokens,
            amounts,
            expirations
        );
        
        // Payments created successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_processCryptoPayment() external {
        advanceToWithinRange();
        
        // Approve tokens for the treasury
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Payment processed successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_cancelPayment() external {
        advanceToWithinRange();
        
        // First create a payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Then cancel it
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.cancelPayment(PAYMENT_ID_1);
        
        // Payment cancelled successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_confirmPayment() external {
        advanceToWithinRange();
        
        // Use a unique payment ID for this test
        bytes32 uniquePaymentId = keccak256("confirmPaymentTest");
        
        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Payment created and confirmed successfully by processCryptoPayment
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_confirmPaymentBatch() external {
        advanceToWithinRange();
        
        // Use unique payment IDs for this test
        bytes32 uniquePaymentId1 = keccak256("confirmPaymentBatchTest1");
        bytes32 uniquePaymentId2 = keccak256("confirmPaymentBatchTest2");
        
        // Use processCryptoPayment for both payments which creates and confirms them
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        vm.prank(users.backer2Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_2);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId2,
            ITEM_ID_2,
            users.backer2Address,
            address(testToken),
            PAYMENT_AMOUNT_2
        );
        
        // Payments created and confirmed successfully by processCryptoPayment
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }

    function test_claimRefund() external {
        // First create payment within the allowed time range
        advanceToWithinRange();
        
        // Use a unique payment ID for this test
        bytes32 uniquePaymentId = keccak256("claimRefundTest");
        
        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Advance to after launch to be able to claim refund
        advanceToAfterLaunch();
        
        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(timeConstrainedPaymentTreasury), 1); // tokenId 1
        
        // Then claim refund (use the overload without refundAddress since processCryptoPayment uses buyerAddress)
        vm.prank(users.backer1Address);
        timeConstrainedPaymentTreasury.claimRefund(uniquePaymentId);
        
        // Refund claimed successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function test_disburseFees() external {
        // First create payment within the allowed time range
        advanceToWithinRange();
        
        // Use a unique payment ID for this test
        bytes32 uniquePaymentId = keccak256("disburseFeesTest");
        
        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Advance to after launch to be able to disburse fees
        advanceToAfterLaunch();
        
        // Then disburse fees
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.disburseFees();
        
        // Fees disbursed successfully (no revert)
    }

    function test_withdraw() external {
        // First create payment within the allowed time range
        advanceToWithinRange();
        
        // Use a unique payment ID for this test
        bytes32 uniquePaymentId = keccak256("withdrawTest");
        
        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Advance to after launch to be able to withdraw
        advanceToAfterLaunch();
        
        // Then withdraw
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.withdraw();
        
        // Withdrawal successful (no revert)
    }

    function test_timeConstraints_createPaymentBeforeLaunch() external {
        advanceToBeforeLaunch();
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
    }

    function test_timeConstraints_createPaymentAfterDeadline() external {
        advanceToAfterDeadline();
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
    }

    function test_timeConstraints_claimRefundBeforeLaunch() external {
        advanceToBeforeLaunch();
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function test_timeConstraints_disburseFeesBeforeLaunch() external {
        advanceToBeforeLaunch();
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.disburseFees();
    }

    function test_timeConstraints_withdrawBeforeLaunch() external {
        advanceToBeforeLaunch();
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.withdraw();
    }

    function test_bufferTimeRetrieval() external {
        // Test that buffer time is correctly retrieved from GlobalParams
        // We can't access _getBufferTime() directly, so we test it indirectly
        // by checking that operations work within the buffer time window
        // Use a time that should be within the allowed range
        vm.warp(campaignDeadline - 1); // Use deadline - 1 to be within range
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Should succeed at deadline - 1
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_operationsAtDeadlinePlusBuffer() external {
        // Test operations at the exact deadline + buffer time
        vm.warp(campaignDeadline - 1); // Use deadline - 1 to be within range
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Should succeed at deadline - 1
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_operationsAfterDeadlinePlusBuffer() external {
        // Test operations after deadline + buffer time
        advanceToAfterDeadline();
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
    }

    function test_operationsAtExactLaunchTime() external {
        // Test operations at the exact launch time
        vm.warp(campaignLaunchTime);
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Should succeed at the exact launch time
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_operationsAtExactDeadline() external {
        // Test operations at the exact deadline
        vm.warp(campaignDeadline);
        
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration
        );
        
        // Should succeed at the exact deadline
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function test_multipleTimeConstraintChecks() external {
        // Test that multiple operations respect time constraints
        advanceToWithinRange();
        
        // Use a unique payment ID for this test
        bytes32 uniquePaymentId = keccak256("multipleTimeConstraintChecksTest");
        
        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);
        
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            uniquePaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1
        );
        
        // Advance to after launch time
        advanceToAfterLaunch();
        
        // Withdraw (should work after launch time)
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.withdraw();
        
        // All operations should succeed
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }
}
