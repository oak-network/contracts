// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../integration/PaymentTreasury/PaymentTreasury.t.sol";
import "forge-std/Test.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";

contract PaymentTreasury_UnitTest is Test, PaymentTreasury_Integration_Shared_Test {
    
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
            CAMPAIGN_DATA
        );
        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);
        
        // Deploy a new treasury
        vm.prank(users.platform1AdminAddress);
        address newTreasury = treasuryFactory.deploy(
            PLATFORM_1_HASH,
            newCampaignAddress,
            2,
            "NewPaymentTreasury",
            "NPT"
        );
        PaymentTreasury newContract = PaymentTreasury(newTreasury);
        
        assertEq(newContract.name(), "NewPaymentTreasury");
        assertEq(newContract.symbol(), "NPT");
        assertEq(newContract.getplatformHash(), PLATFORM_1_HASH);
        assertEq(newContract.getplatformFeePercent(), PLATFORM_FEE_PERCENT);
    }
    
    /*//////////////////////////////////////////////////////////////
                          PAYMENT CREATION
    //////////////////////////////////////////////////////////////*/
    
    function testCreatePayment() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
        // Payment created but not confirmed
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }
    
    function testCreatePaymentRevertWhenNotPlatformAdmin() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.backer1Address);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
    }
    
    function testCreatePaymentRevertWhenZeroBuyerAddress() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            address(0),
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
    }
    
    function testCreatePaymentRevertWhenZeroAmount() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            0,
            expiration
        );
    }
    
    function testCreatePaymentRevertWhenExpired() public {
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            block.timestamp - 1
        );
    }
    
    function testCreatePaymentRevertWhenZeroPaymentId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            bytes32(0),
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
    }
    
    function testCreatePaymentRevertWhenZeroItemId() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            bytes32(0),
            PAYMENT_AMOUNT_1,
            expiration
        );
    }
    
    function testCreatePaymentRevertWhenPaymentExists() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
        vm.expectRevert();
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer2Address,
            ITEM_ID_2,
            PAYMENT_AMOUNT_2,
            expiration
        );
        vm.stopPrank();
    }
    
    function testCreatePaymentRevertWhenPaused() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        // Pause the treasury - but this won't affect createPayment
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));

        // createPayment checks campaign pause, not treasury pause
        CampaignInfo actualCampaignInfo = CampaignInfo(campaignAddress);
        vm.prank(users.protocolAdminAddress);
        actualCampaignInfo._pauseCampaign(keccak256("Pause"));
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
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
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                        PAYMENT CANCELLATION
    //////////////////////////////////////////////////////////////*/
    
    function testCancelPayment() public {
        // Create payment first
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
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
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }
    
    function testCancelPaymentRevertWhenExpired() public {
        uint256 expiration = block.timestamp + 1 hours;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
        // Warp past expiration
        vm.warp(expiration + 1);
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
    }
    
    /*//////////////////////////////////////////////////////////////
                        PAYMENT CONFIRMATION
    //////////////////////////////////////////////////////////////*/
    
    function testConfirmPayment() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), PAYMENT_AMOUNT_1);
    }
    
    function testConfirmPaymentBatch() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        _createAndFundPayment(PAYMENT_ID_2, users.backer2Address, ITEM_ID_2, PAYMENT_AMOUNT_2);
        _createAndFundPayment(PAYMENT_ID_3, users.backer1Address, ITEM_ID_1, 500e18);
        
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;
        
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds);
        
        uint256 totalAmount = PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2 + 500e18;
        assertEq(paymentTreasury.getRaisedAmount(), totalAmount);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), totalAmount);
    }
    
    function testConfirmPaymentRevertWhenNotExists() public {
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
    }
    
    function testConfirmPaymentRevertWhenAlreadyConfirmed() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        vm.expectRevert();
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                              REFUNDS
    //////////////////////////////////////////////////////////////*/
    
    function testClaimRefund() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);
        
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
        
        uint256 balanceAfter = testToken.balanceOf(users.backer1Address);
        
        assertEq(balanceAfter - balanceBefore, PAYMENT_AMOUNT_1);
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }
    
    function testClaimRefundRevertWhenNotConfirmed() public {
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
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
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        // Pause treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));
        
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }
    
    /*//////////////////////////////////////////////////////////////
                          FEE DISBURSEMENT
    //////////////////////////////////////////////////////////////*/
    
    function testDisburseFees() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform1AdminAddress);
        
        paymentTreasury.disburseFees();
        
        uint256 protocolBalanceAfter = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceAfter = testToken.balanceOf(users.platform1AdminAddress);
        assertTrue(protocolBalanceAfter > protocolBalanceBefore);
        assertTrue(platformBalanceAfter > platformBalanceBefore);
    }
    
    function testDisburseFeesRevertWhenAlreadyDisbursed() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        paymentTreasury.disburseFees();
        
        vm.expectRevert();
        paymentTreasury.disburseFees();
    }
    
    function testDisburseFeesRevertWhenPaused() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
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
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        paymentTreasury.disburseFees();
        
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);
        uint256 availableAmount = paymentTreasury.getAvailableRaisedAmount();
        
        paymentTreasury.withdraw();
        
        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, availableAmount);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
    }
    
    function testWithdrawRevertWhenFeesNotDisbursed() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        vm.expectRevert();
        paymentTreasury.withdraw();
    }
    
    function testWithdrawRevertWhenAlreadyWithdrawn() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
        paymentTreasury.disburseFees();
        paymentTreasury.withdraw();
        
        vm.expectRevert();
        paymentTreasury.withdraw();
    }
    
    function testWithdrawRevertWhenPaused() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        paymentTreasury.disburseFees();
        
        // Pause treasury
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.pauseTreasury(keccak256("Pause"));
        
        vm.expectRevert();
        paymentTreasury.withdraw();
    }
    
    /*//////////////////////////////////////////////////////////////
                        PAUSE AND CANCEL
    //////////////////////////////////////////////////////////////*/
    
    function testPauseTreasury() public {
        // First create and confirm a payment to test functions that require it
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        
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

        // createPayment checks campaign pause, not treasury pause
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            users.backer2Address,
            ITEM_ID_2,
            PAYMENT_AMOUNT_2,
            expiration
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
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            expiration
        );
    }

    function testCancelTreasuryByPlatformAdmin() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);

        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelTreasury(keccak256("Cancel"));
        
        vm.expectRevert();
        paymentTreasury.disburseFees();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            users.backer2Address,
            ITEM_ID_2,
            PAYMENT_AMOUNT_2,
            expiration
        );
    }
    
    function testCancelTreasuryByCampaignOwner() public {
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);

        address owner = CampaignInfo(campaignAddress).owner();
        vm.prank(owner);
        paymentTreasury.cancelTreasury(keccak256("Cancel"));
        
        vm.expectRevert();
        paymentTreasury.disburseFees();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            users.backer2Address,
            ITEM_ID_2,
            PAYMENT_AMOUNT_2,
            expiration
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
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        _createAndFundPayment(PAYMENT_ID_2, users.backer2Address, ITEM_ID_2, PAYMENT_AMOUNT_2);
        _createAndFundPayment(PAYMENT_ID_3, users.backer1Address, ITEM_ID_1, 500e18);
        
        // Confirm all in batch
        bytes32[] memory paymentIds = new bytes32[](3);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;
        paymentIds[2] = PAYMENT_ID_3;
        
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPaymentBatch(paymentIds);
        
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
        _createAndFundPayment(PAYMENT_ID_1, users.backer1Address, ITEM_ID_1, PAYMENT_AMOUNT_1);
        _createAndFundPayment(PAYMENT_ID_2, users.backer2Address, ITEM_ID_2, PAYMENT_AMOUNT_2);
        
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        paymentTreasury.confirmPayment(PAYMENT_ID_2);
        
        // Refund all payments
        paymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
        paymentTreasury.claimRefund(PAYMENT_ID_2, users.backer2Address);
        vm.stopPrank();
        
        assertEq(paymentTreasury.getRaisedAmount(), 0);
        assertEq(paymentTreasury.getAvailableRaisedAmount(), 0);
        
        // Disbursing fees with zero balance should succeed (transferring 0 amounts)
        paymentTreasury.disburseFees();
        // But withdraw should revert because balance is 0
        vm.expectRevert();
        paymentTreasury.withdraw();
    }
    
    function testPaymentExpirationScenarios() public {
        uint256 shortExpiration = block.timestamp + 1 hours;
        uint256 longExpiration = block.timestamp + 7 days;
        
        // Create payments with different expirations
        vm.startPrank(users.platform1AdminAddress);
        paymentTreasury.createPayment(
            PAYMENT_ID_1,
            users.backer1Address,
            ITEM_ID_1,
            PAYMENT_AMOUNT_1,
            shortExpiration
        );
        paymentTreasury.createPayment(
            PAYMENT_ID_2,
            users.backer2Address,
            ITEM_ID_2,
            PAYMENT_AMOUNT_2,
            longExpiration
        );
        vm.stopPrank();
        
        // Fund both payments
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, PAYMENT_AMOUNT_1);
        
        vm.prank(users.backer2Address);
        testToken.transfer(treasuryAddress, PAYMENT_AMOUNT_2);
        // Confirm first payment before expiration
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_1);
        // Warp past first expiration but before second
        vm.warp(shortExpiration + 1);
        // Cannot cancel or confirm expired payment
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.cancelPayment(PAYMENT_ID_1);
        // Can still confirm non-expired payment
        vm.prank(users.platform1AdminAddress);
        paymentTreasury.confirmPayment(PAYMENT_ID_2);
        
        assertEq(paymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }
}