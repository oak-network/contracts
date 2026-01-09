// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../integration/GoalBasedPaymentTreasury/GoalBasedPaymentTreasuryFunction.t.sol";
import "forge-std/Test.sol";
import {GoalBasedPaymentTreasury} from "src/treasuries/GoalBasedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

contract GoalBasedPaymentTreasury_UnitTest is Test, GoalBasedPaymentTreasuryFunction_Integration_Shared_Test {
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
        deal(address(testToken), users.backer1Address, 10_000_000e18);
        deal(address(testToken), users.backer2Address, 10_000_000e18);
        // Label addresses
        vm.label(users.protocolAdminAddress, "ProtocolAdmin");
        vm.label(users.platform1AdminAddress, "PlatformAdmin");
        vm.label(users.creator1Address, "CampaignOwner");
        vm.label(users.backer1Address, "Backer1");
        vm.label(users.backer2Address, "Backer2");
        vm.label(address(goalBasedPaymentTreasury), "GoalBasedPaymentTreasury");
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        // Create a new campaign for this test
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("newGoalBasedCampaign"));
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
            4 // GoalBasedPaymentTreasury type
        );
        GoalBasedPaymentTreasury newContract = GoalBasedPaymentTreasury(newTreasury);
        CampaignInfo newCampaignInfo = CampaignInfo(newCampaignAddress);

        // NFT name and symbol are now on CampaignInfo, not treasury
        assertEq(newCampaignInfo.name(), "Campaign Pledge NFT");
        assertEq(newCampaignInfo.symbol(), "PLEDGE");
        assertEq(newContract.getplatformHash(), PLATFORM_1_HASH);
        assertEq(newContract.getplatformFeePercent(), PLATFORM_FEE_PERCENT);
    }

    /*//////////////////////////////////////////////////////////////
                    CREATE PAYMENT TIME CONSTRAINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreatePaymentWithinTimeRange() public {
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

    function testCreatePaymentRevertWhenBeforeLaunchTime() public {
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

    function testCreatePaymentRevertWhenAfterDeadline() public {
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

    function testCreatePaymentBatchRevertWhenAfterDeadline() public {
        advanceToAfterDeadline();

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
        goalBasedPaymentTreasury.createPaymentBatch(
            paymentIds, buyerIds, itemIds, paymentTokens, amounts, expirations, emptyLineItemsArray, externalFeesArray
        );
    }

    function testProcessCryptoPaymentWithinTimeRange() public {
        advanceToWithinRange();

        // Approve tokens for the treasury
        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
    }

    function testProcessCryptoPaymentRevertWhenAfterDeadline() public {
        advanceToAfterDeadline();

        vm.prank(users.backer1Address);
        testToken.approve(address(goalBasedPaymentTreasury), PAYMENT_AMOUNT_1);

        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
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
                    CONFIRM PAYMENT TIME CONSTRAINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testConfirmPaymentWithinBufferPeriod() public {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance to within buffer period
        advanceToAfterDeadline();

        // Confirm should succeed during buffer
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function testConfirmPaymentRevertAfterBufferPeriod() public {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past buffer period
        advanceToAfterDeadlinePlusBuffer();

        // Confirm should fail after buffer
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);
    }

    function testConfirmPaymentBatchWithinBufferPeriod() public {
        advanceToWithinRange();

        // Create and fund payments
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);

        // Advance to buffer period
        advanceToAfterDeadline();

        // Confirm batch should succeed during buffer
        bytes32[] memory paymentIds = new bytes32[](2);
        paymentIds[0] = PAYMENT_ID_1;
        paymentIds[1] = PAYMENT_ID_2;

        address[] memory buyerAddresses = new address[](2);
        buyerAddresses[0] = users.backer1Address;
        buyerAddresses[1] = users.backer2Address;

        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPaymentBatch(paymentIds, buyerAddresses);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }

    /*//////////////////////////////////////////////////////////////
                    CANCEL PAYMENT TIME CONSTRAINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testCancelPaymentWithinBufferPeriod() public {
        advanceToWithinRange();

        // Create payment with expiration that extends past buffer
        uint256 expiration = campaignDeadline + BUFFER_TIME + PAYMENT_EXPIRATION;
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

        // Advance to buffer period
        advanceToAfterDeadline();

        // Cancel should succeed during buffer
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.cancelPayment(PAYMENT_ID_1);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testCancelPaymentRevertAfterBufferPeriod() public {
        advanceToWithinRange();

        // Create payment
        uint256 expiration = campaignDeadline + BUFFER_TIME + PAYMENT_EXPIRATION; // Long expiration
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

        // Advance past buffer period
        advanceToAfterDeadlinePlusBuffer();

        // Cancel should fail after buffer
        vm.expectRevert();
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.cancelPayment(PAYMENT_ID_1);
    }

    /*//////////////////////////////////////////////////////////////
                    GOAL PROGRESS CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGoalProgressDuringCampaign() public {
        advanceToWithinRange();

        // Create confirmed payment
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

        // Create pending payment
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

        // During campaign, goal progress = pending + confirmed
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgress, PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);

        // getRaisedAmount should only return confirmed
        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);

        // getExpectedAmount should return pending
        assertEq(goalBasedPaymentTreasury.getExpectedAmount(), PAYMENT_AMOUNT_2);
    }

    function testGoalProgressDuringBufferPeriod() public {
        advanceToWithinRange();

        // Create confirmed payment
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

        // Create pending payment
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

        // Advance to buffer period
        advanceToAfterDeadline();

        // During buffer, goal progress still = pending + confirmed (optimistic)
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgress, PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);
    }

    function testGoalProgressAfterBufferPeriod() public {
        advanceToWithinRange();

        // Create confirmed payment
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

        // Create pending payment
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

        // After buffer, goal progress = confirmed only
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalProgress, PAYMENT_AMOUNT_1);
    }

    /*//////////////////////////////////////////////////////////////
                        REFUND OPTIMISTIC LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function testRefundBeforeDeadlineSucceeds() public {
        advanceToWithinRange();

        // Create and process crypto payment (first crypto payment = tokenId 1)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should succeed before deadline regardless of goal status
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        assertEq(testToken.balanceOf(users.backer1Address) - balanceBefore, PAYMENT_AMOUNT_1);
    }

    function testRefundAfterDeadlineGoalNotMetSucceeds() public {
        advanceToWithinRange();

        // Create payment that doesn't meet goal (first crypto payment = tokenId 1)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should succeed when goal not met
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        assertEq(testToken.balanceOf(users.backer1Address) - balanceBefore, PAYMENT_AMOUNT_1);
    }

    function testRefundAfterDeadlineGoalMetReverts() public {
        advanceToWithinRange();

        // Fund to meet goal (tokenId 1)
        _fundCampaignToMeetGoal();

        // Create another payment (tokenId 2)
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer2Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 2);

        // Refund should fail when goal met
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);
    }

    function testRefundOptimisticLockWithPendingPayments() public {
        advanceToWithinRange();

        // Create small confirmed payment below goal (first crypto payment = tokenId 1)
        uint256 smallAmount = campaignGoalAmount / 10;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, smallAmount, users.backer2Address);

        // Create large pending payment (would meet goal)
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_1, ITEM_ID_2, campaignGoalAmount, users.backer1Address);

        // Advance past deadline (into buffer)
        advanceToAfterDeadline();

        // Goal progress should show optimistic total >= goal
        uint256 goalProgress = goalBasedPaymentTreasury.getGoalProgress();
        assertGe(goalProgress, campaignGoalAmount);

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should fail due to optimistic lock
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);
    }

    function testRefundAfterBufferWithFailedPendingPayments() public {
        advanceToWithinRange();

        // Create small confirmed payment below goal (first crypto payment = tokenId 1)
        uint256 smallAmount = campaignGoalAmount / 10;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, smallAmount, users.backer2Address);

        // Create pending payment (would meet goal if confirmed)
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_1, ITEM_ID_2, campaignGoalAmount, users.backer1Address);

        // During buffer: optimistic lock should block refunds
        advanceToAfterDeadline();
        assertGe(goalBasedPaymentTreasury.getGoalProgress(), campaignGoalAmount);

        // Advance past buffer: pending payments can no longer be confirmed
        advanceToAfterDeadlinePlusBuffer();

        // Goal progress should now only show confirmed (below goal)
        uint256 goalProgressAfterBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertLt(goalProgressAfterBuffer, campaignGoalAmount);

        // Approve treasury to burn NFT
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);

        // Refund should now succeed since goal not met
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testRefundWithAddressOverloadAfterDeadlineGoalNotMet() public {
        advanceToWithinRange();

        // Create and fund payment
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Confirm the payment
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, address(0));

        // Advance past deadline
        advanceToAfterDeadline();

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Platform admin claims refund on behalf of user
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1, users.backer1Address);

        assertEq(testToken.balanceOf(users.backer1Address) - balanceBefore, PAYMENT_AMOUNT_1);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW AND DISBURSE FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdrawGoalMetSucceeds() public {
        advanceToWithinRange();

        // Fund to meet goal
        _fundCampaignToMeetGoal();

        // Advance past deadline
        advanceToAfterDeadline();

        uint256 creatorBalanceBefore = testToken.balanceOf(users.creator1Address);

        // Withdraw should succeed
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();

        assertTrue(testToken.balanceOf(users.creator1Address) > creatorBalanceBefore);
    }

    function testWithdrawGoalNotMetReverts() public {
        advanceToWithinRange();

        // Create payment below goal
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Withdraw should fail
        vm.expectRevert();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();
    }

    function testWithdrawBeforeDeadlineReverts() public {
        advanceToWithinRange();

        // Fund to meet goal
        _fundCampaignToMeetGoal();

        // Withdraw should fail before deadline
        vm.expectRevert();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();
    }

    function testDisburseFeesGoalMetSucceeds() public {
        advanceToWithinRange();

        // Fund to meet goal
        _fundCampaignToMeetGoal();

        // Advance and withdraw
        advanceToAfterDeadline();
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.withdraw();

        uint256 protocolBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBefore = testToken.balanceOf(users.platform1AdminAddress);

        // Disburse fees
        goalBasedPaymentTreasury.disburseFees();

        assertTrue(testToken.balanceOf(users.protocolAdminAddress) > protocolBefore);
        assertTrue(testToken.balanceOf(users.platform1AdminAddress) > platformBefore);
    }

    function testDisburseFeesGoalNotMetReverts() public {
        advanceToWithinRange();

        // Create payment below goal
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Disburse should fail
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryGoalNotMet.selector);
        goalBasedPaymentTreasury.disburseFees();
    }

    function testDisburseFeesBeforeDeadlineReverts() public {
        advanceToWithinRange();

        // Fund to meet goal
        _fundCampaignToMeetGoal();

        // Disburse should fail before deadline
        vm.expectRevert();
        goalBasedPaymentTreasury.disburseFees();
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL TREASURY TESTS
    //////////////////////////////////////////////////////////////*/

    function testCancelTreasuryByPlatformAdmin() public {
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("cancel"));

        assertTrue(goalBasedPaymentTreasury.cancelled());
    }

    function testCancelTreasuryByCampaignOwner() public {
        vm.prank(users.creator1Address);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("cancel"));

        assertTrue(goalBasedPaymentTreasury.cancelled());
    }

    function testCancelTreasuryByUnauthorizedReverts() public {
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryUnauthorized.selector);
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.cancelTreasury(keccak256("cancel"));
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testOperationsAtExactLaunchTime() public {
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

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testOperationsAtExactDeadline() public {
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

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), 0);
    }

    function testOperationsAtExactDeadlinePlusBuffer() public {
        advanceToWithinRange();

        // Create payment during campaign
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);

        // Advance to exact deadline + buffer
        advanceToDeadlinePlusBuffer();

        // Confirm should still work at exact buffer end
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.confirmPayment(PAYMENT_ID_1, users.backer1Address);

        assertEq(goalBasedPaymentTreasury.getRaisedAmount(), PAYMENT_AMOUNT_1);
    }

    function testGoalProgressTransitionAtBufferBoundary() public {
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

        // At exact buffer end: still includes pending
        vm.warp(campaignDeadline + BUFFER_TIME);
        uint256 goalAtBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalAtBuffer, PAYMENT_AMOUNT_1 + PAYMENT_AMOUNT_2);

        // Just after buffer end: only confirmed
        vm.warp(campaignDeadline + BUFFER_TIME + 1);
        uint256 goalAfterBuffer = goalBasedPaymentTreasury.getGoalProgress();
        assertEq(goalAfterBuffer, PAYMENT_AMOUNT_1);
    }

    function testMultipleRefundsOptimisticLock() public {
        advanceToWithinRange();

        // Create multiple small confirmed payments (tokenId 1, tokenId 2)
        uint256 smallAmount = PAYMENT_AMOUNT_1;
        _createAndProcessCryptoPayment(PAYMENT_ID_1, ITEM_ID_1, smallAmount, users.backer1Address);
        _createAndProcessCryptoPayment(PAYMENT_ID_2, ITEM_ID_2, smallAmount, users.backer2Address);

        // Create pending payment that would meet goal (using creator1 as a third participant)
        deal(address(testToken), users.creator1Address, campaignGoalAmount);
        _createAndFundPayment(PAYMENT_ID_3, BUYER_ID_3, keccak256("item3"), campaignGoalAmount, users.creator1Address);

        // Advance past deadline
        advanceToAfterDeadline();

        // Both refunds should be blocked due to optimistic lock
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 1);
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer1Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_1);

        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(goalBasedPaymentTreasury), 2);
        vm.expectRevert(GoalBasedPaymentTreasury.GoalBasedPaymentTreasuryNotRefundable.selector);
        vm.prank(users.backer2Address);
        goalBasedPaymentTreasury.claimRefund(PAYMENT_ID_2);
    }
}

