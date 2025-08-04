// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./KeepWhatsRaised.t.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";

contract KeepWhatsRaisedFunction_Integration_Shared_Test is KeepWhatsRaised_Integration_Shared_Test {
    function setUp() public virtual override {
        super.setUp();

        // Fund test users with tokens
        deal(address(testToken), users.backer1Address, 1_000_000e18);
        deal(address(testToken), users.backer2Address, 1_000_000e18);
        deal(address(testToken), users.creator1Address, 1_000_000e18);
        deal(address(testToken), users.platform2AdminAddress, 1_000_000e18);
    }

    function test_addRewards() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);
        
        // First reward
        Reward memory resultReward1 = keepWhatsRaised.getReward(REWARD_NAMES[0]);
        assertEq(REWARDS[0].rewardValue, resultReward1.rewardValue);
        assertEq(REWARDS[0].isRewardTier, resultReward1.isRewardTier);
        assertEq(REWARDS[0].itemId[0], resultReward1.itemId[0]);
        assertEq(REWARDS[0].itemValue[0], resultReward1.itemValue[0]);
        assertEq(REWARDS[0].itemQuantity[0], resultReward1.itemQuantity[0]);

        // Second reward
        Reward memory resultReward2 = keepWhatsRaised.getReward(REWARD_NAMES[1]);
        assertEq(REWARDS[1].rewardValue, resultReward2.rewardValue);
        assertEq(REWARDS[1].isRewardTier, resultReward2.isRewardTier);
        assertEq(REWARDS[1].itemId.length, resultReward2.itemId.length);
        assertEq(REWARDS[1].itemId[0], resultReward2.itemId[0]);
        assertEq(REWARDS[1].itemId[1], resultReward2.itemId[1]);
        assertEq(REWARDS[1].itemValue[0], resultReward2.itemValue[0]);
        assertEq(REWARDS[1].itemValue[1], resultReward2.itemValue[1]);
        assertEq(REWARDS[1].itemQuantity[0], resultReward2.itemQuantity[0]);
        assertEq(REWARDS[1].itemQuantity[1], resultReward2.itemQuantity[1]);

        // Third reward
        Reward memory resultReward3 = keepWhatsRaised.getReward(REWARD_NAMES[2]);
        assertEq(REWARDS[2].rewardValue, resultReward3.rewardValue);
        assertEq(REWARDS[2].isRewardTier, resultReward3.isRewardTier);
        assertEq(REWARDS[2].itemId.length, resultReward3.itemId.length);
    }

    function test_setPaymentGatewayFee() external {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        
        uint256 fee = keepWhatsRaised.getPaymentGatewayFee(TEST_PLEDGE_ID_1);
        assertEq(fee, PAYMENT_GATEWAY_FEE);
    }

    function test_pledgeForARewardWithGatewayFee() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);
        
        // Set gateway fee first
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);

        (Vm.Log[] memory logs, uint256 tokenId, bytes32[] memory rewards) = pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        uint256 backerBalance = testToken.balanceOf(users.backer1Address);
        uint256 treasuryBalance = testToken.balanceOf(address(keepWhatsRaised));
        uint256 backerNftBalance = keepWhatsRaised.balanceOf(users.backer1Address);
        address nftOwnerAddress = keepWhatsRaised.ownerOf(tokenId);

        assertEq(users.backer1Address, nftOwnerAddress);
        assertEq(PLEDGE_AMOUNT + TIP_AMOUNT, treasuryBalance);
        assertEq(1, backerNftBalance);
        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT);

        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < PLEDGE_AMOUNT);
    }

    function test_pledgeWithoutARewardWithGatewayFee() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);
        
        // Set gateway fee first
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);

        (, uint256 tokenId) = pledgeWithoutAReward(
            users.backer1Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_1, PLEDGE_AMOUNT, TIP_AMOUNT, LAUNCH_TIME
        );

        uint256 treasuryBalance = testToken.balanceOf(address(keepWhatsRaised));
        uint256 backerNftBalance = keepWhatsRaised.balanceOf(users.backer1Address);
        address nftOwnerAddress = keepWhatsRaised.ownerOf(tokenId);

        assertEq(users.backer1Address, nftOwnerAddress);
        assertEq(PLEDGE_AMOUNT + TIP_AMOUNT, treasuryBalance);
        assertEq(1, backerNftBalance);
        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT);

        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < PLEDGE_AMOUNT);
    }

    function test_setFeeAndPledgeForReward() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);
        
        vm.warp(LAUNCH_TIME);
        
        bytes32[] memory reward = new bytes32[](1);
        reward[0] = REWARD_NAME_1_HASH;
        
        (Vm.Log[] memory logs, uint256 tokenId, bytes32[] memory rewards) = setFeeAndPledge(
            users.platform2AdminAddress,
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            users.backer1Address,
            0, // pledgeAmount is ignored for reward pledges
            TIP_AMOUNT,
            PAYMENT_GATEWAY_FEE,
            reward,
            true
        );
        
        // Verify fee was set
        assertEq(keepWhatsRaised.getPaymentGatewayFee(TEST_PLEDGE_ID_1), PAYMENT_GATEWAY_FEE);
        
        // Verify pledge was made
        address nftOwnerAddress = keepWhatsRaised.ownerOf(tokenId);
        assertEq(users.backer1Address, nftOwnerAddress);
    }

    function test_setFeeAndPledgeWithoutReward() external {
        vm.warp(LAUNCH_TIME);
        
        bytes32[] memory emptyReward = new bytes32[](0);
        
        (Vm.Log[] memory logs, uint256 tokenId, bytes32[] memory rewards) = setFeeAndPledge(
            users.platform2AdminAddress,
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            users.backer1Address,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            PAYMENT_GATEWAY_FEE,
            emptyReward,
            false
        );
        
        // Verify fee was set
        assertEq(keepWhatsRaised.getPaymentGatewayFee(TEST_PLEDGE_ID_1), PAYMENT_GATEWAY_FEE);
        
        // Verify pledge was made
        address nftOwnerAddress = keepWhatsRaised.ownerOf(tokenId);
        assertEq(users.backer1Address, nftOwnerAddress);
    }

    function test_withdrawWithColombianCreatorTax() external {
        // Configure with Colombian creator
        configureTreasury(users.platform2AdminAddress, address(keepWhatsRaised), CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS);
        
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledges with gateway fees
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_2, PAYMENT_GATEWAY_FEE);
        pledgeWithoutAReward(
            users.backer2Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_2, GOAL_AMOUNT, TIP_AMOUNT, LAUNCH_TIME
        );

        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;
        address actualOwner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(actualOwner);

        (Vm.Log[] memory logs, address to, uint256 withdrawalAmount, uint256 fee) =
            withdraw(address(keepWhatsRaised), 0, DEADLINE + 1 days);

        uint256 ownerBalanceAfter = testToken.balanceOf(actualOwner);

        assertEq(to, actualOwner, "Incorrect address receiving the funds");
        assertTrue(withdrawalAmount < totalPledged, "Withdrawal should be less than total pledged due to fees");
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawalAmount, "Incorrect balance change");
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0, "Available amount should be zero");
    }

    function test_refundWithPaymentFees() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledge with gateway fee
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        (, uint256 tokenId,) = pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        uint256 backerBalanceBefore = testToken.balanceOf(users.backer1Address);

        vm.warp(DEADLINE + 1 days);
        (Vm.Log[] memory refundLogs, uint256 refundedTokenId, uint256 refundAmount, address claimer) =
            claimRefund(users.backer1Address, address(keepWhatsRaised), tokenId);

        uint256 backerBalanceAfter = testToken.balanceOf(users.backer1Address);

        assertEq(refundedTokenId, tokenId);
   
        uint256 platformFee = (PLEDGE_AMOUNT * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 vakiCommission = (PLEDGE_AMOUNT * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 expectedRefund = PLEDGE_AMOUNT - PAYMENT_GATEWAY_FEE - platformFee - vakiCommission;

        assertEq(refundAmount, expectedRefund);
        assertEq(claimer, users.backer1Address);
        assertEq(backerBalanceAfter - backerBalanceBefore, refundAmount);
    }

    function test_disburseFees() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledges with gateway fees
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_2, PAYMENT_GATEWAY_FEE);
        pledgeWithoutAReward(
            users.backer2Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_2, PLEDGE_AMOUNT, 0, LAUNCH_TIME
        );

        // Approve and withdraw
        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));
        withdraw(address(keepWhatsRaised), PLEDGE_AMOUNT, DEADLINE - 1 days);

        uint256 protocolAdminBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        (Vm.Log[] memory logs, uint256 protocolShare, uint256 platformShare) =
            disburseFees(address(keepWhatsRaised), block.timestamp);

        uint256 protocolAdminBalanceAfter = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformAdminBalanceAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(
            protocolAdminBalanceAfter - protocolAdminBalanceBefore, protocolShare, "Incorrect protocol fee disbursed"
        );
        assertEq(
            platformAdminBalanceAfter - platformAdminBalanceBefore, platformShare, "Incorrect platform fee disbursed"
        );
        assertTrue(protocolShare > 0, "Protocol share should be greater than zero");
        assertTrue(platformShare > 0, "Platform share should be greater than zero");
    }

    function test_updateDeadlineByPlatformAdmin() external {
        vm.warp(LAUNCH_TIME + 1 days);

        uint256 originalDeadline = keepWhatsRaised.getDeadline();
        uint256 newDeadline = originalDeadline + 14 days;

        updateDeadline(users.platform2AdminAddress, address(keepWhatsRaised), newDeadline);

        assertEq(keepWhatsRaised.getDeadline(), newDeadline);
    }

    function test_updateDeadlineByCampaignOwner() external {
        vm.warp(LAUNCH_TIME + 1 days);

        uint256 originalDeadline = keepWhatsRaised.getDeadline();
        uint256 newDeadline = originalDeadline + 14 days;
        
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        updateDeadline(campaignOwner, address(keepWhatsRaised), newDeadline);

        assertEq(keepWhatsRaised.getDeadline(), newDeadline);
    }

    function test_updateGoalAmountByPlatformAdmin() external {
        vm.warp(LAUNCH_TIME + 1 days);

        uint256 originalGoal = keepWhatsRaised.getGoalAmount();
        uint256 newGoal = originalGoal * 3;

        updateGoalAmount(users.platform2AdminAddress, address(keepWhatsRaised), newGoal);

        assertEq(keepWhatsRaised.getGoalAmount(), newGoal);
    }

    function test_updateGoalAmountByCampaignOwner() external {
        vm.warp(LAUNCH_TIME + 1 days);

        uint256 originalGoal = keepWhatsRaised.getGoalAmount();
        uint256 newGoal = originalGoal * 3;
        
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        updateGoalAmount(campaignOwner, address(keepWhatsRaised), newGoal);

        assertEq(keepWhatsRaised.getGoalAmount(), newGoal);
    }

    function test_approveWithdrawal() external {
        assertFalse(keepWhatsRaised.getWithdrawalApprovalStatus());

        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));

        assertTrue(keepWhatsRaised.getWithdrawalApprovalStatus());
    }

    function test_withdraw() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledges
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_2, PAYMENT_GATEWAY_FEE);
        pledgeWithoutAReward(
            users.backer2Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_2, GOAL_AMOUNT, TIP_AMOUNT, LAUNCH_TIME
        );

        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;
        address actualOwner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(actualOwner);

        (Vm.Log[] memory logs, address to, uint256 withdrawalAmount, uint256 fee) =
            withdraw(address(keepWhatsRaised), 0, DEADLINE + 1 days);

        uint256 ownerBalanceAfter = testToken.balanceOf(actualOwner);

        assertEq(to, actualOwner, "Incorrect address receiving the funds");
        assertTrue(withdrawalAmount < totalPledged, "Should have fees deducted");
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawalAmount, "Incorrect balance change");
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0, "Available amount should be zero");
    }

    function test_withdrawPartial() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeWithoutAReward(
            users.backer1Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_1, PLEDGE_AMOUNT, 0, LAUNCH_TIME
        );

        // Approve withdrawal
        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));

        uint256 partialAmount = 500e18; // Withdraw less than full amount
        uint256 availableBefore = keepWhatsRaised.getAvailableRaisedAmount();

        (Vm.Log[] memory logs, address to, uint256 withdrawalAmount, uint256 fee) =
            withdraw(address(keepWhatsRaised), partialAmount, DEADLINE - 1 days);

        uint256 availableAfter = keepWhatsRaised.getAvailableRaisedAmount();

        assertEq(withdrawalAmount + fee, partialAmount, "Incorrect partial withdrawal");
        assertTrue(availableAfter < availableBefore, "Available amount should be reduced");
    }

    function test_claimTip() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledges with tips
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_2, PAYMENT_GATEWAY_FEE);
        pledgeWithoutAReward(
            users.backer2Address, address(testToken), address(keepWhatsRaised), TEST_PLEDGE_ID_2, GOAL_AMOUNT, TIP_AMOUNT * 2, LAUNCH_TIME
        );

        uint256 totalTips = TIP_AMOUNT + (TIP_AMOUNT * 2);
        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        // Claim tips after deadline
        (Vm.Log[] memory logs, uint256 amount, address claimer) =
            claimTip(users.platform2AdminAddress, address(keepWhatsRaised), DEADLINE + 1 days);

        uint256 platformAdminBalanceAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(amount, totalTips, "Incorrect tip amount");
        assertEq(claimer, users.platform2AdminAddress, "Incorrect claimer");
        assertEq(platformAdminBalanceAfter - platformAdminBalanceBefore, totalTips);
    }

    function test_claimFund() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make a pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        uint256 platformAdminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 expectedAmount = keepWhatsRaised.getAvailableRaisedAmount();

        // Claim fund after withdrawal delay has passed
        (Vm.Log[] memory logs, uint256 amount, address claimer) =
            claimFund(users.platform2AdminAddress, address(keepWhatsRaised), DEADLINE + WITHDRAWAL_DELAY + 1 days);

        uint256 platformAdminBalanceAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(amount, expectedAmount, "Incorrect fund amount");
        assertEq(claimer, users.platform2AdminAddress, "Incorrect claimer");
        assertEq(platformAdminBalanceAfter - platformAdminBalanceBefore, expectedAmount);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }

    function test_removeReward() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Verify reward exists before removal
        Reward memory rewardBefore = keepWhatsRaised.getReward(REWARD_NAMES[1]);
        assertEq(rewardBefore.rewardValue, REWARDS[1].rewardValue);

        // Remove the reward
        removeReward(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES[1]);

        // Verify reward is removed
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        keepWhatsRaised.getReward(REWARD_NAMES[1]);
    }

    function test_cancelTreasuryByPlatformAdmin() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make a pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        bytes32 cancellationMessage = keccak256(abi.encodePacked("Platform cancellation"));

        // Cancel by platform admin
        cancelTreasury(users.platform2AdminAddress, address(keepWhatsRaised), cancellationMessage);

        // Verify campaign is cancelled
        vm.startPrank(users.backer2Address);
        testToken.approve(address(keepWhatsRaised), PLEDGE_AMOUNT);
        vm.expectRevert();
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID_2, users.backer2Address, PLEDGE_AMOUNT, 0);
        vm.stopPrank();
    }

    function test_cancelTreasuryByCampaignOwner() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make a pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        bytes32 cancellationMessage = keccak256(abi.encodePacked("Owner cancellation"));
        address campaignOwner = CampaignInfo(campaignAddress).owner();

        // Cancel by campaign owner
        cancelTreasury(campaignOwner, address(keepWhatsRaised), cancellationMessage);

        // Verify campaign is cancelled
        vm.startPrank(users.backer2Address);
        testToken.approve(address(keepWhatsRaised), PLEDGE_AMOUNT);
        vm.expectRevert();
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID_2, users.backer2Address, PLEDGE_AMOUNT, 0);
        vm.stopPrank();
    }

    function test_refundAfterCancellation() external {
        addRewards(users.creator1Address, address(keepWhatsRaised), REWARD_NAMES, REWARDS);

        // Make pledge with gateway fee
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID_1, PAYMENT_GATEWAY_FEE);
        (, uint256 tokenId,) = pledgeForAReward(
            users.backer1Address,
            address(testToken),
            address(keepWhatsRaised),
            TEST_PLEDGE_ID_1,
            PLEDGE_AMOUNT,
            TIP_AMOUNT,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        // Cancel campaign
        cancelTreasury(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cancelled"));

        uint256 backerBalanceBefore = testToken.balanceOf(users.backer1Address);

        // Try to claim refund immediately after cancellation
        vm.warp(block.timestamp + 1);
        (Vm.Log[] memory refundLogs, uint256 refundedTokenId, uint256 refundAmount, address claimer) =
            claimRefund(users.backer1Address, address(keepWhatsRaised), tokenId);

        uint256 backerBalanceAfter = testToken.balanceOf(users.backer1Address);

        assertEq(refundedTokenId, tokenId);

        uint256 platformFee = (PLEDGE_AMOUNT * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 vakiCommission = (PLEDGE_AMOUNT * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 expectedRefund = PLEDGE_AMOUNT - PAYMENT_GATEWAY_FEE - platformFee - vakiCommission;
        
        assertEq(refundAmount, expectedRefund, "Refund amount should be pledge minus fees");
        assertEq(claimer, users.backer1Address);
        assertEq(backerBalanceAfter - backerBalanceBefore, refundAmount);
    }
}