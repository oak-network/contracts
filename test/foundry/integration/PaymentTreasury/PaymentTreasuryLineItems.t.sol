// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./PaymentTreasury.t.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";

/// @notice Tests for PaymentTreasury with line items and expiration
contract PaymentTreasuryLineItems_Test is PaymentTreasury_Integration_Shared_Test {
    // Line item type IDs
    bytes32 internal constant SHIPPING_FEE_TYPE_ID = keccak256("shipping_fee");
    bytes32 internal constant TIP_TYPE_ID = keccak256("tip");
    bytes32 internal constant INTEREST_TYPE_ID = keccak256("interest");
    bytes32 internal constant REFUNDABLE_FEE_WITH_PROTOCOL_TYPE_ID = keccak256("refundable_fee_with_protocol");

    function setUp() public override {
        super.setUp();
        
        // Register line item types
        vm.prank(users.platform1AdminAddress);
        globalParams.setPlatformLineItemType(
            PLATFORM_1_HASH,
            SHIPPING_FEE_TYPE_ID,
            "shipping_fee",
            true,  // countsTowardGoal
            false, // applyProtocolFee
            true,  // canRefund
            false  // instantTransfer
        );

        vm.prank(users.platform1AdminAddress);
        globalParams.setPlatformLineItemType(
            PLATFORM_1_HASH,
            TIP_TYPE_ID,
            "tip",
            false, // countsTowardGoal
            false, // applyProtocolFee
            false, // canRefund
            true   // instantTransfer
        );

        vm.prank(users.platform1AdminAddress);
        globalParams.setPlatformLineItemType(
            PLATFORM_1_HASH,
            INTEREST_TYPE_ID,
            "interest",
            false, // countsTowardGoal
            true,  // applyProtocolFee
            false, // canRefund
            false  // instantTransfer
        );

        vm.prank(users.platform1AdminAddress);
        globalParams.setPlatformLineItemType(
            PLATFORM_1_HASH,
            REFUNDABLE_FEE_WITH_PROTOCOL_TYPE_ID,
            "refundable_fee_with_protocol",
            false, // countsTowardGoal
            true,  // applyProtocolFee
            true,  // canRefund
            false  // instantTransfer
        );
    }

    /*//////////////////////////////////////////////////////////////
                        LINE ITEMS - CREATE PAYMENT
    //////////////////////////////////////////////////////////////*/

    function test_createPaymentWithShippingFee() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        uint256 shippingFeeAmount = 50e18;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: shippingFeeAmount
        });

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Shipping fee counts toward goal, so it should be tracked in pending payments
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function test_createPaymentWithTip() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        uint256 tipAmount = 25e18;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: tipAmount
        });

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Tip doesn't count toward goal, so it should be tracked separately
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_createPaymentWithInterest() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        uint256 interestAmount = 100e18;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: INTEREST_TYPE_ID,
            amount: interestAmount
        });

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Interest doesn't count toward goal but applies protocol fee
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_createPaymentWithMultipleLineItems() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        uint256 shippingFeeAmount = 50e18;
        uint256 tipAmount = 25e18;
        uint256 interestAmount = 100e18;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](3);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: shippingFeeAmount
        });
        lineItems[1] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: tipAmount
        });
        lineItems[2] = ICampaignPaymentTreasury.LineItem({
            typeId: INTEREST_TYPE_ID,
            amount: interestAmount
        });

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_createPaymentRevertWhenLineItemTypeDoesNotExist() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        bytes32 nonExistentTypeId = keccak256("non_existent");
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: nonExistentTypeId,
            amount: 50e18
        });

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function test_createPaymentRevertWhenLineItemHasZeroTypeId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: bytes32(0),
            amount: 50e18
        });

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function test_createPaymentRevertWhenLineItemHasZeroAmount() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: 0
        });

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                    LINE ITEMS - PROCESS CRYPTO PAYMENT
    //////////////////////////////////////////////////////////////*/

    function test_processCryptoPaymentWithShippingFee() public {
        uint256 shippingFeeAmount = 50e18;
        uint256 totalAmount = PAYMENT_AMOUNT_1 + shippingFeeAmount;
        
        deal(address(testToken), users.backer1Address, totalAmount);
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, totalAmount);

        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: shippingFeeAmount
        });

        vm.prank(users.backer1Address);
        paymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            lineItems
        , new ICampaignPaymentTreasury.ExternalFees[](0));

        // Payment should be confirmed immediately for crypto payments
        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + shippingFeeAmount);
        assertEq(testToken.balanceOf(treasuryAddress), totalAmount);
    }

    function test_processCryptoPaymentWithTip() public {
        uint256 tipAmount = 25e18;
        uint256 totalAmount = PAYMENT_AMOUNT_1 + tipAmount;
        
        deal(address(testToken), users.backer1Address, totalAmount);
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, totalAmount);

        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);

        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: tipAmount
        });

        vm.prank(users.backer1Address);
        paymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            lineItems
        , new ICampaignPaymentTreasury.ExternalFees[](0));

        // Tip doesn't count toward goal, but payment amount does
        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        // Tip is instantly transferred to platform admin, so treasury only holds payment amount
        assertEq(testToken.balanceOf(treasuryAddress), PAYMENT_AMOUNT_1);
        // Platform admin received the tip
        assertEq(testToken.balanceOf(users.platform1AdminAddress), platformAdminBalanceBefore + tipAmount);
    }

    function test_processCryptoPaymentWithMultipleLineItems() public {
        uint256 shippingFeeAmount = 50e18;
        uint256 tipAmount = 25e18;
        uint256 interestAmount = 100e18;
        uint256 totalAmount = PAYMENT_AMOUNT_1 + shippingFeeAmount + tipAmount + interestAmount;
        
        deal(address(testToken), users.backer1Address, totalAmount);
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, totalAmount);

        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);
        uint256 tipNetAmount = tipAmount; // No protocol fee on tip

        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](3);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: shippingFeeAmount
        });
        lineItems[1] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: tipAmount
        });
        lineItems[2] = ICampaignPaymentTreasury.LineItem({
            typeId: INTEREST_TYPE_ID,
            amount: interestAmount
        });

        vm.prank(users.backer1Address);
        paymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            lineItems
        , new ICampaignPaymentTreasury.ExternalFees[](0));

        // Only payment amount + shipping fee count toward goal
        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + shippingFeeAmount);
        // Treasury holds: payment amount + shipping fee + interest (full amount, protocol fee tracked separately)
        // Tip is instantly transferred to platform admin
        assertEq(testToken.balanceOf(treasuryAddress), PAYMENT_AMOUNT_1 + shippingFeeAmount + interestAmount);
        // Platform admin received the tip instantly
        assertEq(testToken.balanceOf(users.platform1AdminAddress), platformAdminBalanceBefore + tipNetAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            EXPIRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createPaymentWithValidExpiration() public {
        uint256 expiration = block.timestamp + 1 days;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_createPaymentRevertWhenExpirationInPast() public {
        uint256 expiration = block.timestamp - 1;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
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

    function test_createPaymentRevertWhenExpirationIsCurrentTime() public {
        uint256 expiration = block.timestamp;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
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

    function test_createPaymentWithLongExpiration() public {
        uint256 expiration = block.timestamp + 365 days;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_cancelPaymentRevertWhenExpired() public {
        uint256 expiration = block.timestamp + 1 hours;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Advance time past expiration
        vm.warp(block.timestamp + 2 hours);

        // Should revert when trying to cancel expired payment
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    function test_confirmPaymentBeforeExpiration() public {
        uint256 expiration = block.timestamp + 1 days;
        
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Fund the payment
        deal(address(testToken), users.backer1Address, PAYMENT_AMOUNT_1);
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, PAYMENT_AMOUNT_1);

        // Should be able to confirm before expiration
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function test_getPaymentDataIncludesLineItemsAndExternalFees() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        uint256 shippingFeeAmount = 50e18;
        uint256 tipAmount = 25e18;

        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](2);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: shippingFeeAmount
        });
        lineItems[1] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: tipAmount
        });

        ICampaignPaymentTreasury.ExternalFees[] memory externalFees = new ICampaignPaymentTreasury.ExternalFees[](2);
        externalFees[0] = ICampaignPaymentTreasury.ExternalFees({
            feeType: keccak256(abi.encodePacked("gateway_fee")),
            feeAmount: 15e18
        });
        externalFees[1] = ICampaignPaymentTreasury.ExternalFees({
            feeType: keccak256(abi.encodePacked("processing_fee")),
            feeAmount: 5e18
        });

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            lineItems,
            externalFees
        );

        ICampaignPaymentTreasury.PaymentData memory paymentData = paymentTreasury.getPaymentData(PAYMENT_ID_1);

        assertEq(paymentData.buyerId, BUYER_ID_1);
        assertEq(paymentData.itemId, ITEM_ID_1);
        assertEq(paymentData.amount, PAYMENT_AMOUNT_1);
        assertEq(paymentData.expiration, expiration);
        assertFalse(paymentData.isConfirmed);
        assertFalse(paymentData.isCryptoPayment);
        assertEq(paymentData.lineItemCount, lineItems.length);
        assertEq(paymentData.paymentToken, address(testToken));

        assertEq(paymentData.lineItems.length, lineItems.length);
        assertEq(paymentData.lineItems[0].typeId, SHIPPING_FEE_TYPE_ID);
        assertEq(paymentData.lineItems[0].amount, shippingFeeAmount);
        assertEq(keccak256(bytes(paymentData.lineItems[0].label)), keccak256(bytes("shipping_fee")));
        assertTrue(paymentData.lineItems[0].countsTowardGoal);
        assertFalse(paymentData.lineItems[0].applyProtocolFee);
        assertTrue(paymentData.lineItems[0].canRefund);
        assertFalse(paymentData.lineItems[0].instantTransfer);

        assertEq(paymentData.lineItems[1].typeId, TIP_TYPE_ID);
        assertEq(paymentData.lineItems[1].amount, tipAmount);
        assertEq(keccak256(bytes(paymentData.lineItems[1].label)), keccak256(bytes("tip")));
        assertFalse(paymentData.lineItems[1].countsTowardGoal);
        assertFalse(paymentData.lineItems[1].applyProtocolFee);
        assertFalse(paymentData.lineItems[1].canRefund);
        assertTrue(paymentData.lineItems[1].instantTransfer);

        assertEq(paymentData.externalFees.length, externalFees.length);
        assertEq(paymentData.externalFees[0].feeType, externalFees[0].feeType);
        assertEq(paymentData.externalFees[0].feeAmount, externalFees[0].feeAmount);
        assertEq(paymentData.externalFees[1].feeType, externalFees[1].feeType);
        assertEq(paymentData.externalFees[1].feeAmount, externalFees[1].feeAmount);
    }

    function test_processCryptoPaymentRefundableNonGoalWithProtocolFee() public {
        uint256 baseAmount = PAYMENT_AMOUNT_1;
        uint256 lineItemAmount = 200e18;
        uint256 totalAmount = baseAmount + lineItemAmount;

        deal(address(testToken), users.backer1Address, totalAmount);

        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, totalAmount);

        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({
            typeId: REFUNDABLE_FEE_WITH_PROTOCOL_TYPE_ID,
            amount: lineItemAmount
        });

        bytes32 paymentId = keccak256("refundableFeePayment");

        vm.prank(users.backer1Address);
        paymentTreasury.processCryptoPayment(
            paymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            baseAmount,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        uint256 buyerBalanceAfterPayment = testToken.balanceOf(users.backer1Address);

        uint256 expectedFee = (lineItemAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedNetLineItem = lineItemAmount - expectedFee;
        uint256 expectedRefund = baseAmount + expectedNetLineItem;

        vm.prank(users.backer1Address);
        // Approve treasury to burn NFT
        CampaignInfo(campaignAddress).approve(address(paymentTreasury), 1);
        paymentTreasury.claimRefund(paymentId);

        assertEq(
            testToken.balanceOf(users.backer1Address),
            buyerBalanceAfterPayment + expectedRefund
        );
        assertEq(testToken.balanceOf(treasuryAddress), expectedFee);
    }

    /*//////////////////////////////////////////////////////////////
                    LINE ITEMS - BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_createPaymentBatchWithLineItems() public {
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
        
        ICampaignPaymentTreasury.LineItem[][] memory lineItemsArray = new ICampaignPaymentTreasury.LineItem[][](2);
        
        // First payment with shipping fee
        lineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](1);
        lineItemsArray[0][0] = ICampaignPaymentTreasury.LineItem({
            typeId: SHIPPING_FEE_TYPE_ID,
            amount: 50e18
        });
        
        // Second payment with tip
        lineItemsArray[1] = new ICampaignPaymentTreasury.LineItem[](1);
        lineItemsArray[1][0] = ICampaignPaymentTreasury.LineItem({
            typeId: TIP_TYPE_ID,
            amount: 25e18
        });

        vm.prank(users.platform1AdminAddress);
            ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray = new ICampaignPaymentTreasury.ExternalFees[][](2);
            externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);
            externalFeesArray[1] = new ICampaignPaymentTreasury.ExternalFees[](0);
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            paymentTokens,
            amounts,
            expirations,
            lineItemsArray,
            externalFeesArray
        );

        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function test_createPaymentBatchRevertWhenLineItemsArrayLengthMismatch() public {
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
        
        // Wrong length - only 1 item instead of 2
        ICampaignPaymentTreasury.LineItem[][] memory lineItemsArray = new ICampaignPaymentTreasury.LineItem[][](1);
        lineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        // Also wrong length for externalFeesArray to match the test intent
        ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray = new ICampaignPaymentTreasury.ExternalFees[][](1);
        externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            paymentTokens,
            amounts,
            expirations,
            lineItemsArray,
            externalFeesArray
        );
    }
}

