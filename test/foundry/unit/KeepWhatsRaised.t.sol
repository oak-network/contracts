// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../integration/KeepWhatsRaised/KeepWhatsRaised.t.sol";
import "forge-std/Test.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {TestToken} from "../../mocks/TestToken.sol";
import {Defaults} from "../Base.t.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";

contract KeepWhatsRaised_UnitTest is Test, KeepWhatsRaised_Integration_Shared_Test {
    
    // Test constants
    uint256 internal constant TEST_PLEDGE_AMOUNT = 1000e18;
    uint256 internal constant TEST_TIP_AMOUNT = 50e18;
    bytes32 internal constant TEST_REWARD_NAME = keccak256("testReward");
    bytes32 internal constant TEST_PLEDGE_ID = keccak256("testPledgeId");
    
    function setUp() public virtual override {
        super.setUp();
        deal(address(testToken), users.backer1Address, 100_000e18);
        deal(address(testToken), users.backer2Address, 100_000e18);
        
        // Label addresses
        vm.label(users.protocolAdminAddress, "ProtocolAdmin");
        vm.label(users.platform2AdminAddress, "PlatformAdmin");
        vm.label(users.contractOwner, "CampaignOwner");
        vm.label(users.backer1Address, "Backer1");
        vm.label(users.backer2Address, "Backer2"); 
        vm.label(address(keepWhatsRaised), "KeepWhatsRaised");
        vm.label(address(globalParams), "GlobalParams");
    }
    
    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    
    function testInitialize() public {
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("newCampaign"));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = PLATFORM_2_HASH;
        
        // Pass empty arrays since platform data is not used by the new treasury
        bytes32[] memory platformDataKey = new bytes32[](0);
        bytes32[] memory platformDataValue = new bytes32[](0);
        
        vm.prank(users.creator1Address);
        campaignInfoFactory.createCampaign(
            users.creator1Address,
            newIdentifierHash,
            selectedPlatformHash,
            platformDataKey,        // Empty array
            platformDataValue,      // Empty array
            CAMPAIGN_DATA
        );
        
        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);
        
        // Deploy
        vm.prank(users.platform2AdminAddress);
        address newTreasury = treasuryFactory.deploy(
            PLATFORM_2_HASH,
            newCampaignAddress,
            1,
            "NewCampaign",
            "NC"
        );
        
        KeepWhatsRaised newContract = KeepWhatsRaised(newTreasury);
        
        assertEq(newContract.name(), "NewCampaign");
        assertEq(newContract.symbol(), "NC");
    }
    
    /*//////////////////////////////////////////////////////////////
                        TREASURY CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    function testConfigureTreasury() public {
        ICampaignData.CampaignData memory newCampaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp + 1 days,
            deadline: block.timestamp + 31 days,
            goalAmount: 5000
        });
        
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, newCampaignData, FEE_KEYS, feeValues);
        
        assertEq(keepWhatsRaised.getLaunchTime(), newCampaignData.launchTime);
        assertEq(keepWhatsRaised.getDeadline(), newCampaignData.deadline);
        assertEq(keepWhatsRaised.getGoalAmount(), newCampaignData.goalAmount);
        
        // Verify fee values are stored
        assertEq(keepWhatsRaised.getFeeValue(FLAT_FEE_KEY), uint256(FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(CUMULATIVE_FLAT_FEE_KEY), uint256(CUMULATIVE_FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(PLATFORM_FEE_KEY), uint256(PLATFORM_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(VAKI_COMMISSION_KEY), uint256(VAKI_COMMISSION_VALUE));
    }
    
    function testConfigureTreasuryWithColombianCreator() public {
        ICampaignData.CampaignData memory newCampaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp + 1 days,
            deadline: block.timestamp + 31 days,
            goalAmount: 5000
        });
        
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, newCampaignData, FEE_KEYS, feeValues);
        
        // Test that Colombian creator tax is not applied in pledges
        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(keepWhatsRaised.getLaunchTime());
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, 0, rewardSelection);
        vm.stopPrank();
        
        // Available amount should not include Colombian tax deduction at pledge time
        uint256 availableAmount = keepWhatsRaised.getAvailableRaisedAmount();
        uint256 expectedWithoutColombianTax = TEST_PLEDGE_AMOUNT 
            - (TEST_PLEDGE_AMOUNT * PLATFORM_FEE_PERCENT / PERCENT_DIVIDER) 
            - (TEST_PLEDGE_AMOUNT * 6 * 100 / PERCENT_DIVIDER)
            - (TEST_PLEDGE_AMOUNT * PROTOCOL_FEE_PERCENT / PERCENT_DIVIDER);
        assertEq(availableAmount, expectedWithoutColombianTax, "Colombian tax should not be applied at pledge time");
    }
    
    function testConfigureTreasuryRevertWhenNotPlatformAdmin() public {
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
    }
    
    function testConfigureTreasuryRevertWhenInvalidCampaignData() public {
        // Invalid launch time (in the past)
        ICampaignData.CampaignData memory invalidCampaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp - 1,
            deadline: block.timestamp + 31 days,
            goalAmount: 5000
        });
        
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, invalidCampaignData, FEE_KEYS, feeValues);
    }
    
    function testConfigureTreasuryRevertWhenMismatchedFeeArrays() public {
        // Create mismatched fee arrays
        KeepWhatsRaised.FeeKeys memory mismatchedKeys = FEE_KEYS;
        KeepWhatsRaised.FeeValues memory mismatchedValues = _createFeeValues();
        mismatchedValues.grossPercentageFeeValues = new uint256[](1); // Wrong length
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, mismatchedKeys, mismatchedValues);
    }
    
    /*//////////////////////////////////////////////////////////////
                        PAYMENT GATEWAY FEES
    //////////////////////////////////////////////////////////////*/
    
    function testSetPaymentGatewayFee() public {
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.setPaymentGatewayFee(TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        assertEq(keepWhatsRaised.getPaymentGatewayFee(TEST_PLEDGE_ID), PAYMENT_GATEWAY_FEE);
    }
    
    function testSetPaymentGatewayFeeRevertWhenNotPlatformAdmin() public {
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.setPaymentGatewayFee(TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
    }
    
    function testSetPaymentGatewayFeeRevertWhenPaused() public {
        _pauseTreasury();
        
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.setPaymentGatewayFee(TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
    }
    
    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL APPROVAL
    //////////////////////////////////////////////////////////////*/
    
    function testApproveWithdrawal() public {
        assertFalse(keepWhatsRaised.getWithdrawalApprovalStatus());
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        assertTrue(keepWhatsRaised.getWithdrawalApprovalStatus());
    }
    
    function testApproveWithdrawalRevertWhenAlreadyApproved() public {
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyEnabled.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
    }
    
    function testApproveWithdrawalRevertWhenNotPlatformAdmin() public {
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.approveWithdrawal();
    }
    
    /*//////////////////////////////////////////////////////////////
                        DEADLINE AND GOAL UPDATES
    //////////////////////////////////////////////////////////////*/
    
    function testUpdateDeadlineByPlatformAdmin() public {
        uint256 newDeadline = DEADLINE + 10 days;
        
        vm.warp(LAUNCH_TIME + 1 days); // Within config lock period
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(newDeadline);
        
        assertEq(keepWhatsRaised.getDeadline(), newDeadline);
    }
    
    function testUpdateDeadlineByCampaignOwner() public {
        uint256 newDeadline = DEADLINE + 10 days;
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(campaignOwner);
        keepWhatsRaised.updateDeadline(newDeadline);
        
        assertEq(keepWhatsRaised.getDeadline(), newDeadline);
    }
    
    function testUpdateDeadlineRevertWhenNotAuthorized() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedUnAuthorized.selector);
        vm.prank(users.backer1Address);
        keepWhatsRaised.updateDeadline(DEADLINE + 10 days);
    }
    
    function testUpdateDeadlineRevertWhenPastConfigLock() public {
        // Warp to past config lock period
        vm.warp(DEADLINE - CONFIG_LOCK_PERIOD + 1);
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedConfigLocked.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(DEADLINE + 10 days);
    }
    
    function testUpdateDeadlineRevertWhenDeadlineBeforeLaunchTime() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(LAUNCH_TIME - 1);
    }
    
    function testUpdateDeadlineRevertWhenDeadlineBeforeCurrentTime() public {
        vm.warp(LAUNCH_TIME + 5 days);
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(LAUNCH_TIME + 4 days);
    }
    
    function testUpdateDeadlineRevertWhenPaused() public {
        _pauseTreasury();
        
        // Try to update deadline 
        vm.warp(LAUNCH_TIME + 1 days);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(DEADLINE + 10 days);
    }
    
    function testUpdateGoalAmountByPlatformAdmin() public {
        uint256 newGoal = GOAL_AMOUNT * 2;
        
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateGoalAmount(newGoal);
        
        assertEq(keepWhatsRaised.getGoalAmount(), newGoal);
    }
    
    function testUpdateGoalAmountByCampaignOwner() public {
        uint256 newGoal = GOAL_AMOUNT * 2;
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(campaignOwner);
        keepWhatsRaised.updateGoalAmount(newGoal);
        
        assertEq(keepWhatsRaised.getGoalAmount(), newGoal);
    }
    
    function testUpdateGoalAmountRevertWhenNotAuthorized() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedUnAuthorized.selector);
        vm.prank(users.backer1Address);
        keepWhatsRaised.updateGoalAmount(GOAL_AMOUNT * 2);
    }
    
    function testUpdateGoalAmountRevertWhenZero() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateGoalAmount(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                            REWARDS MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    function testAddRewards() public {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
        
        Reward memory retrievedReward = keepWhatsRaised.getReward(TEST_REWARD_NAME);
        assertEq(retrievedReward.rewardValue, TEST_PLEDGE_AMOUNT);
        assertTrue(retrievedReward.isRewardTier);
    }
    
    function testAddRewardsRevertWhenMismatchedArrays() public {
        bytes32[] memory rewardNames = new bytes32[](2);
        Reward[] memory rewards = new Reward[](1);
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }
    
    function testAddRewardsRevertWhenDuplicateReward() public {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        // Add first time
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
        
        // Try to add again
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedRewardExists.selector);
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }
    
    function testRemoveReward() public {
        // First add a reward
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
        
        // Remove reward
        vm.prank(users.creator1Address);
        keepWhatsRaised.removeReward(TEST_REWARD_NAME);
        
        // Verify removal
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        keepWhatsRaised.getReward(TEST_REWARD_NAME);
    }
    
    function testRemoveRewardRevertWhenRewardDoesNotExist() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        vm.prank(users.creator1Address);
        keepWhatsRaised.removeReward(TEST_REWARD_NAME);
    }
    
    function testAddRewardsRevertWhenPaused() public {
        _pauseTreasury();
        
        // Try to add rewards
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        vm.expectRevert();
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }
    
    function testRemoveRewardRevertWhenPaused() public {
        // First add a reward
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
        
        _pauseTreasury();
        
        // Try to remove reward - should revert
        vm.expectRevert();
        vm.prank(users.creator1Address);
        keepWhatsRaised.removeReward(TEST_REWARD_NAME);
    }
    
    /*//////////////////////////////////////////////////////////////
                              PLEDGING
    //////////////////////////////////////////////////////////////*/
    
    function testPledgeForAReward() public {
        // Add reward first
        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);
        
        // Pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_TIP_AMOUNT, rewardSelection);
        vm.stopPrank();
        
        // Verify
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore - TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT);
        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < TEST_PLEDGE_AMOUNT); // Less due to fees
        assertEq(keepWhatsRaised.balanceOf(users.backer1Address), 1);
    }
    
    function testPledgeForARewardRevertWhenDuplicatePledgeId() public {
        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT * 2);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        // First pledge
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, 0, rewardSelection);
        
        // Try to pledge with same ID
        bytes32 internalPledgeId = keccak256(abi.encodePacked(TEST_PLEDGE_ID, users.backer1Address));
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedPledgeAlreadyProcessed.selector, internalPledgeId));
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, 0, rewardSelection);
        vm.stopPrank();
    }
    
    function testPledgeForARewardRevertWhenNotRewardTier() public {
        // Add non-reward tier
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, false); 
        
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
        
        // Try to pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, 0, rewardSelection);
        vm.stopPrank();
    }
    
    function testPledgeWithoutAReward() public {
        uint256 pledgeAmount = 500e18;
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);
        
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        // Pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), pledgeAmount + TEST_TIP_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, pledgeAmount, TEST_TIP_AMOUNT);
        vm.stopPrank();
        
        // Verify
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore - pledgeAmount - TEST_TIP_AMOUNT);
        assertEq(keepWhatsRaised.getRaisedAmount(), pledgeAmount);
        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < pledgeAmount); // Less due to fees
        assertEq(keepWhatsRaised.balanceOf(users.backer1Address), 1);
    }
    
    function testPledgeWithoutARewardRevertWhenDuplicatePledgeId() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT * 2);
        
        // First pledge
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        
        // Try to pledge with same ID - internal pledge ID includes caller
        bytes32 internalPledgeId = keccak256(abi.encodePacked(TEST_PLEDGE_ID, users.backer1Address));
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedPledgeAlreadyProcessed.selector, internalPledgeId));
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        vm.stopPrank();
    }
    
    function testPledgeRevertWhenOutsideCampaignPeriod() public {
        // Before launch
        vm.warp(LAUNCH_TIME - 1);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        
        // After deadline
        vm.warp(DEADLINE + 1);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("newPledge"), users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
    }
    
    function testPledgeForARewardRevertWhenPaused() public {
        // Add reward first
        _setupReward();
        
        _pauseTreasury();
        
        // Try to pledge 
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        vm.expectRevert();
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_TIP_AMOUNT, rewardSelection);
        vm.stopPrank();
    }
    
    function testSetFeeAndPledge() public {
        _setupReward();
        
        vm.warp(LAUNCH_TIME);
        
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        
        // Fund admin with tokens since they will be the token source
        deal(address(testToken), users.platform2AdminAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID, 
            users.backer1Address, 
            0, // ignored for reward pledges
            TEST_TIP_AMOUNT, 
            PAYMENT_GATEWAY_FEE, 
            rewardSelection, 
            true
        );
        vm.stopPrank();
        
        // Verify fee was set
        assertEq(keepWhatsRaised.getPaymentGatewayFee(TEST_PLEDGE_ID), PAYMENT_GATEWAY_FEE);
        
        // Verify pledge was made
        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
        assertEq(keepWhatsRaised.balanceOf(users.backer1Address), 1);
    }
    
    /*//////////////////////////////////////////////////////////////
                            WITHDRAWALS
    //////////////////////////////////////////////////////////////*/
    
    function testWithdrawFullAmountAfterDeadline() public {
        // Setup pledges
        _setupPledges();
        
        // Approve withdrawal
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);
        
        // Withdraw after deadline (as platform admin)
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        
        // Verify (accounting for fees)
        assertTrue(ownerBalanceAfter > ownerBalanceBefore);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }
    
    function testWithdrawPartialAmountBeforeDeadline() public {
        // Setup pledges
        _setupPledges();
        
        // Approve withdrawal
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        uint256 partialAmount = 500e18;
        uint256 availableBefore = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Withdraw partial amount before deadline (as platform admin)
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(partialAmount);
        
        uint256 availableAfter = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Verify - available is reduced by withdrawal plus fees
        assertTrue(availableAfter < availableBefore - partialAmount);
    }
    
    function testWithdrawRevertWhenNotApproved() public {
        _setupPledges();
        
        vm.warp(DEADLINE + 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedDisabled.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
    }
    
    function testWithdrawRevertWhenAmountExceedsAvailable() public {
        _setupPledges();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();
        
        vm.warp(LAUNCH_TIME + 1 days);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(available + 1e18);
    }
    
    function testWithdrawRevertWhenAlreadyWithdrawn() public {
        _setupPledges();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        // First withdrawal
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        // Second withdrawal attempt
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyWithdrawn.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
    }
    
    function testWithdrawRevertWhenPaused() public {
        // Setup pledges and approve withdrawal first
        _setupPledges();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        _pauseTreasury();
        
        // Try to withdraw 
        vm.warp(DEADLINE + 1);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
    }
    
    function testWithdrawWithMinimumFeeExemption() public {
        // Calculate pledge amount needed to have available amount above exemption after fees
        // We need the available amount after all pledge fees to be > MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION
        // Total fees during pledge: platform (10%) + vaki (6%) + protocol (20%) = 36%
        // So available = pledge * 0.64
        // We need: pledge * 0.64 > 50,000e18
        // Therefore: pledge > 78,125e18
        uint256 largePledge = 80_000e18;
   
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), largePledge);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, largePledge, 0);
        vm.stopPrank();
        
        uint256 availableAfterPledge = keepWhatsRaised.getAvailableRaisedAmount();

        // Verify available amount is above exemption threshold
        assertTrue(availableAfterPledge > MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION, "Available amount should be above exemption threshold");
        
        // Approve and withdraw
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);
        
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        uint256 received = ownerBalanceAfter - ownerBalanceBefore;
   
        // For final withdrawal above exemption threshold, no flat fee is applied
        // The owner should receive the full available amount
        assertEq(received, availableAfterPledge, "Should receive full available amount without flat fee");
    }
    
    function testWithdrawWithColombianCreatorTax() public {
        // Configure with Colombian creator
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);
        
        // Make a pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        vm.stopPrank();
        
        // Approve withdrawal
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);
        uint256 availableBeforeWithdraw = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Withdraw after deadline
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        uint256 received = ownerBalanceAfter - ownerBalanceBefore;
        
        // Calculate expected amount after Colombian tax
        uint256 flatFee = uint256(FLAT_FEE_VALUE);
        uint256 amountAfterFlatFee = availableBeforeWithdraw - flatFee;
        
        // Colombian tax: (availableBeforeWithdraw * 0.004) / 1.004
        uint256 colombianTax = (availableBeforeWithdraw * 40) / 10040;
        uint256 expectedAmount = amountAfterFlatFee - colombianTax;
        
        assertApproxEqAbs(received, expectedAmount, 10, "Should receive amount minus flat fee and Colombian tax");
    }
    
    /*//////////////////////////////////////////////////////////////
                              REFUNDS
    //////////////////////////////////////////////////////////////*/
    
    function testClaimRefundAfterDeadline() public {
        // Make pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenId = 0;
        vm.stopPrank();
        
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);
        
        // Claim refund within refund window
        vm.warp(DEADLINE + 1 days);
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
        
        // Calculate expected refund (pledge minus all fees including protocol)
        uint256 platformFee = (TEST_PLEDGE_AMOUNT * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 vakiCommission = (TEST_PLEDGE_AMOUNT * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 protocolFee = (TEST_PLEDGE_AMOUNT * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedRefund = TEST_PLEDGE_AMOUNT - PAYMENT_GATEWAY_FEE - platformFee - vakiCommission - protocolFee;
        
        // Verify refund amount is pledge minus fees
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore + expectedRefund);
        vm.expectRevert();
        keepWhatsRaised.ownerOf(tokenId); // Token should be burned
    }
    
    function testClaimRefundRevertWhenOutsideRefundWindow() public {
        // Make pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenId = 0;
        vm.stopPrank();
        
        // Try to claim after refund window
        vm.warp(DEADLINE + REFUND_DELAY + 1);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
    }
    
    function testClaimRefundAfterCancellation() public {
        // Make pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenId = 0;
        vm.stopPrank();
        
        // Cancel campaign
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.cancelTreasury(keccak256("cancelled"));
        
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);
        
        // Claim refund
        vm.warp(block.timestamp + 1);
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
        
        // Calculate expected refund (pledge minus all fees)
        uint256 platformFee = (TEST_PLEDGE_AMOUNT * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 vakiCommission = (TEST_PLEDGE_AMOUNT * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 protocolFee = (TEST_PLEDGE_AMOUNT * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedRefund = TEST_PLEDGE_AMOUNT - PAYMENT_GATEWAY_FEE - platformFee - vakiCommission - protocolFee;
        
        // Verify refund amount is pledge minus fees
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore + expectedRefund);
    }
    
    function testClaimRefundRevertWhenPaused() public {
        // Make pledge first
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenId = 0;
        vm.stopPrank();
        
        _pauseTreasury();
        
        // Try to claim refund 
        vm.warp(DEADLINE + 1 days);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
    }
    
    function testClaimRefundRevertWhenInsufficientFunds() public {
        // Make pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenId = 0;
        vm.stopPrank();
        
        // Withdraw all funds
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        // Try to claim refund 
        vm.warp(DEADLINE + 1 days);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
    }
    
    /*//////////////////////////////////////////////////////////////
                        TIPS AND FUNDS CLAIMING
    //////////////////////////////////////////////////////////////*/
    
    function testClaimTipAfterDeadline() public {
        // Setup pledges with tips
        _setupPledges();
        
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 totalTips = TEST_TIP_AMOUNT * 2;
        
        // Claim tips after deadline
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
        
        // Verify
        assertEq(testToken.balanceOf(users.platform2AdminAddress), platformBalanceBefore + totalTips);
    }
    
    function testClaimTipRevertWhenBeforeDeadline() public {
        _setupPledges();
        
        vm.warp(DEADLINE - 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedNotClaimableAdmin.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
    }
    
    function testClaimTipRevertWhenAlreadyClaimed() public {
        _setupPledges();
        
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyClaimed.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
    }
    
    function testClaimTipRevertWhenPaused() public {
        // Setup pledges with tips
        _setupPledges();
        _pauseTreasury();
 
        vm.warp(DEADLINE + 1);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
    }
    
    function testClaimFundAfterWithdrawalDelay() public {
        // Setup pledges
        _setupPledges();
        
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 availableFunds = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Claim funds after withdrawal delay
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
        
        // Verify
        assertEq(testToken.balanceOf(users.platform2AdminAddress), platformBalanceBefore + availableFunds);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }
    
    function testClaimFundAfterCancellation() public {
        // Setup pledges
        _setupPledges();
        
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 availableFunds = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Cancel treasury
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.cancelTreasury(keccak256("cancelled"));
        
        // Claim funds after refund delay from cancellation
        vm.warp(block.timestamp + REFUND_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
        
        // Verify
        assertEq(testToken.balanceOf(users.platform2AdminAddress), platformBalanceBefore + availableFunds);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }
    
    function testClaimFundRevertWhenBeforeWithdrawalDelay() public {
        _setupPledges();
        
        vm.warp(DEADLINE + WITHDRAWAL_DELAY - 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedNotClaimableAdmin.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
    }
    
    function testClaimFundRevertWhenAlreadyClaimed() public {
        _setupPledges();
        
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
        
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyClaimed.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
    }
    
    function testClaimFundRevertWhenPaused() public {
        // Setup pledges
        _setupPledges();     
        _pauseTreasury();

        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();
    }
    
    /*//////////////////////////////////////////////////////////////
                            FEE DISBURSEMENT
    //////////////////////////////////////////////////////////////*/
    
    function testDisburseFees() public {
        // Setup pledges - protocol fees are collected during pledge
        _setupPledges();
        
        // Approve and withdraw to generate withdrawal fees
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        
        // Disburse fees immediately
        keepWhatsRaised.disburseFees();
        
        // Verify fees were distributed
        assertTrue(testToken.balanceOf(users.protocolAdminAddress) > protocolBalanceBefore);
        assertTrue(testToken.balanceOf(users.platform2AdminAddress) > platformBalanceBefore);
    }
    
    function testDisburseFeesRevertWhenPaused() public {
        // Setup pledges and withdraw to generate fees
        _setupPledges();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
        
        _pauseTreasury();
        
        // Try to disburse fees - should revert
        vm.expectRevert();
        keepWhatsRaised.disburseFees();
    }
    
    /*//////////////////////////////////////////////////////////////
                          CANCEL TREASURY
    //////////////////////////////////////////////////////////////*/
    
    function testCancelTreasuryByPlatformAdmin() public {
        bytes32 message = keccak256("Platform cancellation");
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.cancelTreasury(message);
        
        // Verify campaign is cancelled
        vm.warp(LAUNCH_TIME);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
    }
    
    function testCancelTreasuryByCampaignOwner() public {
        bytes32 message = keccak256("Owner cancellation");
        address campaignOwner = CampaignInfo(campaignAddress).owner();
        
        vm.prank(campaignOwner);
        keepWhatsRaised.cancelTreasury(message);
        
        // Verify campaign is cancelled
        vm.warp(LAUNCH_TIME);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
    }
    
    function testCancelTreasuryRevertWhenUnauthorized() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedUnAuthorized.selector);
        vm.prank(users.backer1Address);
        keepWhatsRaised.cancelTreasury(keccak256("unauthorized"));
    }
    
    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/
    
    function testMultiplePartialWithdrawals() public {
        _setupPledges();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();
  
        // First withdrawal: small amount that will incur cumulative fee
        // Need to ensure available >= withdrawal + cumulativeFee
        uint256 firstWithdrawal = 200e18; // Reduced to ensure enough for fee
        
        // First withdrawal
        vm.warp(LAUNCH_TIME + 1 days);
        uint256 availableBefore1 = keepWhatsRaised.getAvailableRaisedAmount();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(firstWithdrawal);
        uint256 availableAfter1 = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Verify first withdrawal reduced available amount by withdrawal + fees
        uint256 expectedReduction1 = firstWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE);
        assertApproxEqAbs(availableBefore1 - availableAfter1, expectedReduction1, 10, "First withdrawal should reduce by amount plus cumulative fee");
        
        // Second withdrawal
        // Calculate safe amount based on remaining balance
        uint256 secondWithdrawal = 150e18; // Reduced to ensure enough for fee
        
        // Only do second withdrawal if we have enough funds
        if (availableAfter1 >= secondWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE)) {
            vm.warp(LAUNCH_TIME + 2 days);
            uint256 availableBefore2 = keepWhatsRaised.getAvailableRaisedAmount();
            vm.prank(users.platform2AdminAddress);
            keepWhatsRaised.withdraw(secondWithdrawal);
            uint256 availableAfter2 = keepWhatsRaised.getAvailableRaisedAmount();
            
            // Verify second withdrawal reduced available amount by withdrawal + fees
            uint256 expectedReduction2 = secondWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE);
            assertApproxEqAbs(availableBefore2 - availableAfter2, expectedReduction2, 10, "Second withdrawal should reduce by amount plus cumulative fee");
        }
        
        // Verify remaining amount
        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() > 0, "Should still have funds available");
    }
    
    function testWithdrawalRevertWhenFeesExceedAmount() public {
        // Make a small pledge
        uint256 smallPledge = 300e18; // Small enough that fees might exceed available
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), smallPledge);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, smallPledge, 0);
        vm.stopPrank();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
  
        // Try to withdraw partial amount that would cause available < withdrawal + fees
        vm.warp(LAUNCH_TIME + 1 days);
        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Try to withdraw an amount that with fees would exceed available
        uint256 withdrawAmount = available - 50e18; // Leave less than cumulative fee
        vm.expectRevert();
        keepWhatsRaised.withdraw(withdrawAmount);
    }
    
    function testZeroTipPledge() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        vm.stopPrank();
        
        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
    }
    
    function testFeeCalculationWithoutColombianTax() public {
        // Make a pledge (non-Colombian)
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        vm.stopPrank();
        
        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();
        uint256 platformFee = (TEST_PLEDGE_AMOUNT * uint256(PLATFORM_FEE_VALUE)) / PERCENT_DIVIDER;
        uint256 vakiCommission = (TEST_PLEDGE_AMOUNT * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 protocolFee = (TEST_PLEDGE_AMOUNT * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 totalFees = platformFee + vakiCommission + PAYMENT_GATEWAY_FEE + protocolFee;
        
        uint256 expectedAvailable = TEST_PLEDGE_AMOUNT - totalFees;
        
        assertEq(available, expectedAvailable);
    }
    
    function testGetRewardRevertWhenNotExists() public {
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector);
        keepWhatsRaised.getReward(keccak256("nonexistent"));
    }
    
    function testWithdrawRevertWhenZeroAfterDeadline() public {
        // No pledges made
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        vm.warp(DEADLINE + 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyWithdrawn.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                         COMPREHENSIVE FEE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testComplexFeeScenario() public {
        // Testing multiple pledges with different fee structures
        
        // Configure Colombian creator for complex fee testing
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);
        
        // Add rewards
        _setupReward();
        
        // Pledge 1: With reward and tip
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge1"), PAYMENT_GATEWAY_FEE);
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        keepWhatsRaised.pledgeForAReward(keccak256("pledge1"), users.backer1Address, TEST_TIP_AMOUNT, rewardSelection);
        vm.stopPrank();
        
        // Pledge 2: Without reward, different gateway fee
        uint256 differentGatewayFee = 20e18;
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge2"), differentGatewayFee);
        vm.startPrank(users.backer2Address);
        testToken.approve(address(keepWhatsRaised), 2000e18);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("pledge2"), users.backer2Address, 2000e18, 0);
        vm.stopPrank();
        
        // Verify total raised and available amounts
        uint256 totalRaised = keepWhatsRaised.getRaisedAmount();
        uint256 totalAvailable = keepWhatsRaised.getAvailableRaisedAmount();
        
        assertEq(totalRaised, TEST_PLEDGE_AMOUNT + 2000e18);
        assertTrue(totalAvailable < totalRaised); // No colombian tax yet
        
        // Test partial withdrawal with Colombian tax applied
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        uint256 partialWithdrawAmount = 1000e18;
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);
        
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(partialWithdrawAmount);
        
        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        uint256 netReceived = ownerBalanceAfter - ownerBalanceBefore;
        
        // Verify withdrawal amount equals requested (fees deducted from available)
        assertEq(netReceived, partialWithdrawAmount);
    }
    
    function testWithdrawalFeeStructure() public {
        // Testing different withdrawal scenarios and their fee implications
        
        // Small withdrawal (below exemption) before deadline
        uint256 smallAmount = 1000e18;
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("small"), 0);
        
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), smallAmount);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("small"), users.backer1Address, smallAmount, 0);
        vm.stopPrank();
        
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        
        address owner = CampaignInfo(campaignAddress).owner();
        uint256 balanceBefore = testToken.balanceOf(owner);
        
        // Calculate available after pledge fees
        uint256 availableBeforeWithdraw = keepWhatsRaised.getAvailableRaisedAmount();
        
        // Withdraw before deadline - should apply cumulative fee
        vm.warp(LAUNCH_TIME + 1 days);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(availableBeforeWithdraw - uint256(CUMULATIVE_FLAT_FEE_VALUE) - 10); // Leave small buffer
        
        uint256 received = testToken.balanceOf(owner) - balanceBefore;

        assertTrue(received > 0, "Should receive something");
    }
    
    /*//////////////////////////////////////////////////////////////
                            FEE VALUE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testGetFeeValue() public {
        // Test retrieval of stored fee values
        assertEq(keepWhatsRaised.getFeeValue(FLAT_FEE_KEY), uint256(FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(CUMULATIVE_FLAT_FEE_KEY), uint256(CUMULATIVE_FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(PLATFORM_FEE_KEY), uint256(PLATFORM_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(VAKI_COMMISSION_KEY), uint256(VAKI_COMMISSION_VALUE));
    }
    
    function testGetFeeValueForNonExistentKey() public {
        // Should return 0 for non-existent keys
        bytes32 nonExistentKey = keccak256("nonExistentFee");
        assertEq(keepWhatsRaised.getFeeValue(nonExistentKey), 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _createTestReward(uint256 value, bool isRewardTier) internal pure returns (Reward memory) {
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory itemValues = new uint256[](1);
        uint256[] memory itemQuantities = new uint256[](1);
        
        itemIds[0] = keccak256("testItem");
        itemValues[0] = value;
        itemQuantities[0] = 1;
        
        return Reward({
            rewardValue: value,
            isRewardTier: isRewardTier,
            itemId: itemIds,
            itemValue: itemValues,
            itemQuantity: itemQuantities
        });
    }
    
    function _setupReward() internal {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;
        
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true);
        
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }
    
    function _setupPledges() internal {
        _setupReward();
        
        // Set gateway fees for pledges
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge1"), PAYMENT_GATEWAY_FEE);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge2"), PAYMENT_GATEWAY_FEE);
        
        // Make pledges from two backers
        vm.warp(LAUNCH_TIME);
        
        // Backer 1 pledge with reward
        vm.startPrank(users.backer1Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        keepWhatsRaised.pledgeForAReward(keccak256("pledge1"), users.backer1Address, TEST_TIP_AMOUNT, rewardSelection);
        vm.stopPrank();
        
        // Backer 2 pledge without reward
        vm.startPrank(users.backer2Address);
        testToken.approve(address(keepWhatsRaised), TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("pledge2"), users.backer2Address, TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT);
        vm.stopPrank();
    }

    function _pauseTreasury() internal {
        // Pause treasury
        bytes32 message = keccak256("Pause");
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.pauseTreasury(message);
    }
    
    function _createFeeValues() internal pure returns (KeepWhatsRaised.FeeValues memory) {
        KeepWhatsRaised.FeeValues memory feeValues;
        feeValues.flatFeeValue = uint256(FLAT_FEE_VALUE);
        feeValues.cumulativeFlatFeeValue = uint256(CUMULATIVE_FLAT_FEE_VALUE);
        feeValues.grossPercentageFeeValues = new uint256[](2);
        feeValues.grossPercentageFeeValues[0] = uint256(PLATFORM_FEE_VALUE);
        feeValues.grossPercentageFeeValues[1] = uint256(VAKI_COMMISSION_VALUE);
        return feeValues;
    }
}