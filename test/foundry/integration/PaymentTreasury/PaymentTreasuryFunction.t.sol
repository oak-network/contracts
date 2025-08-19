// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PaymentTreasury.t.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";

/**
 * @title PaymentTreasuryFunction_Integration_Test
 * @notice This contract contains integration tests for the happy-path functionality
 * of the PaymentTreasury contract. Each test focuses on a single core function.
 */
contract PaymentTreasuryFunction_Integration_Test is
    PaymentTreasury_Integration_Shared_Test
{
    /**
     * @notice Tests the successful confirmation of a single payment.
     */
    function test_confirmPayment() public {
        _createAndFundPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            users.backer1Address
        );
        assertEq(testToken.balanceOf(treasuryAddress), PAYMENT_AMOUNT_1);

        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);

        assertEq(
            paymentTreasury.getRaisedAmount(),
            PAYMENT_AMOUNT_1,
            "Raised amount should match the payment amount"
        );
        assertEq(
            paymentTreasury.getAvailableRaisedAmount(),
            PAYMENT_AMOUNT_1,
            "Available raised amount should match the payment amount"
        );
    }

    /**
     * @notice Tests the successful confirmation of multiple payments in a batch.
     */
    function test_confirmPaymentBatch() public {
        _createTestPayments(); // Creates PAYMENT_ID_1 and PAYMENT_ID_2
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        assertEq(testToken.balanceOf(treasuryAddress), totalAmount);

        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);

        assertEq(
            paymentTreasury.getRaisedAmount(),
            totalAmount,
            "Raised amount should match the total of batched payments"
        );
        assertEq(
            paymentTreasury.getAvailableRaisedAmount(),
            totalAmount,
            "Available raised amount should match the total of batched payments"
        );
    }

    /**
     * @notice Tests that a confirmed payment can be successfully refunded.
     */
    function test_claimRefund() public {
        _createAndFundPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            users.backer1Address
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        uint256 backerBalanceBefore = testToken.balanceOf(users.backer1Address);

        uint256 refundAmount = claimRefund(
            users.platform1AdminAddress,
            PAYMENT_ID_1,
            users.backer1Address
        );

        // Assert: The refund amount is correct and all balances are updated as expected.
        assertEq(refundAmount, PAYMENT_AMOUNT_1, "Refunded amount is incorrect");
        assertEq(
            testToken.balanceOf(users.backer1Address),
            backerBalanceBefore + PAYMENT_AMOUNT_1,
            "Backer did not receive the correct refund amount"
        );
        assertEq(paymentTreasury.getRaisedAmount(), 0, "Raised amount should be zero after refund");
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0, "Available amount should be zero after refund");
        assertEq(testToken.balanceOf(treasuryAddress), 0, "Treasury token balance should be zero after refund");
    }
    
    /**
     * @notice Tests the correct disbursement of fees to the protocol and platform.
     */
    function test_disburseFees() public {
        _createTestPayments();
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);

        uint256 protocolAdminBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);
        uint256 treasuryAvailableAmountBefore = paymentTreasury.getAvailableRaisedAmount();

        (uint256 protocolShare, uint256 platformShare) = disburseFees(treasuryAddress);

        // Assert: Fees are calculated and transferred correctly.
        uint256 expectedProtocolShare = (totalAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedPlatformShare = (totalAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;

        assertEq(protocolShare, expectedProtocolShare, "Incorrect protocol fee disbursed");
        assertEq(platformShare, expectedPlatformShare, "Incorrect platform fee disbursed");

        assertEq(
            testToken.balanceOf(users.protocolAdminAddress),
            protocolAdminBalanceBefore + expectedProtocolShare,
            "Protocol admin did not receive correct fee amount"
        );
        assertEq(
            testToken.balanceOf(users.platform1AdminAddress),
            platformAdminBalanceBefore + expectedPlatformShare,
            "Platform admin did not receive correct fee amount"
        );
        assertEq(
            paymentTreasury.getAvailableRaisedAmount(),
            treasuryAvailableAmountBefore - protocolShare - platformShare,
            "Treasury available amount not reduced correctly after disbursing fees"
        );
    }

    /**
     * @notice Tests the final withdrawal of funds by the campaign owner after fees have been disbursed.
     */
    function test_withdraw() public {
        _createTestPayments();
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);
        (uint256 protocolShare, uint256 platformShare) = disburseFees(treasuryAddress);

        address campaignOwner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(campaignOwner);

        (address recipient, uint256 withdrawnAmount) = withdraw(treasuryAddress);
        uint256 ownerBalanceAfter = testToken.balanceOf(campaignOwner);

        // Check that the correct amount is withdrawn to the campaign owner's address.
        uint256 expectedWithdrawalAmount = totalAmount - protocolShare - platformShare;
        assertEq(recipient, campaignOwner, "Funds withdrawn to incorrect address");
        assertEq(withdrawnAmount, expectedWithdrawalAmount, "Incorrect amount withdrawn");
        assertEq(
            ownerBalanceAfter - ownerBalanceBefore, 
            expectedWithdrawalAmount, 
            "Campaign owner did not receive correct withdrawn amount"
        );
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0, "Available amount should be zero after withdrawal");
        assertEq(testToken.balanceOf(treasuryAddress), 0, "Treasury token balance should be zero after withdrawal");
    }
}
