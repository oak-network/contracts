// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./PaymentTreasury.t.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";
import {TestToken} from "../../../mocks/TestToken.sol";

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

        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1); // Removed token parameter

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
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds); // Removed token array

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

        // Verify the refund amount is correct and all balances are updated as expected.
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
     * @notice Tests the processing of a crypto payment.
     */
    function test_processCryptoPayment() public {
        uint256 amount = 1500e18;
        deal(address(testToken), users.backer1Address, amount);
        
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, amount);
        
        processCryptoPayment(users.backer1Address, PAYMENT_ID_1, ITEM_ID_1, users.backer1Address, address(testToken), amount);
        
        assertEq(paymentTreasury.getRaisedAmount(), amount, "Raised amount should match crypto payment");
        assertEq(paymentTreasury.getAvailableRaisedAmount(), amount, "Available amount should match crypto payment");
        assertEq(testToken.balanceOf(treasuryAddress), amount, "Treasury should hold the tokens");
    }

    /**
     * @notice Tests buyer-initiated refund for crypto payment.
     */
    function test_claimRefundBuyerInitiated() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);
        
        uint256 buyerBalanceBefore = testToken.balanceOf(users.backer1Address);
        uint256 refundAmount = claimRefund(users.backer1Address, PAYMENT_ID_1);
        
        assertEq(refundAmount, amount, "Refund amount should match payment");
        assertEq(
            testToken.balanceOf(users.backer1Address),
            buyerBalanceBefore + amount,
            "Buyer should receive refund"
        );
        assertEq(paymentTreasury.getRaisedAmount(), 0, "Raised amount should be zero after refund");
    }
    
    /**
     * @notice Tests the final withdrawal of funds by the campaign owner after fees have been calculated.
     */
    function test_withdraw() public {
        _createTestPayments();
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);

        address campaignOwner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(campaignOwner);

        (address recipient, uint256 withdrawnAmount, uint256 fee) = withdraw(treasuryAddress);
        uint256 ownerBalanceAfter = testToken.balanceOf(campaignOwner);

        // Check that the correct amount is withdrawn to the campaign owner's address.
        uint256 expectedProtocolFee = (totalAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedPlatformFee = (totalAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedTotalFee = expectedProtocolFee + expectedPlatformFee;
        uint256 expectedWithdrawalAmount = totalAmount - expectedTotalFee;

        assertEq(recipient, campaignOwner, "Funds withdrawn to incorrect address");
        assertEq(withdrawnAmount, expectedWithdrawalAmount, "Incorrect amount withdrawn");
        assertEq(fee, expectedTotalFee, "Incorrect fee amount");
        assertEq(
            ownerBalanceAfter - ownerBalanceBefore, 
            expectedWithdrawalAmount, 
            "Campaign owner did not receive correct withdrawn amount"
        );
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0, "Available amount should be zero after withdrawal");
    }

    /**
     * @notice Tests the correct disbursement of fees to the protocol and platform after withdrawal.
     */
    function test_disburseFeesAfterWithdraw() public {
        _createTestPayments();
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);
        
        // Withdraw first to calculate fees
        withdraw(treasuryAddress);

        uint256 protocolAdminBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);

        (uint256 protocolShare, uint256 platformShare) = disburseFees(treasuryAddress);

        // Verify fees are calculated and transferred correctly.
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
        
        assertEq(testToken.balanceOf(treasuryAddress), 0, "Treasury should have zero balance after disbursing fees");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-TOKEN FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_confirmPaymentWithMultipleTokens() public {
        // Create payments with different tokens
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PAYMENT_AMOUNT_1);
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PAYMENT_AMOUNT_2);
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            usdcAmount,
            users.backer2Address,
            address(usdcToken)
        );
        
        // Confirm without specifying token (already set during creation)
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2);
        
        // Verify normalized raised amount
        uint256 expectedNormalized = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        assertEq(
            paymentTreasury.getRaisedAmount(),
            expectedNormalized,
            "Raised amount should be normalized sum"
        );
    }

    function test_getRaisedAmountNormalizesCorrectly() public {
        // Create payments with same base amount in different tokens
        uint256 baseAmount = 1000e18;
        uint256 usdtAmount = baseAmount / 1e12; // 6 decimals
        uint256 cUSDAmount = baseAmount;        // 18 decimals
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        
        uint256 raisedAfterUSDT = paymentTreasury.getRaisedAmount();
        assertEq(raisedAfterUSDT, baseAmount, "USDT should normalize to base amount");
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            cUSDAmount,
            users.backer2Address,
            address(cUSDToken)
        );
        
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2);
        
        uint256 raisedAfterCUSD = paymentTreasury.getRaisedAmount();
        assertEq(raisedAfterCUSD, baseAmount * 2, "Total should be sum of normalized amounts");
    }

    function test_batchConfirmWithMultipleTokens() public {
        // Create payments with different tokens
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 500e18);
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 700e18);
        uint256 cUSDAmount = 900e18;
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            usdcAmount,
            users.backer2Address,
            address(usdcToken)
        );
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_3,
            BUYER_ID_1,
            ITEM_ID_1,
            cUSDAmount,
            users.backer1Address,
            address(cUSDToken)
        );
        
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;
        
        // Batch confirm without token array (tokens already set during creation)
        confirmPaymentBatch(users.platform1AdminAddress, paymentIds);
        
        uint256 expectedTotal = 500e18 + 700e18 + 900e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal, "Should sum all normalized amounts");
    }

    function test_processCryptoPaymentWithMultipleTokens() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 800e18);
        uint256 cUSDAmount = 1200e18;
        
        // Process USDT payment
        _createAndProcessCryptoPaymentWithToken(
            PAYMENT_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        
        // Process cUSD payment
        _createAndProcessCryptoPaymentWithToken(
            PAYMENT_ID_2,
            ITEM_ID_2,
            cUSDAmount,
            users.backer2Address,
            address(cUSDToken)
        );
        
        uint256 expectedTotal = 800e18 + 1200e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal, "Should track both crypto payments");
        assertEq(usdtToken.balanceOf(treasuryAddress), usdtAmount, "Should hold USDT");
        assertEq(cUSDToken.balanceOf(treasuryAddress), cUSDAmount, "Should hold cUSD");
    }

    function test_refundReturnsCorrectToken() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PAYMENT_AMOUNT_1);
        uint256 cUSDAmount = PAYMENT_AMOUNT_2;
        
        // Create and confirm USDT payment
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1); // No token parameter
        
        // Create and confirm cUSD payment
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            cUSDAmount,
            users.backer2Address,
            address(cUSDToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2); // No token parameter
        
        uint256 backer1USDTBefore = usdtToken.balanceOf(users.backer1Address);
        uint256 backer2CUSDBefore = cUSDToken.balanceOf(users.backer2Address);
        
        // Claim refunds
        uint256 refund1 = claimRefund(users.platform1AdminAddress, PAYMENT_ID_1, users.backer1Address);
        uint256 refund2 = claimRefund(users.platform1AdminAddress, PAYMENT_ID_2, users.backer2Address);
        
        // Verify correct tokens refunded
        assertEq(refund1, usdtAmount, "Should refund USDT amount");
        assertEq(refund2, cUSDAmount, "Should refund cUSD amount");
        assertEq(
            usdtToken.balanceOf(users.backer1Address) - backer1USDTBefore,
            usdtAmount,
            "Should receive USDT"
        );
        assertEq(
            cUSDToken.balanceOf(users.backer2Address) - backer2CUSDBefore,
            cUSDAmount,
            "Should receive cUSD"
        );
        
        // Verify no cross-token contamination
        assertEq(cUSDToken.balanceOf(users.backer1Address), TOKEN_MINT_AMOUNT, "Backer1 shouldn't have cUSD changes");
        assertEq(usdtToken.balanceOf(users.backer2Address), TOKEN_MINT_AMOUNT / 1e12, "Backer2 shouldn't have USDT changes");
    }

    function test_cryptoPaymentRefundWithMultipleTokens() public {
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 1500e18);
        uint256 cUSDAmount = 2000e18;
        
        // Process crypto payments
        _createAndProcessCryptoPaymentWithToken(
            PAYMENT_ID_1,
            ITEM_ID_1,
            usdcAmount,
            users.backer1Address,
            address(usdcToken)
        );
        
        _createAndProcessCryptoPaymentWithToken(
            PAYMENT_ID_2,
            ITEM_ID_2,
            cUSDAmount,
            users.backer2Address,
            address(cUSDToken)
        );
        
        uint256 backer1USDCBefore = usdcToken.balanceOf(users.backer1Address);
        uint256 backer2CUSDBefore = cUSDToken.balanceOf(users.backer2Address);
        
        // Buyers claim their own refunds
        uint256 refund1 = claimRefund(users.backer1Address, PAYMENT_ID_1);
        uint256 refund2 = claimRefund(users.backer2Address, PAYMENT_ID_2);
        
        assertEq(refund1, usdcAmount, "Should refund USDC amount");
        assertEq(refund2, cUSDAmount, "Should refund cUSD amount");
        assertEq(usdcToken.balanceOf(users.backer1Address) - backer1USDCBefore, usdcAmount);
        assertEq(cUSDToken.balanceOf(users.backer2Address) - backer2CUSDBefore, cUSDAmount);
    }

    function test_withdrawWithMultipleTokens() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 1000e18);
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 1500e18);
        uint256 cUSDAmount = 2000e18;
        
        // Create and confirm payments with different tokens
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            usdcAmount,
            users.backer2Address,
            address(usdcToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2);
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_3,
            BUYER_ID_1,
            ITEM_ID_1,
            cUSDAmount,
            users.backer1Address,
            address(cUSDToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_3);
        
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        uint256 ownerUSDTBefore = usdtToken.balanceOf(campaignOwner);
        uint256 ownerUSDCBefore = usdcToken.balanceOf(campaignOwner);
        uint256 ownerCUSDBefore = cUSDToken.balanceOf(campaignOwner);
        
        // Withdraw all tokens
        withdraw(treasuryAddress);
        
        // Verify owner received all tokens (minus fees)
        assertTrue(usdtToken.balanceOf(campaignOwner) > ownerUSDTBefore, "Should receive USDT");
        assertTrue(usdcToken.balanceOf(campaignOwner) > ownerUSDCBefore, "Should receive USDC");
        assertTrue(cUSDToken.balanceOf(campaignOwner) > ownerCUSDBefore, "Should receive cUSD");
        
        // Verify available amount is zero
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0, "Should have zero available after withdrawal");
    }

    function test_disburseFeesWithMultipleTokens() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PAYMENT_AMOUNT_1);
        uint256 cUSDAmount = PAYMENT_AMOUNT_2;
        
        // Create and confirm payments
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            cUSDAmount,
            users.backer2Address,
            address(cUSDToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2);
        
        // Withdraw to calculate fees
        withdraw(treasuryAddress);
        
        uint256 protocolUSDTBefore = usdtToken.balanceOf(users.protocolAdminAddress);
        uint256 protocolCUSDBefore = cUSDToken.balanceOf(users.protocolAdminAddress);
        uint256 platformUSDTBefore = usdtToken.balanceOf(users.platform1AdminAddress);
        uint256 platformCUSDBefore = cUSDToken.balanceOf(users.platform1AdminAddress);
        
        // Disburse fees
        disburseFees(treasuryAddress);
        
        // Verify fees distributed for both tokens
        uint256 expectedUSDTProtocolFee = (usdtAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedUSDTPlatformFee = (usdtAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedCUSDProtocolFee = (cUSDAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedCUSDPlatformFee = (cUSDAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        
        assertEq(
            usdtToken.balanceOf(users.protocolAdminAddress) - protocolUSDTBefore,
            expectedUSDTProtocolFee,
            "USDT protocol fee incorrect"
        );
        assertEq(
            cUSDToken.balanceOf(users.protocolAdminAddress) - protocolCUSDBefore,
            expectedCUSDProtocolFee,
            "cUSD protocol fee incorrect"
        );
        assertEq(
            usdtToken.balanceOf(users.platform1AdminAddress) - platformUSDTBefore,
            expectedUSDTPlatformFee,
            "USDT platform fee incorrect"
        );
        assertEq(
            cUSDToken.balanceOf(users.platform1AdminAddress) - platformCUSDBefore,
            expectedCUSDPlatformFee,
            "cUSD platform fee incorrect"
        );
        
        // Treasury should be empty
        assertEq(usdtToken.balanceOf(treasuryAddress), 0, "USDT should be fully disbursed");
        assertEq(cUSDToken.balanceOf(treasuryAddress), 0, "cUSD should be fully disbursed");
    }

    function test_mixedPaymentTypesWithMultipleTokens() public {
        // Regular payment with USDT
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 1000e18);
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount,
            users.backer1Address,
            address(usdtToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        
        // Crypto payment with USDC
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 1500e18);
        _createAndProcessCryptoPaymentWithToken(
            PAYMENT_ID_2,
            ITEM_ID_2,
            usdcAmount,
            users.backer2Address,
            address(usdcToken)
        );
        
        // Regular payment with cUSD
        uint256 cUSDAmount = 2000e18;
        _createAndFundPaymentWithToken(
            PAYMENT_ID_3,
            BUYER_ID_1,
            ITEM_ID_1,
            cUSDAmount,
            users.backer1Address,
            address(cUSDToken)
        );
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_3);
        
        // Verify all contribute to raised amount
        uint256 expectedTotal = 1000e18 + 1500e18 + 2000e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal, "Should sum all payment types");
        
        // Withdraw and disburse
        withdraw(treasuryAddress);
        disburseFees(treasuryAddress);
        
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function test_revertWhenCreatingWithUnacceptedToken() public {
        // Create a token not in the accepted list
        TestToken rejectedToken = new TestToken("Rejected", "REJ", 18);
        uint256 amount = 1000e18;
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        
        // Try to create payment with unaccepted token
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(rejectedToken),
            amount,
            expiration
        );
    }

    function test_revertWhenTokenNotAccepted() public {
        // Create a token not in the accepted list
        TestToken rejectedToken = new TestToken("Rejected", "REJ", 18);
        uint256 amount = 1000e18;
        rejectedToken.mint(users.backer1Address, amount);
        
        vm.prank(users.backer1Address);
        rejectedToken.approve(treasuryAddress, amount);
        
        // Try to process crypto payment with unaccepted token
        vm.expectRevert();
        processCryptoPayment(
            users.backer1Address,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(rejectedToken),
            amount
        );
    }

    function test_balanceTrackingAcrossMultipleTokens() public {
        // Create multiple payments with different tokens
        uint256 usdtAmount1 = getTokenAmount(address(usdtToken), 500e18);
        uint256 usdtAmount2 = getTokenAmount(address(usdtToken), 300e18);
        uint256 cUSDAmount = 1000e18;
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            usdtAmount1,
            users.backer1Address,
            address(usdtToken)
        );
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            usdtAmount2,
            users.backer2Address,
            address(usdtToken)
        );
        
        _createAndFundPaymentWithToken(
            PAYMENT_ID_3,
            BUYER_ID_1,
            ITEM_ID_1,
            cUSDAmount,
            users.backer1Address,
            address(cUSDToken)
        );
        
        // Confirm all payments
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_1);
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_2);
        confirmPayment(users.platform1AdminAddress, PAYMENT_ID_3);
        
        // Verify raised amounts
        uint256 expectedTotal = 500e18 + 300e18 + 1000e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal, "Should track total correctly");
        
        // Refund one USDT payment
        claimRefund(users.platform1AdminAddress, PAYMENT_ID_1, users.backer1Address);
        
        uint256 afterRefund = 300e18 + 1000e18;
        assertEq(paymentTreasury.getRaisedAmount(), afterRefund, "Should update after refund");
        
        // Verify token balances
        assertEq(
            usdtToken.balanceOf(treasuryAddress),
            usdtAmount2,
            "Should only have remaining USDT"
        );
        assertEq(
            cUSDToken.balanceOf(treasuryAddress),
            cUSDAmount,
            "cUSD should be unchanged"
        );
    }
}