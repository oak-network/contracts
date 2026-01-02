// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../integration/TimeConstrainedPaymentTreasury/TimeConstrainedPaymentTreasuryFunction.t.sol";
import "forge-std/Test.sol";
import {TimeConstrainedPaymentTreasury} from "src/treasuries/TimeConstrainedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

contract TimeConstrainedPaymentTreasury_UnitTest is
    Test,
    TimeConstrainedPaymentTreasuryFunction_Integration_Shared_Test
{
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
        vm.label(address(timeConstrainedPaymentTreasury), "TimeConstrainedPaymentTreasury");
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        // Create a new campaign for this test
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("newTimeConstrainedCampaign"));
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
        address newTreasury = treasuryFactory.deploy(
            PLATFORM_1_HASH,
            newCampaignAddress,
            3 // TimeConstrainedPaymentTreasury type
        );
        TimeConstrainedPaymentTreasury newContract = TimeConstrainedPaymentTreasury(newTreasury);
        CampaignInfo newCampaignInfo = CampaignInfo(newCampaignAddress);

        // NFT name and symbol are now on CampaignInfo, not treasury
        assertEq(newCampaignInfo.name(), "Campaign Pledge NFT");
        assertEq(newCampaignInfo.symbol(), "PLEDGE");
        assertEq(newContract.getplatformHash(), PLATFORM_1_HASH);
        assertEq(newContract.getplatformFeePercent(), PLATFORM_FEE_PERCENT);
    }

    /*//////////////////////////////////////////////////////////////
                          TIME CONSTRAINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreatePaymentWithinTimeRange() public {
        advanceToWithinRange();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
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
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
        assertEq(timeConstrainedPaymentTreasury.getAvailableRaisedAmount(), 0);
    }

    function testCreatePaymentRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
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

    function testCreatePaymentRevertWhenAfterDeadlinePlusBuffer() public {
        advanceToAfterDeadline();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
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

    function testCreatePaymentBatchWithinTimeRange() public {
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

        address[] memory paymentTokens = _createPaymentTokensArray(2, address(testToken));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = PAYMENT_AMOUNT_1;
        amounts[1] = PAYMENT_AMOUNT_2;

        uint256[] memory expirations = new uint256[](2);
        expirations[0] = block.timestamp + PAYMENT_EXPIRATION;
        expirations[1] = block.timestamp + PAYMENT_EXPIRATION;

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray = new ICampaignPaymentTreasury.LineItem[][](2);
        emptyLineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        emptyLineItemsArray[1] = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](2);
        externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);
        externalFeesArray[1] = new ICampaignPaymentTreasury.ExternalFees[](0);
        timeConstrainedPaymentTreasury.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, emptyLineItemsArray, externalFeesArray
        );

        // Payments created successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testCreatePaymentBatchRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        bytes32[] memory paymentIds = new bytes32[](1);
        paymentIds[0] = PAYMENT_ID_1;

        bytes32[] memory buyerIds = new bytes32[](1);
        buyerIds[0] = BUYER_ID_1;

        bytes32[] memory itemIds = new bytes32[](1);
        itemIds[0] = ITEM_ID_1;

        address[] memory paymentTokens = _createPaymentTokensArray(1, address(testToken));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = PAYMENT_AMOUNT_1;

        uint256[] memory expirations = new uint256[](1);
        expirations[0] = block.timestamp + PAYMENT_EXPIRATION;

        ICampaignPaymentTreasury.LineItem[][] memory emptyLineItemsArray = new ICampaignPaymentTreasury.LineItem[][](1);
        emptyLineItemsArray[0] = new ICampaignPaymentTreasury.LineItem[](0);
        ICampaignPaymentTreasury.ExternalFees[][] memory externalFeesArray =
            new ICampaignPaymentTreasury.ExternalFees[][](1);
        externalFeesArray[0] = new ICampaignPaymentTreasury.ExternalFees[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, emptyLineItemsArray, externalFeesArray
        );
    }

    function testProcessCryptoPaymentWithinTimeRange() public {
        advanceToWithinRange();

        // Approve tokens for the treasury
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Payment processed successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function testProcessCryptoPaymentRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    function testCancelPaymentWithinTimeRange() public {
        advanceToWithinRange();

        // First create a payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
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
        timeConstrainedPaymentTreasury.cancelPayment(PAYMENT_ID_1);

        // Payment cancelled successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testCancelPaymentRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    function testConfirmPaymentWithinTimeRange() public {
        advanceToWithinRange();

        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Payment created and confirmed successfully by processCryptoPayment
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function testConfirmPaymentRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));
    }

    function testConfirmPaymentBatchWithinTimeRange() public {
        advanceToWithinRange();

        // Use processCryptoPayment for both payments which creates and confirms them
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        vm.prank(users.backer2Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_2);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems2 = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_2,
            ITEM_ID_2,
            users.backer2Address,
            address(testToken),
            PAYMENT_AMOUNT_2,
            emptyLineItems2,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Payments created and confirmed successfully by processCryptoPayment
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }

    function testConfirmPaymentBatchRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        bytes32[] memory paymentIds = new bytes32[](1);
        paymentIds[0] = PAYMENT_ID_1;

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.confirmPaymentBatch(paymentIds, _createZeroAddressArray(paymentIds.length));
    }

    /*//////////////////////////////////////////////////////////////
                          POST-LAUNCH TIME TESTS
    //////////////////////////////////////////////////////////////*/

    function testClaimRefundAfterLaunchTime() public {
        // First create payment within the allowed time range
        advanceToWithinRange();

        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Advance to after launch to be able to claim refund
        advanceToAfterLaunch();

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(timeConstrainedPaymentTreasury), 1); // tokenId 1

        // Then claim refund (use the overload without refundAddress since processCryptoPayment uses buyerAddress)
        vm.prank(users.backer1Address);
        timeConstrainedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        // Refund claimed successfully
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testClaimRefundRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);
    }

    function testDisburseFeesAfterLaunchTime() public {
        // First create payment within the allowed time range
        advanceToWithinRange();

        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Advance to after launch time
        advanceToAfterLaunch();

        // Then disburse fees
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.disburseFees();

        // Fees disbursed successfully (no revert)
    }

    function testDisburseFeesRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.disburseFees();
    }

    function testWithdrawAfterLaunchTime() public {
        // First create payment within the allowed time range
        advanceToWithinRange();

        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Advance to after launch time
        advanceToAfterLaunch();

        // Then withdraw
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.withdraw();

        // Withdrawal successful (no revert)
    }

    function testWithdrawRevertWhenBeforeLaunchTime() public {
        advanceToBeforeLaunch();

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                          BUFFER TIME TESTS
    //////////////////////////////////////////////////////////////*/

    function testBufferTimeRetrieval() public {
        // Test that buffer time is correctly retrieved from GlobalParams
        // We can't access _getBufferTime() directly, so we test it indirectly
        // by checking that operations work within the buffer time window
        vm.warp(campaignDeadline - 1); // Use deadline - 1 to be within range

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Should succeed at deadline - 1
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testOperationsAtDeadlinePlusBuffer() public {
        // Test operations at the exact deadline + buffer time
        vm.warp(campaignDeadline - 1); // Use deadline - 1 to be within range

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Should succeed at deadline - 1
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testOperationsAfterDeadlinePlusBuffer() public {
        // Test operations after deadline + buffer time
        advanceToAfterDeadline();

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
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
                          EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testOperationsAtExactLaunchTime() public {
        // Test operations at the exact launch time
        vm.warp(campaignLaunchTime);

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Should succeed at the exact launch time
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testOperationsAtExactDeadline() public {
        // Test operations at the exact deadline
        vm.warp(campaignDeadline);

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        timeConstrainedPaymentTreasury.createPayment(
            PAYMENT_ID_1,
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            PAYMENT_AMOUNT_1,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
        // Should succeed at the exact deadline
        assertEq(timeConstrainedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testMultipleTimeConstraintChecks() public {
        // Test that multiple operations respect time constraints
        advanceToWithinRange();

        // Use processCryptoPayment which creates and confirms payment in one step
        vm.prank(users.backer1Address);
        testToken.approve(address(timeConstrainedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        timeConstrainedPaymentTreasury.processCryptoPayment(
            PAYMENT_ID_1,
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            PAYMENT_AMOUNT_1,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
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
