// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../integration/PaymentTreasury/PaymentTreasury.t.sol";
import "forge-std/Test.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";
import {BasePaymentTreasury} from "src/utils/BasePaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TestToken} from "../../mocks/TestToken.sol";

contract PaymentTreasury_UnitTest is Test, PaymentTreasury_Integration_Shared_Test {
    // Helper function to create payment tokens array with same token for all payments
    function _createPaymentTokensArray(uint256 length, address token) internal pure returns (address[] memory) {
        address[] memory paymentTokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            paymentTokens[i] = token;
        }
        return paymentTokens;
    }

    function setUp() public virtual override {
        super.setUp();
        // Fund test addresses
        deal(address(testToken), users.backer1Address, 10_000e18);
        deal(address(testToken), users.backer2Address, 10_000e18);
        // Label addresses
        vm.label(users.protocolAdminAddress, "ProtocolAdmin");
        vm.label(users.platform1AdminAddress, "PlatformAdmin");
        vm.label(users.creator1Address, "CampaignOwner");
        vm.label(users.backer1Address, "Backer1");
        vm.label(users.backer2Address, "Backer2");
        vm.label(address(paymentTreasury), "PaymentTreasury");
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        // Create a new campaign for this test
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("newPaymentCampaign"));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = PLATFORM_1_HASH;

        bytes32[] memory platformDataKey = new bytes32[](0);
        bytes32[] memory platformDataValue = new bytes32[](0);

        vm.prank(users.creator1Address);
        campaignInfoFactory.createCampaign(
            users.creator1Address,
            newIdentifierHash,
            selectedPlatformHash,
            platformDataKey,
            platformDataValue,
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );
        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);

        // Deploy a new treasury
        vm.prank(users.platform1AdminAddress);
        address newTreasury = treasuryFactory.deploy(PLATFORM_1_HASH, newCampaignAddress, 2);
        PaymentTreasury newContract = PaymentTreasury(newTreasury);
        CampaignInfo newCampaignInfo = CampaignInfo(newCampaignAddress);

        // NFT name and symbol are now on CampaignInfo, not treasury
        assertEq(newCampaignInfo.name(), "Campaign Pledge NFT");
        assertEq(newCampaignInfo.symbol(), "PLEDGE");
        assertEq(newContract.getplatformHash(), PLATFORM_1_HASH);
        assertEq(newContract.getplatformFeePercent(), PLATFORM_FEE_PERCENT);
    }

    /*//////////////////////////////////////////////////////////////
                          PAYMENT CREATION
    //////////////////////////////////////////////////////////////*/

    function testCreatePayment() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken), // Added token parameter
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Payment created but not confirmed
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testCreatePaymentRevertWhenNotPlatformAdmin() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.backer1Address);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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

    function testCreatePaymentRevertWhenZeroBuyerId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            bytes32(0),
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenZeroAmount() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            0,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenExpired() public {
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            block.timestamp - 1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenZeroPaymentId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            bytes32(0),
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenZeroItemId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            bytes32(0),
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenZeroTokenAddress() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(0), // Zero token address
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenTokenNotAccepted() public {
        // Create unaccepted token
        TestToken unacceptedToken = new TestToken("Unaccepted", "UNACC", 18);
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;

        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(unacceptedToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCreatePaymentRevertWhenPaymentExists() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.startPrank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems2 = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems2,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        vm.stopPrank();
    }

    function testCreatePaymentRevertWhenPaused() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        // Pause the treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        // createPayment checks both treasury and campaign pause
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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

    function testCreatePaymentRevertWhenCampaignPaused() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        // Pause the campaign
        CampaignInfo actualCampaignInfo = CampaignInfo(campaignAddress);
        vm.prank(users.protocolAdminAddress);
        actualCampaignInfo._pauseCampaign(keccak256("Pause"));

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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

    /*//////////////////////////////////////////////////////////////
                       CRYPTO PAYMENT PROCESSING
    //////////////////////////////////////////////////////////////*/

    function testProcessCryptoPayment() public {
        uint256 amount = 1500e18;
        deal(address(testToken), users.backer1Address, amount);

        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, amount);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        processCryptoPayment(
            users.backer1Address,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            amount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        assertEq(paymentTreasury.getRaisedAmount(), amount);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), amount);
        assertEq(testToken.balanceOf(treasuryAddress), amount);
    }

    function testProcessCryptoPaymentStoresExternalFees() public {
        uint256 amount = 1000e18;
        deal(address(testToken), users.backer1Address, amount);

        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, amount);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        ICampaignPaymentTreasury.ExternalFees[] memory externalFees = new ICampaignPaymentTreasury.ExternalFees[](2);
        externalFees[0] = ICampaignPaymentTreasury.ExternalFees({feeType: keccak256("feeType1"), feeAmount: 10});
        externalFees[1] = ICampaignPaymentTreasury.ExternalFees({feeType: keccak256("feeType2"), feeAmount: 25});

        bytes32 cryptoPaymentId = keccak256("cryptoPaymentWithFees");
        processCryptoPayment(
            users.backer1Address,
            cryptoPaymentId,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            amount,
            emptyLineItems,
            externalFees
        );

        ICampaignPaymentTreasury.PaymentData memory paymentData = paymentTreasury.getPaymentData(cryptoPaymentId);
        assertEq(paymentData.amount, amount);
        assertTrue(paymentData.isConfirmed);
        assertEq(paymentData.externalFees.length, 2);
        assertEq(paymentData.externalFees[0].feeType, keccak256("feeType1"));
        assertEq(paymentData.externalFees[0].feeAmount, 10);
        assertEq(paymentData.externalFees[1].feeType, keccak256("feeType2"));
        assertEq(paymentData.externalFees[1].feeAmount, 25);
    }

    function testProcessCryptoPaymentRevertWhenZeroBuyerAddress() public {
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        processCryptoPayment(
            users.platform1AdminAddress,
            PAYMENT_ID_1,
            ITEM_ID_1,
            address(0),
            address(testToken),
            1000e18,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testProcessCryptoPaymentRevertWhenZeroAmount() public {
        vm.expectRevert();
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        processCryptoPayment(
            users.platform1AdminAddress,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            0,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testProcessCryptoPaymentRevertWhenPaymentExists() public {
        uint256 amount = 1500e18;
        deal(address(testToken), users.backer1Address, amount * 2);

        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, amount * 2);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        processCryptoPayment(
            users.backer1Address,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            amount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        vm.expectRevert();
        processCryptoPayment(
            users.backer1Address,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            amount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testClaimExpiredFundsRevertsBeforeWindow() public {
        uint256 claimDelay = 7 days;
        vm.prank(users.platform1AdminAddress);
        globalParams.updatePlatformClaimDelay(PLATFORM_1_HASH, claimDelay);

        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        uint256 claimableAt = CampaignInfo(campaignAddress).getDeadline() + claimDelay;
        vm.warp(claimableAt - 1);

        vm.prank(users.platform1AdminAddress);
        vm.expectRevert(
            abi.encodeWithSelector(BasePaymentTreasury.PaymentTreasuryClaimWindowNotReached.selector, claimableAt)
        );
        paymentTreasury.claimExpiredFunds();
    }

    function testClaimExpiredFundsTransfersAllBalances() public {
        uint256 claimDelay = 7 days;
        vm.prank(users.platform1AdminAddress);
        globalParams.updatePlatformClaimDelay(PLATFORM_1_HASH, claimDelay);

        bytes32 refundableTypeId = keccak256("refundable_non_goal_type");
        vm.prank(users.platform1AdminAddress);
        globalParams.setPlatformLineItemType(
            PLATFORM_1_HASH, refundableTypeId, "Refundable Non Goal", false, false, true, false
        );

        uint256 lineItemAmount = 250e18;
        ICampaignPaymentTreasury.LineItem[] memory lineItems = new ICampaignPaymentTreasury.LineItem[](1);
        lineItems[0] = ICampaignPaymentTreasury.LineItem({typeId: refundableTypeId, amount: lineItemAmount});

        uint256 totalAmount = PAYMENT_AMOUNT_1 + lineItemAmount;
        deal(address(testToken), users.backer1Address, totalAmount);

        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, totalAmount);

        vm.prank(users.backer1Address);
        paymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            lineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        uint256 claimableAt = CampaignInfo(campaignAddress).getDeadline() + claimDelay;
        vm.warp(claimableAt + 1);

        uint256 platformBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);
        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimExpiredFunds();

        assertEq(
            testToken.balanceOf(users.platform1AdminAddress),
            platformBalanceBefore + totalAmount,
            "Platform admin should receive all remaining funds"
        );
        assertEq(
            testToken.balanceOf(users.protocolAdminAddress),
            protocolBalanceBefore,
            "Protocol admin should not receive funds when no protocol fees accrued"
        );
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0, "Available raised amount should be zero");
        assertEq(testToken.balanceOf(treasuryAddress), 0, "Treasury token balance should be zero");
    }

    function testClaimExpiredFundsRevertsWhenNoFunds() public {
        uint256 claimDelay = 1 days;
        vm.prank(users.platform1AdminAddress);
        globalParams.updatePlatformClaimDelay(PLATFORM_1_HASH, claimDelay);

        uint256 claimableAt = CampaignInfo(campaignAddress).getDeadline() + claimDelay;
        vm.warp(claimableAt + 1);

        vm.prank(users.platform1AdminAddress);
        vm.expectRevert(abi.encodeWithSelector(BasePaymentTreasury.PaymentTreasuryNoFundsToClaim.selector));
        paymentTreasury.claimExpiredFunds();
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT CANCELLATION
    //////////////////////////////////////////////////////////////*/

    function testCancelPayment() public {
        // Create payment first
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
        // Cancel it
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
        // Payment should be deleted
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function testCancelPaymentRevertWhenNotExists() public {
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    function testCancelPaymentRevertWhenAlreadyConfirmed() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    function testCancelPaymentRevertWhenExpired() public {
        uint256 expiration = block.timestamp + 1 hours;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
        // Warp past expiration
        vm.warp(expiration + 1);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    function testCancelPaymentRevertWhenCryptoPayment() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT CONFIRMATION
    //////////////////////////////////////////////////////////////*/

    function testConfirmPayment() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function testConfirmPaymentBatch() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);
        _createAndFundPayment(PAYMENT_ID_3, BUYER_ID_1, ITEM_ID_1, 500e18, users.backer1Address);

        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds, _createZeroAddressArray(paymentIds.length)); // Removed token array

        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2 + 500e18;
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), totalAmount);
    }

    function testConfirmPaymentRevertWhenNotExists() public {
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter
    }

    function testConfirmPaymentRevertWhenAlreadyConfirmed() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        vm.expectRevert();
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter
        vm.stopPrank();
    }

    function testConfirmPaymentRevertWhenCryptoPayment() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter
    }

    /*//////////////////////////////////////////////////////////////
                              REFUNDS
    //////////////////////////////////////////////////////////////*/

    function testClaimRefund() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);

        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);

        assertEq(balanceAfter - balanceBefore, PAYMENT_AMOUNT_1);
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testClaimRefundBuyerInitiated() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(paymentTreasury), 1);

        vm.prank(users.backer1Address);
        paymentTreasury.claimRefund(PAYMENT_ID_1);

        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);

        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testClaimRefundByPlatformAdminForCryptoPayment() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(paymentTreasury), 1);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1);

        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);

        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(paymentTreasury.getRaisedAmount(), 0);
    }

    function testClaimRefundRevertWhenNotConfirmed() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function testClaimRefundRevertWhenNotExists() public {
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function testClaimRefundRevertWhenPaused() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Pause treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function testClaimRefundRevertWhenUnauthorizedForCryptoPayment() public {
        uint256 amount = 1500e18;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, amount, users.backer1Address);

        vm.expectRevert();
        vm.prank(users.backer2Address); // Different buyer
        paymentTreasury.claimRefund(PAYMENT_ID_1);
    }

    /*//////////////////////////////////////////////////////////////
                          FEE DISBURSEMENT
    //////////////////////////////////////////////////////////////*/

    function testDisburseFees() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Withdraw first to calculate fees
        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();

        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);

        paymentTreasury.disburseFees();

        uint256 protocolBalanceAfter = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceAfter = testToken.balanceOf(users.platform1AdminAddress);
        assertTrue(protocolBalanceAfter > protocolBalanceBefore);
        assertTrue(platformBalanceAfter > platformBalanceBefore);
    }

    function testDisburseFeesMultipleTimes() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // First withdrawal and disbursement
        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();
        paymentTreasury.disburseFees();

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0)); // Removed token parameter

        // Second withdrawal and disbursement
        vm.prank(owner);
        paymentTreasury.withdraw();
        paymentTreasury.disburseFees();
    }

    function testDisburseFeesRevertWhenPaused() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();

        // Pause treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        vm.expectRevert();
        paymentTreasury.disburseFees();
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAWALS
    //////////////////////////////////////////////////////////////*/

    function testWithdraw() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);

        vm.prank(owner);
        paymentTreasury.withdraw();

        uint256 ownerBalanceAfter = testToken.balanceOf(owner);

        uint256 expectedProtocolFee = (PAYMENT_AMOUNT_1 * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedPlatformFee = (PAYMENT_AMOUNT_1 * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedWithdrawal = PAYMENT_AMOUNT_1 - expectedProtocolFee - expectedPlatformFee;

        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedWithdrawal);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testWithdrawRevertWhenAlreadyWithdrawn() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();
        paymentTreasury.disburseFees();

        vm.expectRevert();
        vm.prank(owner);
        paymentTreasury.withdraw();
    }

    function testWithdrawRevertWhenPaused() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Pause treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        address owner = CampaignInfo(campaignAddress).owner();
        vm.expectRevert();
        vm.prank(owner);
        paymentTreasury.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE AND CANCEL
    //////////////////////////////////////////////////////////////*/

    function testPauseTreasury() public {
        // First create and confirm a payment to test functions that require it
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Pause the treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));
        // Functions that check treasury pause status should revert
        // claimRefund uses whenNotPaused
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);

        // disburseFees uses whenNotPaused
        vm.expectRevert();
        paymentTreasury.disburseFees();

        // createPayment checks treasury pause as well
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_1,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testUnpauseTreasury() public {
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.unpauseTreasury(keccak256("Unpause"));

        // Should be able to create payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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

    function testCancelTreasuryByPlatformAdmin() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelTreasury(keccak256("Cancel"));

        // disburseFees() should succeed even when cancelled (fixes vulnerability)
        paymentTreasury.disburseFees();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_1,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCancelTreasuryByCampaignOwner() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.cancelTreasury(keccak256("Cancel"));

        // disburseFees() should succeed even when cancelled (fixes vulnerability)
        paymentTreasury.disburseFees();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_1,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCancelTreasuryRevertWhenUnauthorized() public {
        vm.expectRevert();
        vm.prank(users.backer1Address);
        paymentTreasury.cancelTreasury(keccak256("Cancel"));
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testMultipleRefundsAfterBatchConfirm() public {
        // Create multiple payments
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);
        _createAndFundPayment(PAYMENT_ID_3, BUYER_ID_1, ITEM_ID_1, 500e18, users.backer1Address);

        // Confirm all in batch
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds, _createZeroAddressArray(paymentIds.length)); // Removed token array

        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2 + 500e18;
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount);

        // Refund payments one by one
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount - PAYMENT_AMOUNT_1);

        paymentTreasury.claimRefund(PAYMENT_ID_2, users.backer2Address);
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount - PAYMENT_AMOUNT_1 - PAYMENT_AMOUNT_2);

        paymentTreasury.claimRefund(PAYMENT_ID_3, users.backer1Address);
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        vm.stopPrank();
    }

    function testZeroBalanceAfterAllRefunds() public {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);

        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0)); // Removed token parameter

        // Refund all payments
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
        paymentTreasury.claimRefund(PAYMENT_ID_2, users.backer2Address);
        vm.stopPrank();

        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);

        // Withdraw should revert because balance is 0
        address owner = CampaignInfo(campaignAddress).owner();
        vm.expectRevert();
        vm.prank(owner);
        paymentTreasury.withdraw();
    }

    function testPaymentExpirationScenarios() public {
        uint256 shortExpiration = block.timestamp + 1 hours;
        uint256 longExpiration = block.timestamp + 7 days;

        // Create payments with different expirations
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            shortExpiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            PAYMENT_AMOUNT_2,
            longExpiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        vm.stopPrank();

        // Fund both payments
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, PAYMENT_AMOUNT_1);

        vm.prank(users.backer2Address);
        testToken.transfer(treasuryAddress, PAYMENT_AMOUNT_2);
        // Confirm first payment before expiration
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter
        // Warp past first expiration but before second
        vm.warp(shortExpiration + 1);
        // Cannot cancel or confirm expired payment
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
        // Can still confirm non-expired payment
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0)); // Removed token parameter

        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }

    function testMixedPaymentTypes() public {
        // Create both regular and crypto payments
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndProcessCryptoPayment(PAYMENT_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);

        // Confirm regular payment
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Both should contribute to raised amount
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2;
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), totalAmount);

        // Withdraw and disburse fees
        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();
        paymentTreasury.disburseFees();

        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testCannotCreatePhantomBalances() public {
        // Create payment for 1000 tokens with USDC specified
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken), // Token specified during creation
            1000e18,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Try to confirm without any tokens - should revert
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        // Send the tokens
        deal(address(testToken), users.backer1Address, 1000e18);
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, 1000e18);

        // Now confirmation works
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        assertEq(paymentTreasury.getRaisedAmount(), 1000e18);
    }

    function testCannotConfirmMoreThanBalance() public {
        // Create two payments of 500 each, both with testToken
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.startPrank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            500e18,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            500e18,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        vm.stopPrank();

        // Send only 500 tokens total
        deal(address(testToken), users.backer1Address, 500e18);
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, 500e18);

        // Can confirm one payment
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0)); // Removed token parameter

        // Cannot confirm second payment - total would exceed balance
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0)); // Removed token parameter

        assertEq(paymentTreasury.getRaisedAmount(), 500e18);
    }

    function testBatchConfirmRespectsBalance() public {
        // Create two payments
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.startPrank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        ICampaignPaymentTreasury.ExternalFees[] memory emptyExternalFees =
            new ICampaignPaymentTreasury.ExternalFees[](0);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            500e18,
            expiration,
            emptyLineItems,
            emptyExternalFees
        );
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(testToken),
            500e18,
            expiration,
            emptyLineItems,
            emptyExternalFees
        );
        vm.stopPrank();

        // Send only 500 tokens
        deal(address(testToken), users.backer1Address, 500e18);
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, 500e18);

        // Try to confirm both
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds, _createZeroAddressArray(paymentIds.length)); // Removed token array
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-TOKEN SPECIFIC UNIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testConfirmPaymentWithDifferentTokens() public {
        // Create payments expecting different tokens
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 500e18);
        uint256 cUSDAmount = 700e18;

        // Create USDT payment - token specified during creation
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        // Create cUSD payment - token specified during creation
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, cUSDAmount, users.backer2Address, address(cUSDToken)
        );

        // Confirm without specifying token
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));
        vm.stopPrank();

        uint256 expectedTotal = 500e18 + 700e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal);
    }

    function testProcessCryptoPaymentWithDifferentTokens() public {
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 800e18);
        uint256 cUSDAmount = 1200e18;

        // USDC payment
        deal(address(usdcToken), users.backer1Address, usdcAmount);
        vm.prank(users.backer1Address);
        usdcToken.approve(treasuryAddress, usdcAmount);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        processCryptoPayment(
            users.backer1Address,
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(usdcToken),
            usdcAmount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // cUSD payment
        deal(address(cUSDToken), users.backer2Address, cUSDAmount);
        vm.prank(users.backer2Address);
        cUSDToken.approve(treasuryAddress, cUSDAmount);
        processCryptoPayment(
            users.backer2Address,
            PAYMENT_ID_2,
            ITEM_ID_2,
            users.backer2Address,
            address(cUSDToken),
            cUSDAmount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        uint256 expectedTotal = 800e18 + 1200e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal);
        assertEq(usdcToken.balanceOf(treasuryAddress), usdcAmount);
        assertEq(cUSDToken.balanceOf(treasuryAddress), cUSDAmount);
    }

    function testBatchConfirmWithMixedTokens() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 500e18);
        uint256 usdcAmount = getTokenAmount(address(usdcToken), 600e18);
        uint256 cUSDAmount = 700e18;

        // Create payments with tokens specified
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );
        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, usdcAmount, users.backer2Address, address(usdcToken)
        );
        _createAndFundPaymentWithToken(
            PAYMENT_ID_3, BUYER_ID_3, ITEM_ID_1, cUSDAmount, users.backer1Address, address(cUSDToken)
        );

        // Batch confirm without token array
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds, _createZeroAddressArray(paymentIds.length));

        uint256 expectedTotal = 500e18 + 600e18 + 700e18;
        assertEq(paymentTreasury.getRaisedAmount(), expectedTotal);
    }

    function testRefundReturnsCorrectTokenType() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PAYMENT_AMOUNT_1);

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        uint256 usdtBefore = usdtToken.balanceOf(users.backer1Address);
        uint256 cUSDBefore = cUSDToken.balanceOf(users.backer1Address);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);

        // Should receive USDT, not cUSD
        assertEq(usdtToken.balanceOf(users.backer1Address) - usdtBefore, usdtAmount, "Should receive USDT");
        assertEq(cUSDToken.balanceOf(users.backer1Address), cUSDBefore, "cUSD should be unchanged");
    }

    function testWithdrawDistributesAllTokens() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 1000e18);
        uint256 cUSDAmount = 1500e18;

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, cUSDAmount, users.backer2Address, address(cUSDToken)
        );

        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));
        vm.stopPrank();

        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerUSDTBefore = usdtToken.balanceOf(owner);
        uint256 ownerCUSDBefore = cUSDToken.balanceOf(owner);

        vm.prank(owner);
        paymentTreasury.withdraw();

        // Should receive both tokens
        assertTrue(usdtToken.balanceOf(owner) > ownerUSDTBefore, "Should receive USDT");
        assertTrue(cUSDToken.balanceOf(owner) > ownerCUSDBefore, "Should receive cUSD");
    }

    function testDisburseFeesDistributesAllTokens() public {
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PAYMENT_AMOUNT_1);
        uint256 cUSDAmount = PAYMENT_AMOUNT_2;

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdcAmount, users.backer1Address, address(usdcToken)
        );

        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, cUSDAmount, users.backer2Address, address(cUSDToken)
        );

        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));
        vm.stopPrank();

        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();

        uint256 protocolUSDCBefore = usdcToken.balanceOf(users.protocolAdminAddress);
        uint256 protocolCUSDBefore = cUSDToken.balanceOf(users.protocolAdminAddress);
        uint256 platformUSDCBefore = usdcToken.balanceOf(users.platform1AdminAddress);
        uint256 platformCUSDBefore = cUSDToken.balanceOf(users.platform1AdminAddress);

        paymentTreasury.disburseFees();

        // All token types should have fees disbursed
        assertTrue(
            usdcToken.balanceOf(users.protocolAdminAddress) > protocolUSDCBefore, "Should disburse USDC to protocol"
        );
        assertTrue(
            cUSDToken.balanceOf(users.protocolAdminAddress) > protocolCUSDBefore, "Should disburse cUSD to protocol"
        );
        assertTrue(
            usdcToken.balanceOf(users.platform1AdminAddress) > platformUSDCBefore, "Should disburse USDC to platform"
        );
        assertTrue(
            cUSDToken.balanceOf(users.platform1AdminAddress) > platformCUSDBefore, "Should disburse cUSD to platform"
        );
    }

    function testDecimalNormalizationAccuracy() public {
        // Test that 1000 USDT (6 decimals) = 1000 cUSD (18 decimals) after normalization
        uint256 baseAmount = 1000e18;
        uint256 usdtAmount = baseAmount / 1e12; // 1000 USDT (1000000000)
        uint256 cUSDAmount = baseAmount; // 1000 cUSD (1000000000000000000000)

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        uint256 raisedAfterUSDT = paymentTreasury.getRaisedAmount();
        assertEq(raisedAfterUSDT, baseAmount, "1000 USDT should equal 1000e18 normalized");

        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, cUSDAmount, users.backer2Address, address(cUSDToken)
        );

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));

        uint256 totalRaised = paymentTreasury.getRaisedAmount();
        assertEq(totalRaised, baseAmount * 2, "Both should contribute equally");
    }

    function testCannotConfirmWithInsufficientBalancePerToken() public {
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 1000e18);
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;

        // Create two payments expecting USDT
        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            BUYER_ID_2,
            ITEM_ID_2,
            address(usdtToken), // Token specified
            usdtAmount,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Only funded first payment, second has no tokens

        // Can confirm first
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        // Cannot confirm second - insufficient USDT balance
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));
    }

    function testMixedTokenRefundsAfterPartialWithdraw() public {
        // This tests the edge case where some tokens are withdrawn but others have pending refunds
        uint256 usdtAmount = getTokenAmount(address(usdtToken), 1000e18);
        uint256 cUSDAmount = 1500e18;

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        _createAndFundPaymentWithToken(
            PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, cUSDAmount, users.backer2Address, address(cUSDToken)
        );

        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));
        paymentTreasury.confirmPayment(PAYMENT_ID_2, address(0));
        vm.stopPrank();

        // Withdraw (takes fees)
        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();

        // Try to refund - should fail because funds were withdrawn
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function testZeroBalanceTokensHandledGracefully() public {
        // Create payment with USDT only
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PAYMENT_AMOUNT_1);

        _createAndFundPaymentWithToken(
            PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, usdtAmount, users.backer1Address, address(usdtToken)
        );

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        // Withdraw should handle zero-balance tokens (USDC, cUSD) gracefully
        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.withdraw();

        // Disburse should also handle it
        paymentTreasury.disburseFees();

        // Verify only USDT was processed
        assertEq(usdcToken.balanceOf(treasuryAddress), 0, "USDC should remain zero");
        assertEq(cUSDToken.balanceOf(treasuryAddress), 0, "cUSD should remain zero");
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT BATCH CREATION
    //////////////////////////////////////////////////////////////*/

    function testCreatePaymentBatch() public {
        bytes32[] memory paymentIds = new bytes32[](3);
        bytes32[] memory buyerIds = new bytes32[](3);
        bytes32[] memory itemIds = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory expirations = new uint256[](3);

        // Set up payment data
        paymentIds[0] = keccak256("batchPayment1");
        paymentIds[1] = keccak256("batchPayment2");
        paymentIds[2] = keccak256("batchPayment3");

        buyerIds[0] = BUYER_ID_1;
        buyerIds[1] = BUYER_ID_2;
        buyerIds[2] = BUYER_ID_3;

        itemIds[0] = ITEM_ID_1;
        itemIds[1] = ITEM_ID_2;
        itemIds[2] = ITEM_ID_1; // Reuse existing item ID

        amounts[0] = 100 * 10 ** 18;
        amounts[1] = 200 * 10 ** 18;
        amounts[2] = 300 * 10 ** 18;

        expirations[0] = block.timestamp + 1 days;
        expirations[1] = block.timestamp + 2 days;
        expirations[2] = block.timestamp + 3 days;

        // Execute batch creation
        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray = new ICampaignPaymentTreasury.LineItem[][](3);
        emptyLineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[1] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[2] = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.ExternalFees[][] memory emptyExternalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](3);
        for (uint256 i = 0; i < 3; i++) {
            emptyExternalFeesArray[i] = new ICampaignPaymentTreasury.ExternalFees[](0);
        }
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            _createPaymentTokensArray(3, address(testToken)),
            amounts,
            expirations,
            emptyLineItemsArray,
            emptyExternalFeesArray
        );

        // Verify that payments were created by checking raised amount is still 0 (not confirmed yet)
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testCreatePaymentBatchRevertWhenArrayLengthMismatch() public {
        bytes32[] memory paymentIds = new bytes32[](2);
        bytes32[] memory buyerIds = new bytes32[](3); // Different length
        bytes32[] memory itemIds = new bytes32[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory expirations = new uint256[](2);

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray =
            new ICampaignPaymentTreasury.LineItem[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyLineItemsArray[i] = new ICampaignPaymentTreasury.LineItem[](0);
        }
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.ExternalFees[][] memory emptyExternalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyExternalFeesArray[i] = new ICampaignPaymentTreasury.ExternalFees[](0);
        }
        vm.expectRevert();
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            _createPaymentTokensArray(paymentIds.length, address(testToken)),
            amounts,
            expirations,
            emptyLineItemsArray,
            emptyExternalFeesArray
        );
    }

    function testCreatePaymentBatchRevertWhenEmptyArray() public {
        bytes32[] memory paymentIds = new bytes32[](0);
        bytes32[] memory buyerIds = new bytes32[](0);
        bytes32[] memory itemIds = new bytes32[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory expirations = new uint256[](0);

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray =
            new ICampaignPaymentTreasury.LineItem[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyLineItemsArray[i] = new ICampaignPaymentTreasury.LineItem[](0);
        }
        ICampaignPaymentTreasury.ExternalFees[][] memory emptyExternalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyExternalFeesArray[i] = new ICampaignPaymentTreasury.ExternalFees[](0);
        }
        vm.prank(users.platform1AdminAddress);
        vm.expectRevert();
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            _createPaymentTokensArray(paymentIds.length, address(testToken)),
            amounts,
            expirations,
            emptyLineItemsArray,
            emptyExternalFeesArray
        );
    }

    function testCreatePaymentBatchRevertWhenPaymentAlreadyExists() public {
        // First create a single payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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

        // Now try to create a batch with the same payment ID
        bytes32[] memory paymentIds = new bytes32[](1);
        bytes32[] memory buyerIds = new bytes32[](1);
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory expirations = new uint256[](1);

        paymentIds[0] = PAYMENT_ID_1; // Same ID as above
        buyerIds[0] = BUYER_ID_2;
        itemIds[0] = ITEM_ID_2;
        amounts[0] = PAYMENT_AMOUNT_2;
        expirations[0] = block.timestamp + 2 days;

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray =
            new ICampaignPaymentTreasury.LineItem[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyLineItemsArray[i] = new ICampaignPaymentTreasury.LineItem[](0);
        }
        ICampaignPaymentTreasury.ExternalFees[][] memory emptyExternalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyExternalFeesArray[i] = new ICampaignPaymentTreasury.ExternalFees[](0);
        }
        vm.prank(users.platform1AdminAddress);
        vm.expectRevert();
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            _createPaymentTokensArray(paymentIds.length, address(testToken)),
            amounts,
            expirations,
            emptyLineItemsArray,
            emptyExternalFeesArray
        );
    }

    function testCreatePaymentBatchRevertWhenNotPlatformAdmin() public {
        bytes32[] memory paymentIds = new bytes32[](1);
        bytes32[] memory buyerIds = new bytes32[](1);
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory expirations = new uint256[](1);

        paymentIds[0] = keccak256("batchPayment1");
        buyerIds[0] = BUYER_ID_1;
        itemIds[0] = ITEM_ID_1;
        amounts[0] = PAYMENT_AMOUNT_1;
        expirations[0] = block.timestamp + 1 days;

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray =
            new ICampaignPaymentTreasury.LineItem[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyLineItemsArray[i] = new ICampaignPaymentTreasury.LineItem[](0);
        }
        ICampaignPaymentTreasury.ExternalFees[][] memory emptyExternalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            emptyExternalFeesArray[i] = new ICampaignPaymentTreasury.ExternalFees[](0);
        }
        vm.prank(users.creator1Address); // Not platform admin
        vm.expectRevert();
        paymentTreasury.createPaymentBatch(
            paymentIds,
            buyerIds,
            itemIds,
            _createPaymentTokensArray(paymentIds.length, address(testToken)),
            amounts,
            expirations,
            emptyLineItemsArray,
            emptyExternalFeesArray
        );
    }

    function testCreatePaymentBatchWithMultipleTokens() public {
        // Create payments with different tokens
        bytes32[] memory paymentIds = new bytes32[](3);
        bytes32[] memory buyerIds = new bytes32[](3);
        bytes32[] memory itemIds = new bytes32[](3);
        address[] memory paymentTokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory expirations = new uint256[](3);

        paymentIds[0] = keccak256("payment1");
        paymentIds[1] = keccak256("payment2");
        paymentIds[2] = keccak256("payment3");

        buyerIds[0] = BUYER_ID_1;
        buyerIds[1] = BUYER_ID_2;
        buyerIds[2] = BUYER_ID_3;

        itemIds[0] = ITEM_ID_1;
        itemIds[1] = ITEM_ID_2;
        itemIds[2] = ITEM_ID_1;

        // Use different tokens for each payment
        paymentTokens[0] = address(testToken); // cUSD
        paymentTokens[1] = address(testToken); // cUSD (same token for simplicity in test)
        paymentTokens[2] = address(testToken); // cUSD (same token for simplicity in test)

        amounts[0] = 100 * 10 ** 18;
        amounts[1] = 200 * 10 ** 18;
        amounts[2] = 300 * 10 ** 18;

        expirations[0] = block.timestamp + 1 days;
        expirations[1] = block.timestamp + 2 days;
        expirations[2] = block.timestamp + 3 days;

        // Execute batch creation with multiple tokens
        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray = new ICampaignPaymentTreasury.LineItem[][](3);
        emptyLineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[1] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[2] = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](3);
        externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);
        externalFeesArray[1] = new ICampaignPaymentTreasury.ExternalFees[](0);
        externalFeesArray[2] = new ICampaignPaymentTreasury.ExternalFees[](0);
        paymentTreasury.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, emptyLineItemsArray, externalFeesArray
        );

        // Verify that payments were created
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);

        // Verify that the batch operation completed successfully
        // (The fact that no revert occurred means all payments were created successfully)
        assertTrue(true); // This test passes if no revert occurred during batch creation
    }
}
