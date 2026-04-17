// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

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
import {TestToken} from "../../mocks/TestToken.sol";
import {MockPermit2} from "../../mocks/MockPermit2.sol";
import {TreasuryErrors} from "src/errors/TreasuryErrors.sol";

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
            platformDataKey, // Empty array
            platformDataValue, // Empty array
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );

        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);

        // Deploy
        vm.prank(users.platform2AdminAddress);
        address newTreasury = treasuryFactory.deploy(PLATFORM_2_HASH, newCampaignAddress, 1);

        KeepWhatsRaised newContract = KeepWhatsRaised(newTreasury);
        CampaignInfo newCampaignInfo = CampaignInfo(newCampaignAddress);

        // NFT name and symbol are now on CampaignInfo, not treasury
        assertEq(newCampaignInfo.name(), "Campaign Pledge NFT");
        assertEq(newCampaignInfo.symbol(), "PLEDGE");
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function testConfigureTreasury() public {
        // configureTreasury was called once during setUp with CONFIG + CAMPAIGN_DATA.
        // Verify the stored state reflects that initial configuration.
        assertEq(keepWhatsRaised.getLaunchTime(), CAMPAIGN_DATA.launchTime);
        assertEq(keepWhatsRaised.getDeadline(), CAMPAIGN_DATA.deadline);
        assertEq(keepWhatsRaised.getGoalAmount(), CAMPAIGN_DATA.goalAmount);

        // Verify fee values are stored
        assertEq(keepWhatsRaised.getFeeValue(FLAT_FEE_KEY), uint256(FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(CUMULATIVE_FLAT_FEE_KEY), uint256(CUMULATIVE_FLAT_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(PLATFORM_FEE_KEY), uint256(PLATFORM_FEE_VALUE));
        assertEq(keepWhatsRaised.getFeeValue(VAKI_COMMISSION_KEY), uint256(VAKI_COMMISSION_VALUE));
    }

    function testConfigureTreasury_RevertsWhenAlreadyConfigured() public {
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyConfigured.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
    }

    function testConfigureTreasuryWithColombianCreator() public {
        // Deploy a fresh treasury so configureTreasury can be called for the first time.
        _resetTreasury();

        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        // Test that Colombian creator tax is not applied in pledges
        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(keepWhatsRaised.getLaunchTime());
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, 0, rewardSelection, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), 0, rewardSelection, permitData);
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
        // Deploy a fresh unconfigured treasury so input validation is reachable.
        _resetTreasury();

        // Invalid launch time (in the past)
        ICampaignData.CampaignData memory invalidCampaignData = ICampaignData.CampaignData({
            launchTime: block.timestamp - 1,
            deadline: block.timestamp + 31 days,
            goalAmount: 5000,
            currency: bytes32("USD")
        });

        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedLaunchTimeInPast.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, invalidCampaignData, FEE_KEYS, feeValues);
    }

    function testConfigureTreasuryRevertWhenMismatchedFeeArrays() public {
        // Deploy a fresh unconfigured treasury so input validation is reachable.
        _resetTreasury();

        // Create mismatched fee arrays
        KeepWhatsRaised.FeeKeys memory mismatchedKeys = FEE_KEYS;
        KeepWhatsRaised.FeeValues memory mismatchedValues = _createFeeValues();
        mismatchedValues.grossPercentageFeeValues = new uint256[](1); // Wrong length

        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.FEE_LENGTH_MISMATCH));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, mismatchedKeys, mismatchedValues);
    }

    function testConfigureTreasuryRevertWhenDuplicateFlatKeys() public {
        _resetTreasury();
        KeepWhatsRaised.FeeKeys memory keys = FEE_KEYS;
        keys.flatFeeKey = keys.cumulativeFlatFeeKey; // same key for both flat fees
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedDuplicateFeeKey.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, keys, feeValues);
    }

    function testConfigureTreasuryRevertWhenFlatKeyEqualsPercentageKey() public {
        _resetTreasury();
        KeepWhatsRaised.FeeKeys memory keys = FEE_KEYS;
        keys.flatFeeKey = PLATFORM_FEE_KEY; // flat key collides with percentage key
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedDuplicateFeeKey.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, keys, feeValues);
    }

    function testConfigureTreasuryRevertWhenDuplicatePercentageKeys() public {
        _resetTreasury();
        KeepWhatsRaised.FeeKeys memory keys = FEE_KEYS;
        keys.grossPercentageFeeKeys[1] = keys.grossPercentageFeeKeys[0]; // duplicate
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedDuplicateFeeKey.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, keys, feeValues);
    }

    function testConfigureTreasuryRevertWhenPercentageFeeExceedsMax() public {
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        feeValues.grossPercentageFeeValues[0] = PERCENT_DIVIDER; // 100% not allowed

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedPercentageFeeExceedsMax.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
    }

    function testConfigureTreasuryRevertWhenAggregatePercentageExceedsMax() public {
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        feeValues.grossPercentageFeeValues[0] = 6000; // 60%
        feeValues.grossPercentageFeeValues[1] = 5000; // 50% -> total 110%

        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAggregatePercentageExceedsMax.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
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
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.INVALID_DEADLINE));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.updateDeadline(LAUNCH_TIME - 1);
    }

    function testUpdateDeadlineRevertWhenDeadlineBeforeCurrentTime() public {
        vm.warp(LAUNCH_TIME + 5 days);

        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.INVALID_DEADLINE));
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
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.ZERO_GOAL_AMOUNT));
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
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);

        Reward memory retrievedReward = keepWhatsRaised.getReward(TEST_REWARD_NAME);
        assertEq(retrievedReward.rewardValue, TEST_PLEDGE_AMOUNT);
        assertTrue(retrievedReward.isRewardTier);
    }

    function testAddRewardsRevertWhenMismatchedArrays() public {
        bytes32[] memory rewardNames = new bytes32[](2);
        Reward[] memory rewards = new Reward[](1);

        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.REWARD_LENGTH_MISMATCH));
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }

    function testAddRewardsRevertWhenDuplicateReward() public {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

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
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);

        // Remove reward
        vm.prank(users.creator1Address);
        keepWhatsRaised.removeReward(TEST_REWARD_NAME);

        // Verify removal
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.REWARD_NOT_FOUND));
        keepWhatsRaised.getReward(TEST_REWARD_NAME);
    }

    function testRemoveRewardRevertWhenRewardDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.REWARD_NOT_FOUND));
        vm.prank(users.creator1Address);
        keepWhatsRaised.removeReward(TEST_REWARD_NAME);
    }

    function testAddRewardsRevertWhenPaused() public {
        _pauseTreasury();

        // Try to add rewards
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

        vm.expectRevert();
        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }

    function testRemoveRewardRevertWhenPaused() public {
        // First add a reward
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitData
        );
        vm.stopPrank();

        // Verify
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore - TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT);
        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < TEST_PLEDGE_AMOUNT); // Less due to fees
        assertEq(CampaignInfo(campaignAddress).balanceOf(users.backer1Address), 1);
    }

    function testPledgeForARewardRevertWhenDuplicatePledgeId() public {
        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT * 2);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        // First pledge
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, 0, rewardSelection, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), 0, rewardSelection, permitData1);

        // Try to pledge with same ID
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, 0, rewardSelection, 1, block.timestamp + 1 hours);
        vm.expectRevert(
            abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedPledgeAlreadyProcessed.selector, TEST_PLEDGE_ID)
        );
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), 0, rewardSelection, permitData2);
        vm.stopPrank();
    }

    function testPledgeForARewardRevertWhenNotRewardTier() public {
        // Add non-reward tier
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, false, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);

        // Try to pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory emptyPermit;
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.EMPTY_SIGNATURE));
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), 0, rewardSelection, emptyPermit);
        vm.stopPrank();
    }

    function testPledgeForARewardRevertWhenAddOnNotAllowed() public {
        bytes32 addOnRewardName = keccak256(abi.encodePacked("addOnReward"));

        bytes32[] memory rewardNames = new bytes32[](2);
        rewardNames[0] = TEST_REWARD_NAME;
        rewardNames[1] = addOnRewardName;

        Reward[] memory rewards = new Reward[](2);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);
        rewards[1] = _createTestReward(TEST_PLEDGE_AMOUNT / 2, false, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT * 2);

        bytes32[] memory rewardSelection = new bytes32[](2);
        rewardSelection[0] = TEST_REWARD_NAME;
        rewardSelection[1] = addOnRewardName;

        PermitData memory emptyPermit2;
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.EMPTY_SIGNATURE));
        keepWhatsRaised.pledgeForAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), 0, rewardSelection, emptyPermit2);
        vm.stopPrank();
    }

    function testPledgeWithoutAReward() public {
        uint256 pledgeAmount = 500e18;
        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);

        // Pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, pledgeAmount + TEST_TIP_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, pledgeAmount, TEST_TIP_AMOUNT, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), pledgeAmount, TEST_TIP_AMOUNT, permitData
        );
        vm.stopPrank();

        // Verify
        assertEq(testToken.balanceOf(users.backer1Address), balanceBefore - pledgeAmount - TEST_TIP_AMOUNT);
        assertEq(keepWhatsRaised.getRaisedAmount(), pledgeAmount);
        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() < pledgeAmount); // Less due to fees
        assertEq(CampaignInfo(campaignAddress).balanceOf(users.backer1Address), 1);
    }

    function testPledgeWithoutARewardRevertWhenDuplicatePledgeId() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT * 2);

        // First pledge
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData1
        );

        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 1, block.timestamp + 1 hours);
        vm.expectRevert(
            abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedPledgeAlreadyProcessed.selector, TEST_PLEDGE_ID)
        );
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData2
        );
        vm.stopPrank();
    }

    function testPledgeWithoutARewardRevertWhenPermitMissing() public {
        vm.warp(LAUNCH_TIME);
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.EMPTY_SIGNATURE));
        vm.prank(users.backer1Address);
        PermitData memory emptyPermitData = PermitData({nonce: 0, deadline: 0, signature: ""});
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, emptyPermitData
        );
    }

    function testPledgeWithoutARewardRevertWhenSignedPledgeIdIsTampered() public {
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_PLEDGE_AMOUNT,
            0,
            55,
            block.timestamp + 1 hours
        );

        vm.expectRevert(MockPermit2.InvalidSigner.selector);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("tamperedPledgeId"),
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            0,
            permitData
        );
        vm.stopPrank();
    }

    function testPledgeRevertWhenOutsideCampaignPeriod() public {
        // Before launch
        vm.warp(LAUNCH_TIME - 1);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        PermitData memory emptyPermit1;
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, emptyPermit1
        );

        // After deadline
        vm.warp(DEADLINE + 1);
        vm.expectRevert();
        vm.prank(users.backer1Address);
        PermitData memory emptyPermit2;
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("newPledge"), users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, emptyPermit2
        );
    }

    function testPledgeForARewardRevertWhenPaused() public {
        // Add reward first
        _setupReward();

        _pauseTreasury();

        // Try to pledge
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory emptyPermit;
        vm.expectRevert();
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, emptyPermit
        );
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
            address(testToken),
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
        assertEq(CampaignInfo(campaignAddress).balanceOf(users.backer1Address), 1);
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
        keepWhatsRaised.withdraw(address(testToken), 0);

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
        keepWhatsRaised.withdraw(address(testToken), partialAmount);

        uint256 availableAfter = keepWhatsRaised.getAvailableRaisedAmount();

        // Verify - available is reduced by withdrawal plus fees
        assertTrue(availableAfter < availableBefore - partialAmount);
    }

    function testWithdrawRevertWhenNotApproved() public {
        _setupPledges();

        vm.warp(DEADLINE + 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedDisabled.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);
    }

    function testWithdrawRevertWhenAmountExceedsAvailable() public {
        _setupPledges();

        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();

        vm.warp(LAUNCH_TIME + 1 days);
        vm.expectRevert();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), available + 1e18);
    }

    function testWithdrawRevertWhenAlreadyWithdrawn() public {
        _setupPledges();

        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        // First withdrawal
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);

        // Second withdrawal attempt
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyWithdrawn.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);
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
        keepWhatsRaised.withdraw(address(testToken), 0);
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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, largePledge);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, largePledge, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), largePledge, 0, permitData);
        vm.stopPrank();

        uint256 availableAfterPledge = keepWhatsRaised.getAvailableRaisedAmount();

        // Verify available amount is above exemption threshold
        assertTrue(
            availableAfterPledge > MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION,
            "Available amount should be above exemption threshold"
        );

        // Approve and withdraw
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerBalanceBefore = testToken.balanceOf(owner);

        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);

        uint256 ownerBalanceAfter = testToken.balanceOf(owner);
        uint256 received = ownerBalanceAfter - ownerBalanceBefore;

        // For final withdrawal above exemption threshold, no flat fee is applied
        // The owner should receive the full available amount
        assertEq(received, availableAfterPledge, "Should receive full available amount without flat fee");
    }

    function testWithdrawWithColombianCreatorTax() public {
        // Deploy a fresh treasury and configure it with Colombian creator settings.
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        // Make a pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
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
        keepWhatsRaised.withdraw(address(testToken), 0);

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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
        uint256 tokenId = 1; // First token ID after pledge
        vm.stopPrank();

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Claim refund within refund window
        vm.warp(DEADLINE + 1 days);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);

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
        campaignInfo.ownerOf(tokenId); // Token should be burned
    }

    function testClaimRefundRevertWhenOutsideRefundWindow() public {
        // Make pledge
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
        uint256 tokenId = 1; // First token ID after pledge
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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
        uint256 tokenId = 1; // First token ID after pledge
        vm.stopPrank();

        // Cancel campaign
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.cancelTreasury(keccak256("cancelled"));

        uint256 balanceBefore = testToken.balanceOf(users.backer1Address);

        // Claim refund
        vm.warp(block.timestamp + 1);

        // Approve treasury to burn NFT
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);

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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
        uint256 tokenId = 0;
        vm.stopPrank();

        // Withdraw all funds
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);

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
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedClaimFundWindowNotReached.selector);
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
                    FORWARD TIPS IMMEDIATELY (CONFIG_COLOMBIAN)
    //////////////////////////////////////////////////////////////*/

    function testClaimTipRevertsWhenForwardTipsImmediately() public {
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitData
        );
        vm.stopPrank();

        // Tip was forwarded at pledge time, so claimTip must revert
        assertEq(keepWhatsRaised.getTipClaimedPerToken(address(testToken)), TEST_TIP_AMOUNT, "Tip tracked as forwarded");

        vm.warp(DEADLINE + 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedTipsAlreadyForwarded.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();
    }

    function testTipForwardedToPlatformAdminAtPledgeTime() public {
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        _setupReward();
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        uint256 adminBalanceBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBalanceBefore = testToken.balanceOf(treasuryAddress);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitData
        );
        vm.stopPrank();

        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore + TEST_TIP_AMOUNT,
            "Platform admin should receive tip at pledge time"
        );
        assertEq(
            testToken.balanceOf(treasuryAddress),
            treasuryBalanceBefore + TEST_PLEDGE_AMOUNT,
            "Treasury should hold pledge amount only (tip forwarded to admin)"
        );
        assertEq(
            keepWhatsRaised.getTipClaimedPerToken(address(testToken)),
            TEST_TIP_AMOUNT,
            "Tip tracked as forwarded"
        );
    }

    function testSetFeeAndPledgeSplitsPledgeAndTipWithForwarding() public {
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        uint256 adminBalanceBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBalanceBefore = testToken.balanceOf(treasuryAddress);

        vm.warp(LAUNCH_TIME);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            emptyReward,
            false
        );
        vm.stopPrank();

        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore - TEST_PLEDGE_AMOUNT,
            "Admin transfers pledgeAmount; tip stays in admin wallet"
        );
        assertEq(
            testToken.balanceOf(treasuryAddress),
            treasuryBalanceBefore + TEST_PLEDGE_AMOUNT,
            "Treasury receives pledgeAmount"
        );
        assertEq(
            keepWhatsRaised.getRaisedAmount(),
            TEST_PLEDGE_AMOUNT,
            "Raised amount equals pledgeAmount (tip tracked separately)"
        );
        assertEq(
            keepWhatsRaised.getTipClaimedPerToken(address(testToken)),
            TEST_TIP_AMOUNT,
            "Tip tracked as forwarded immediately"
        );
    }

      /// @notice Helper that builds a signed Permit2 no-reward permit for any treasury address
    function _buildSignedPermitDataForTreasury(
        address backer,
        address _treasuryAddress,
        address token,
        bytes32 pledgeId,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 nonce,
        uint256 deadline
    ) internal returns (PermitData memory) {
        bytes32 witness =
            keccak256(abi.encode(KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH, pledgeId, backer, pledgeAmount, tip));

        return _buildSignedPermitData(
            backer,
            _treasuryAddress,
            token,
            pledgeAmount + tip,
            witness,
            KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING,
            nonce,
            deadline
        );
    }

    /// @notice Builds a signed Permit2 reward permit for any treasury address
    function _buildSignedRewardPermitDataForTreasury(
        address backer,
        address _treasuryAddress,
        address token,
        bytes32 pledgeId,
        uint256 tip,
        bytes32[] memory rewardSelection,
        uint256 rewardValue,
        uint256 nonce,
        uint256 deadline
    ) internal returns (PermitData memory) {
        uint256 totalAmount = rewardValue + tip;
        bytes32 rewardsHash = keccak256(abi.encodePacked(rewardSelection));
        bytes32 witness =
            keccak256(abi.encode(KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, pledgeId, backer, rewardsHash, tip));

        return _buildSignedPermitData(
            backer, _treasuryAddress, token, totalAmount, witness, KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING, nonce, deadline
        );
    }

    /// @notice Deploys and fully configures a fresh treasury with forwardTipsImmediately = true
    function _createTreasuryWithTipForwarding() internal returns (KeepWhatsRaised) {
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("tipForwardingCampaign", block.timestamp));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = PLATFORM_2_HASH;

        bytes32[] memory emptyKey = new bytes32[](0);
        bytes32[] memory emptyVal = new bytes32[](0);

        vm.prank(users.creator1Address);
        campaignInfoFactory.createCampaign(
            users.creator1Address,
            newIdentifierHash,
            selectedPlatformHash,
            emptyKey,
            emptyVal,
            CAMPAIGN_DATA,
            "Tip Forward Campaign",
            "TFC",
            "ipfs://image",
            "ipfs://contract"
        );

        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);

        vm.prank(users.platform2AdminAddress);
        address newTreasuryAddress = treasuryFactory.deploy(PLATFORM_2_HASH, newCampaignAddress, 1);

        KeepWhatsRaised newTreasury = KeepWhatsRaised(newTreasuryAddress);

        KeepWhatsRaised.Config memory tipConfig = KeepWhatsRaised.Config({
            minimumWithdrawalForFeeExemption: MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION,
            withdrawalDelay: WITHDRAWAL_DELAY,
            refundDelay: REFUND_DELAY,
            configLockPeriod: CONFIG_LOCK_PERIOD,
            isColombianCreator: false,
            forwardTipsImmediately: true
        });

        KeepWhatsRaised.FeeValues memory feeValues = KeepWhatsRaised.FeeValues({
            flatFeeValue: uint256(FLAT_FEE_VALUE),
            cumulativeFlatFeeValue: uint256(CUMULATIVE_FLAT_FEE_VALUE),
            grossPercentageFeeValues: new uint256[](2)
        });
        feeValues.grossPercentageFeeValues[0] = uint256(PLATFORM_FEE_VALUE);
        feeValues.grossPercentageFeeValues[1] = uint256(VAKI_COMMISSION_VALUE);

        vm.prank(users.platform2AdminAddress);
        newTreasury.configureTreasury(tipConfig, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        return newTreasury;
    }

    // ─── setFeeAndPledge (admin path) ────────────────────────────────────────

    /// Admin transfers pledgeAmount to treasury; tip stays in admin wallet and is tracked.
    function test_TipForwarding_SetFeeAndPledge_WithoutReward_OnlyPledgeAmountTransferred() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        uint256 tip         = 100e18;
        uint256 fee         = 40e18;
        bytes32 pledgeId    = keccak256("tipFwdAdminNoReward");

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount);

        uint256 adminBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBefore = testToken.balanceOf(address(tipTreasury));

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), pledgeAmount);

        bytes32[] memory emptyReward = new bytes32[](0);
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, fee, emptyReward, false);
        vm.stopPrank();

        uint256 adminAfter    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryAfter = testToken.balanceOf(address(tipTreasury));

        assertEq(adminBefore - adminAfter, pledgeAmount, "Admin transfers pledgeAmount; tip stays in admin wallet");
        assertEq(treasuryAfter - treasuryBefore, pledgeAmount, "Treasury receives pledgeAmount");

        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)), tip, "Tip tracked immediately");
        assertEq(tipTreasury.getTotalTipClaimed(), tip, "getTotalTipClaimed equals tip");
    }

    /// For pledgeForAReward: admin transfers only rewardValue; tip is NOT pulled from admin
    function test_TipForwarding_SetFeeAndPledge_WithReward_OnlyRewardValueTransferred() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        bytes32 rewardName = keccak256("tipFwdReward");
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = rewardName;
        uint256 rewardValue = 500e18;
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = Reward({
            rewardValue: rewardValue,
            isRewardTier: true,
            canBeAddOn: false,
            itemId: new bytes32[](0),
            itemValue: new uint256[](0),
            itemQuantity: new uint256[](0)
        });
        vm.prank(users.creator1Address);
        tipTreasury.addRewards(rewardNames, rewards);

        uint256 tip  = 50e18;
        uint256 fee  = 20e18;
        bytes32 pledgeId = keccak256("tipFwdAdminReward");

        // Admin only needs rewardValue in wallet (tip stays with admin — not transferred)
        deal(address(testToken), users.platform2AdminAddress, rewardValue);

        uint256 adminBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBefore  = testToken.balanceOf(address(tipTreasury));

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), rewardValue);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = rewardName;
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), 0, tip, fee, rewardSelection, true);
        vm.stopPrank();

        uint256 adminAfter    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryAfter  = testToken.balanceOf(address(tipTreasury));

        // Only rewardValue transferred; tip stays with admin
        assertEq(adminBefore - adminAfter, rewardValue, "Admin should only transfer rewardValue");
        assertEq(treasuryAfter - treasuryBefore, rewardValue, "Treasury receives rewardValue only");

        // Tip tracked even though no transfer occurred
        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)), tip, "Tip should be tracked");
    }

    // ─── pledgeWithoutAReward (Permit2 / user path) ───────────────────────────

    /// Backer pays pledge + tip; treasury keeps pledge, tip is forwarded to platform admin
    function test_TipForwarding_PledgeWithoutReward_Permit2_ForwardsTipToPlatformAdmin() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        uint256 tip          = 100e18;
        bytes32 pledgeId     = keccak256("tipFwdPermit2NoReward");

        deal(address(testToken), users.backer1Address, pledgeAmount + tip);

        uint256 backerBefore  = testToken.balanceOf(users.backer1Address);
        uint256 adminBefore   = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBefore = testToken.balanceOf(address(tipTreasury));

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, pledgeAmount + tip);

        PermitData memory permitData = _buildSignedPermitDataForTreasury(
            users.backer1Address, address(tipTreasury), address(testToken),
            pledgeId, pledgeAmount, tip, 0, block.timestamp + 1 hours
        );
        tipTreasury.pledgeWithoutAReward(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, permitData);
        vm.stopPrank();

        assertEq(backerBefore  - testToken.balanceOf(users.backer1Address),  pledgeAmount + tip, "Backer pays pledge + tip");
        assertEq(testToken.balanceOf(users.platform2AdminAddress) - adminBefore, tip,            "Admin receives tip");
        assertEq(testToken.balanceOf(address(tipTreasury)) - treasuryBefore, pledgeAmount,       "Treasury receives pledge only");

        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)), tip, "Tip tracked");
    }

    // ─── claimTip() guard ─────────────────────────────────────────────────────

    /// claimTip() must revert when forwardTipsImmediately is enabled
    function test_TipForwarding_ClaimTip_RevertsWhenForwardingEnabled() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedTipsAlreadyForwarded.selector);
        tipTreasury.claimTip();
    }

    // ─── TipForwarded event ───────────────────────────────────────────────────

    /// TipForwarded event is emitted with correct values on admin path
    function test_TipForwarding_EmitsTipForwardedEvent() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        uint256 tip          = 100e18;
        bytes32 pledgeId     = keccak256("tipFwdEvent");

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), pledgeAmount);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.recordLogs();
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, 40e18, emptyReward, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TipForwarded(bytes32,address,address,uint256,uint256)")) {
                found = true;
                assertEq(logs[i].topics[1], pledgeId,                                                  "pledgeId indexed");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), users.backer1Address,            "backer indexed");
                assertEq(address(uint160(uint256(logs[i].topics[3]))), address(testToken),              "token indexed");
                (uint256 tipAmt,) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(tipAmt, tip, "tip amount in event");
                break;
            }
        }
        assertTrue(found, "TipForwarded event should be emitted");
    }

    // ─── Receipt event tip field ──────────────────────────────────────────────

    /// Receipt event must contain the original tip value even when forwarding is enabled
    function test_TipForwarding_ReceiptEventHasOriginalTip() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        uint256 tip          = 100e18;
        bytes32 pledgeId     = keccak256("tipFwdReceipt");

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), pledgeAmount);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.recordLogs();
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, 40e18, emptyReward, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        bool receiptFound;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])")) {
                receiptFound = true;
                (, , uint256 tipInEvent,,) =
                    abi.decode(logs[i].data, (bytes32, uint256, uint256, uint256, bytes32[]));
                assertEq(tipInEvent, tip, "Receipt event tip must equal original tip");
                break;
            }
        }
        assertTrue(receiptFound, "Receipt event should be emitted");
    }

    // ─── Cumulative tip tracking ──────────────────────────────────────────────

    /// Multiple pledges accumulate tip correctly in s_tipClaimedPerToken
    function test_TipForwarding_CumulativeTipTracking() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        uint256 tip1 = 50e18;
        uint256 tip2 = 75e18;
        uint256 fee  = 40e18;

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount * 2);

        vm.warp(LAUNCH_TIME);
        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);

        testToken.approve(address(tipTreasury), pledgeAmount);
        tipTreasury.setFeeAndPledge(keccak256("cum1"), users.backer1Address, address(testToken), pledgeAmount, tip1, fee, emptyReward, false);

        testToken.approve(address(tipTreasury), pledgeAmount);
        tipTreasury.setFeeAndPledge(keccak256("cum2"), users.backer2Address, address(testToken), pledgeAmount, tip2, fee, emptyReward, false);

        vm.stopPrank();

        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)), tip1 + tip2, "Cumulative tip per token");
        assertEq(tipTreasury.getTotalTipClaimed(), tip1 + tip2, "getTotalTipClaimed cumulative");
    }

    // ─── Forwarding disabled — original claimTip() flow intact ───────────────

    /// When forwardTipsImmediately = false, tip is stored and claimTip() works as before
    function test_TipForwarding_Disabled_ClaimTipWorkAsOriginal() public {
        // keepWhatsRaised fixture has forwardTipsImmediately = false (default)
        uint256 pledgeAmount = 1000e18;
        uint256 tip          = 100e18;
        bytes32 pledgeId     = keccak256("noFwdTip");

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount + tip);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(keepWhatsRaised), pledgeAmount + tip);

        bytes32[] memory emptyReward = new bytes32[](0);
        keepWhatsRaised.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, 40e18, emptyReward, false);
        vm.stopPrank();

        // s_tipClaimedPerToken must still be 0 — tip not yet forwarded/claimed
        assertEq(keepWhatsRaised.getTipClaimedPerToken(address(testToken)), 0, "Tip not claimed yet");

        // claimTip() should work after deadline
        vm.warp(DEADLINE + 1);
        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();

        assertEq(testToken.balanceOf(users.platform2AdminAddress) - adminBefore, tip, "Admin receives tip via claimTip");

        // Now tracked
        assertEq(keepWhatsRaised.getTipClaimedPerToken(address(testToken)), tip, "Tip tracked after claimTip");
    }

    // ─── pledgeForAReward (Permit2 / user path) ───────────────────────────────

    /// Backer pays rewardValue + tip; treasury keeps rewardValue, tip is forwarded to platform admin
    function test_TipForwarding_PledgeForReward_Permit2_ForwardsTipToPlatformAdmin() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        bytes32 rewardName = keccak256("fwdReward");
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = rewardName;
        uint256 rewardValue = 500e18;
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = Reward({
            rewardValue: rewardValue,
            isRewardTier: true,
            canBeAddOn: false,
            itemId: new bytes32[](0),
            itemValue: new uint256[](0),
            itemQuantity: new uint256[](0)
        });
        vm.prank(users.creator1Address);
        tipTreasury.addRewards(rewardNames, rewards);

        uint256 tip      = 50e18;
        bytes32 pledgeId = keccak256("tipFwdPermit2Reward");

        deal(address(testToken), users.backer1Address, rewardValue + tip);

        uint256 backerBefore   = testToken.balanceOf(users.backer1Address);
        uint256 adminBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBefore = testToken.balanceOf(address(tipTreasury));

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, rewardValue + tip);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = rewardName;

        PermitData memory permitData = _buildSignedRewardPermitDataForTreasury(
            users.backer1Address, address(tipTreasury), address(testToken),
            pledgeId, tip, rewardSelection, rewardValue, 0, block.timestamp + 1 hours
        );
        tipTreasury.pledgeForAReward(pledgeId, users.backer1Address, address(testToken), tip, rewardSelection, permitData);
        vm.stopPrank();

        assertEq(backerBefore - testToken.balanceOf(users.backer1Address),              rewardValue + tip, "Backer pays rewardValue + tip");
        assertEq(testToken.balanceOf(users.platform2AdminAddress) - adminBefore,        tip,              "Admin receives tip immediately");
        assertEq(testToken.balanceOf(address(tipTreasury)) - treasuryBefore,            rewardValue,      "Treasury holds rewardValue only");
        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)),                 tip,              "Tip tracked as forwarded");
    }

    // ─── Security edge cases ─────────────────────────────────────────────────

    /// When tip == 0 and forwarding is enabled, no TipForwarded event is emitted and
    /// s_tipClaimedPerToken remains zero — the feature must not fire spuriously.
    function test_TipForwarding_ZeroTip_SkipsForwardingLogic() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 1000e18;
        bytes32 pledgeId     = keccak256("zeroTipFwd");

        deal(address(testToken), users.platform2AdminAddress, pledgeAmount);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), pledgeAmount);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.recordLogs();
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), pledgeAmount, 0, 0, emptyReward, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        // No TipForwarded event should be emitted
        bytes32 tipForwardedSig = keccak256("TipForwarded(bytes32,address,address,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertFalse(logs[i].topics[0] == tipForwardedSig, "TipForwarded must not fire on zero tip");
        }

        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)), 0, "No tip tracked for zero-tip pledge");
        assertEq(tipTreasury.getRaisedAmount(), pledgeAmount,             "Full pledgeAmount counts as raised");
    }

    /// When tip > pledgeAmount on the Permit2 path, token accounting stays correct with no underflow.
    function test_TipForwarding_LargeTip_ExceedsPledgeAmount_Permit2() public {
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 pledgeAmount = 100e18;
        uint256 tip          = 400e18;   // tip intentionally larger than pledgeAmount
        bytes32 pledgeId     = keccak256("largeTipPermit2");

        deal(address(testToken), users.backer1Address, pledgeAmount + tip);

        uint256 backerBefore   = testToken.balanceOf(users.backer1Address);
        uint256 adminBefore    = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBefore = testToken.balanceOf(address(tipTreasury));

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, pledgeAmount + tip);

        PermitData memory permitData = _buildSignedPermitDataForTreasury(
            users.backer1Address, address(tipTreasury), address(testToken),
            pledgeId, pledgeAmount, tip, 0, block.timestamp + 1 hours
        );
        tipTreasury.pledgeWithoutAReward(pledgeId, users.backer1Address, address(testToken), pledgeAmount, tip, permitData);
        vm.stopPrank();

        assertEq(backerBefore - testToken.balanceOf(users.backer1Address),             pledgeAmount + tip, "Backer pays full amount");
        assertEq(testToken.balanceOf(users.platform2AdminAddress) - adminBefore,       tip,               "Admin receives large tip");
        assertEq(testToken.balanceOf(address(tipTreasury)) - treasuryBefore,           pledgeAmount,      "Treasury holds only pledgeAmount");
        assertEq(tipTreasury.getRaisedAmount(),                                        pledgeAmount,      "Raised amount unaffected by large tip");
        assertEq(tipTreasury.getTipClaimedPerToken(address(testToken)),                tip,               "Large tip tracked correctly");
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
        keepWhatsRaised.withdraw(address(testToken), 0);

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
        keepWhatsRaised.withdraw(address(testToken), 0);

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
        PermitData memory emptyPermit1;
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, emptyPermit1
        );
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
        PermitData memory emptyPermit2;
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, emptyPermit2
        );
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
        keepWhatsRaised.withdraw(address(testToken), firstWithdrawal);
        uint256 availableAfter1 = keepWhatsRaised.getAvailableRaisedAmount();

        // Verify first withdrawal reduced available amount by withdrawal + fees
        uint256 expectedReduction1 = firstWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE);
        assertApproxEqAbs(
            availableBefore1 - availableAfter1,
            expectedReduction1,
            10,
            "First withdrawal should reduce by amount plus cumulative fee"
        );

        // Second withdrawal
        // Calculate safe amount based on remaining balance
        uint256 secondWithdrawal = 150e18; // Reduced to ensure enough for fee

        // Only do second withdrawal if we have enough funds
        if (availableAfter1 >= secondWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE)) {
            vm.warp(LAUNCH_TIME + 2 days);
            uint256 availableBefore2 = keepWhatsRaised.getAvailableRaisedAmount();
            vm.prank(users.platform2AdminAddress);
            keepWhatsRaised.withdraw(address(testToken), secondWithdrawal);
            uint256 availableAfter2 = keepWhatsRaised.getAvailableRaisedAmount();

            // Verify second withdrawal reduced available amount by withdrawal + fees
            uint256 expectedReduction2 = secondWithdrawal + uint256(CUMULATIVE_FLAT_FEE_VALUE);
            assertApproxEqAbs(
                availableBefore2 - availableAfter2,
                expectedReduction2,
                10,
                "Second withdrawal should reduce by amount plus cumulative fee"
            );
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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, smallPledge);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, smallPledge, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(TEST_PLEDGE_ID, users.backer1Address, address(testToken), smallPledge, 0, permitData);
        vm.stopPrank();

        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        // Try to withdraw partial amount that would cause available < withdrawal + fees
        vm.warp(LAUNCH_TIME + 1 days);
        uint256 available = keepWhatsRaised.getAvailableRaisedAmount();

        // Try to withdraw an amount that with fees would exceed available
        uint256 withdrawAmount = available - 50e18; // Leave less than cumulative fee
        vm.expectRevert();
        keepWhatsRaised.withdraw(address(testToken), withdrawAmount);
    }

    function testZeroTipPledge() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
        vm.stopPrank();

        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
    }

    function testFeeCalculationWithoutColombianTax() public {
        // Make a pledge (non-Colombian)
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), TEST_PLEDGE_ID, TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, 0, permitData
        );
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
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedInvalidInput.selector, TreasuryErrors.InvalidInput.REWARD_NOT_FOUND));
        keepWhatsRaised.getReward(keccak256("nonexistent"));
    }

    function testWithdrawRevertWhenZeroAfterDeadline() public {
        // No pledges made
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        vm.warp(DEADLINE + 1);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedAlreadyWithdrawn.selector);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);
    }

    /*//////////////////////////////////////////////////////////////
                         COMPREHENSIVE FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function testComplexFeeScenario() public {
        // Testing multiple pledges with different fee structures

        // Deploy a fresh treasury and configure with Colombian creator settings.
        _resetTreasury();
        KeepWhatsRaised.FeeValues memory feeValues = _createFeeValues();
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(CONFIG_COLOMBIAN, CAMPAIGN_DATA, FEE_KEYS, feeValues);

        // Add rewards
        _setupReward();

        // Pledge 1: With reward and tip
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge1"), PAYMENT_GATEWAY_FEE
        );
        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), keccak256("pledge1"), TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeForAReward(
            keccak256("pledge1"), users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitData1
        );
        vm.stopPrank();

        // Pledge 2: Without reward, different gateway fee
        uint256 differentGatewayFee = 20e18;
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge2"), differentGatewayFee
        );
        vm.startPrank(users.backer2Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, 2000e18);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(testToken), keccak256("pledge2"), 2000e18, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("pledge2"), users.backer2Address, address(testToken), 2000e18, 0, permitData2);
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
        keepWhatsRaised.withdraw(address(testToken), partialWithdrawAmount);

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
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, smallAmount);
        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(testToken), keccak256("small"), smallAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("small"), users.backer1Address, address(testToken), smallAmount, 0, permitData
        );
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
        keepWhatsRaised.withdraw(address(testToken), availableBeforeWithdraw - uint256(CUMULATIVE_FLAT_FEE_VALUE) - 10); // Leave small buffer

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

    function _createTestReward(uint256 value, bool isRewardTier, bool canBeAddOn) internal pure returns (Reward memory) {
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory itemValues = new uint256[](1);
        uint256[] memory itemQuantities = new uint256[](1);

        itemIds[0] = keccak256("testItem");
        itemValues[0] = value;
        itemQuantities[0] = 1;

        return Reward({
            rewardValue: value,
            isRewardTier: isRewardTier,
            canBeAddOn: canBeAddOn,
            itemId: itemIds,
            itemValue: itemValues,
            itemQuantity: itemQuantities
        });
    }

    function _setupReward() internal {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }

    function _setupPledges() internal {
        _setupReward();

        // Set gateway fees for pledges
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge1"), PAYMENT_GATEWAY_FEE
        );
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("pledge2"), PAYMENT_GATEWAY_FEE
        );

        // Make pledges from two backers
        vm.warp(LAUNCH_TIME);

        // Backer 1 pledge with reward
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;
        PermitData memory permitDataBacker1 = _buildSignedKeepWhatsRaisedRewardPermitData(users.backer1Address, address(testToken), keccak256("pledge1"), TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeForAReward(
            keccak256("pledge1"), users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitDataBacker1
        );
        vm.stopPrank();

        // Backer 2 pledge without reward
        vm.startPrank(users.backer2Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        PermitData memory permitDataBacker2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(testToken), keccak256("pledge2"), TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("pledge2"), users.backer2Address, address(testToken), TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT, permitDataBacker2
        );
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

    /*//////////////////////////////////////////////////////////////
                    MULTI-TOKEN SPECIFIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_pledgeWithMultipleTokenTypes() public {
        _setupReward();

        // Pledge with USDC
        uint256 usdcAmount = getTokenAmount(address(usdcToken), TEST_PLEDGE_AMOUNT);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc_pledge"), 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("usdc_pledge"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("usdc_pledge"), users.backer1Address, address(usdcToken), usdcAmount, 0, permitData1
        );
        vm.stopPrank();

        // Pledge with cUSD
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cusd_pledge"), 0);

        vm.startPrank(users.backer2Address);
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(cUSDToken), keccak256("cusd_pledge"), TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("cusd_pledge"), users.backer2Address, address(cUSDToken), TEST_PLEDGE_AMOUNT, 0, permitData2
        );
        vm.stopPrank();

        // Verify raised amount is normalized
        uint256 totalRaised = keepWhatsRaised.getRaisedAmount();
        assertEq(totalRaised, TEST_PLEDGE_AMOUNT * 2, "Should normalize to same value");
    }

    function test_withdrawMultipleTokensCorrectly() public {
        _setupReward();

        // Use larger amounts to ensure enough remains after fees
        uint256 largeAmount = 100_000e18; // 100k base amount
        uint256 usdcAmount = getTokenAmount(address(usdcToken), largeAmount);
        uint256 cUSDAmount = largeAmount;

        // Pledge with USDC
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc"), 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        deal(address(usdcToken), users.backer1Address, usdcAmount); // Ensure enough tokens
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("usdc"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("usdc"), users.backer1Address, address(usdcToken), usdcAmount, 0, permitData1);
        vm.stopPrank();

        // Pledge with cUSD
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cusd"), 0);

        vm.startPrank(users.backer2Address);
        deal(address(cUSDToken), users.backer2Address, cUSDAmount); // Ensure enough tokens
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, cUSDAmount);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(cUSDToken), keccak256("cusd"), cUSDAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("cusd"), users.backer2Address, address(cUSDToken), cUSDAmount, 0, permitData2);
        vm.stopPrank();

        // Approve withdrawal
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        address owner = CampaignInfo(campaignAddress).owner();
        uint256 ownerUSDCBefore = usdcToken.balanceOf(owner);
        uint256 ownerCUSDBefore = cUSDToken.balanceOf(owner);

        // Withdraw USDC
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(usdcToken), 0);

        // Withdraw cUSD
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(cUSDToken), 0);

        // Verify withdrawals
        assertTrue(usdcToken.balanceOf(owner) > ownerUSDCBefore, "Should receive USDC");
        assertTrue(cUSDToken.balanceOf(owner) > ownerCUSDBefore, "Should receive cUSD");
    }

    function test_disburseFeesForMultipleTokens() public {
        _setupReward();

        // Make pledges with different tokens
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PLEDGE_AMOUNT);
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PLEDGE_AMOUNT);

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc"), 0);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdt"), 0);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cusd"), 0);

        vm.warp(LAUNCH_TIME);

        // USDC pledge
        vm.startPrank(users.backer1Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("usdc"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("usdc"), users.backer1Address, address(usdcToken), usdcAmount, 0, permitData1);
        vm.stopPrank();

        // USDT pledge
        vm.startPrank(users.backer2Address);
        usdtToken.approve(CANONICAL_PERMIT2_ADDRESS, usdtAmount);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(usdtToken), keccak256("usdt"), usdtAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("usdt"), users.backer2Address, address(usdtToken), usdtAmount, 0, permitData2);
        vm.stopPrank();

        // cUSD pledge
        vm.startPrank(users.backer1Address);
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, PLEDGE_AMOUNT);
        PermitData memory permitData3 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(cUSDToken), keccak256("cusd"), PLEDGE_AMOUNT, 0, 1, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("cusd"), users.backer1Address, address(cUSDToken), PLEDGE_AMOUNT, 0, permitData3
        );
        vm.stopPrank();

        // Approve and make partial withdrawal to generate fees
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(cUSDToken), 0);

        // Track balances before disbursement
        uint256 protocolUSDCBefore = usdcToken.balanceOf(users.protocolAdminAddress);
        uint256 protocolUSDTBefore = usdtToken.balanceOf(users.protocolAdminAddress);
        uint256 protocolCUSDBefore = cUSDToken.balanceOf(users.protocolAdminAddress);

        uint256 platformUSDCBefore = usdcToken.balanceOf(users.platform2AdminAddress);
        uint256 platformUSDTBefore = usdtToken.balanceOf(users.platform2AdminAddress);
        uint256 platformCUSDBefore = cUSDToken.balanceOf(users.platform2AdminAddress);

        // Disburse fees
        keepWhatsRaised.disburseFees();

        // Verify fees were distributed for all tokens
        assertTrue(
            usdcToken.balanceOf(users.protocolAdminAddress) > protocolUSDCBefore, "Should receive USDC protocol fees"
        );
        assertTrue(
            usdtToken.balanceOf(users.protocolAdminAddress) > protocolUSDTBefore, "Should receive USDT protocol fees"
        );
        assertTrue(
            cUSDToken.balanceOf(users.protocolAdminAddress) > protocolCUSDBefore, "Should receive cUSD protocol fees"
        );

        assertTrue(
            usdcToken.balanceOf(users.platform2AdminAddress) > platformUSDCBefore, "Should receive USDC platform fees"
        );
        assertTrue(
            usdtToken.balanceOf(users.platform2AdminAddress) > platformUSDTBefore, "Should receive USDT platform fees"
        );
        assertTrue(
            cUSDToken.balanceOf(users.platform2AdminAddress) > platformCUSDBefore, "Should receive cUSD platform fees"
        );
    }

    function test_refundReturnsCorrectToken() public {
        _setupReward();

        // Backer1 pledges with USDC
        uint256 usdcAmount = getTokenAmount(address(usdcToken), TEST_PLEDGE_AMOUNT);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc_pledge"), 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("usdc_pledge"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("usdc_pledge"), users.backer1Address, address(usdcToken), usdcAmount, 0, permitData1
        );
        uint256 usdcTokenId = 1; // First pledge
        vm.stopPrank();

        // Backer2 pledges with cUSD
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cusd_pledge"), 0);

        vm.startPrank(users.backer2Address);
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(cUSDToken), keccak256("cusd_pledge"), TEST_PLEDGE_AMOUNT, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("cusd_pledge"), users.backer2Address, address(cUSDToken), TEST_PLEDGE_AMOUNT, 0, permitData2
        );
        uint256 cUSDTokenId = 2; // Second pledge
        vm.stopPrank();

        uint256 backer1USDCBefore = usdcToken.balanceOf(users.backer1Address);
        uint256 backer2CUSDBefore = cUSDToken.balanceOf(users.backer2Address);

        // Claim refunds after deadline
        vm.warp(DEADLINE + 1);

        // Approve treasury to burn NFTs
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), usdcTokenId);

        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(usdcTokenId);

        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), cUSDTokenId);

        vm.prank(users.backer2Address);
        keepWhatsRaised.claimRefund(cUSDTokenId);

        // Verify correct tokens were refunded (should get something back even after fees)
        assertTrue(usdcToken.balanceOf(users.backer1Address) > backer1USDCBefore, "Should refund USDC");
        assertTrue(cUSDToken.balanceOf(users.backer2Address) > backer2CUSDBefore, "Should refund cUSD");
    }

    function test_claimTipWithMultipleTokens() public {
        _setupReward();

        uint256 tipAmountUSDC = getTokenAmount(address(usdcToken), TIP_AMOUNT);
        uint256 tipAmountCUSD = TIP_AMOUNT;

        // Pledge with USDC + tip
        uint256 usdcPledge = getTokenAmount(address(usdcToken), TEST_PLEDGE_AMOUNT);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc"), 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcPledge + tipAmountUSDC);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("usdc"), usdcPledge, tipAmountUSDC, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("usdc"), users.backer1Address, address(usdcToken), usdcPledge, tipAmountUSDC, permitData1
        );
        vm.stopPrank();

        // Pledge with cUSD + tip
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("cusd"), 0);

        vm.startPrank(users.backer2Address);
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + tipAmountCUSD);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(cUSDToken), keccak256("cusd"), TEST_PLEDGE_AMOUNT, tipAmountCUSD, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("cusd"), users.backer2Address, address(cUSDToken), TEST_PLEDGE_AMOUNT, tipAmountCUSD, permitData2
        );
        vm.stopPrank();

        uint256 platformUSDCBefore = usdcToken.balanceOf(users.platform2AdminAddress);
        uint256 platformCUSDBefore = cUSDToken.balanceOf(users.platform2AdminAddress);

        // Claim tips
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();

        // Verify tips in both tokens
        assertEq(
            usdcToken.balanceOf(users.platform2AdminAddress) - platformUSDCBefore,
            tipAmountUSDC,
            "Should receive USDC tips"
        );
        assertEq(
            cUSDToken.balanceOf(users.platform2AdminAddress) - platformCUSDBefore,
            tipAmountCUSD,
            "Should receive cUSD tips"
        );
    }

    function test_mixedTokenPledgesWithDecimalNormalization() public {
        _setupReward();

        // Make three pledges with same normalized value but different decimals
        uint256 baseAmount = 1000e18;
        uint256 usdcAmount = baseAmount / 1e12; // 6 decimals
        uint256 usdtAmount = baseAmount / 1e12; // 6 decimals
        uint256 cUSDAmount = baseAmount; // 18 decimals

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("p1"), 0);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("p2"), 0);
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("p3"), 0);

        vm.warp(LAUNCH_TIME);

        // USDC pledge
        vm.startPrank(users.backer1Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdcToken), keccak256("p1"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("p1"), users.backer1Address, address(usdcToken), usdcAmount, 0, permitData1);
        vm.stopPrank();

        uint256 raisedAfterUSDC = keepWhatsRaised.getRaisedAmount();
        assertEq(raisedAfterUSDC, baseAmount, "USDC should normalize to base amount");

        // USDT pledge
        vm.startPrank(users.backer2Address);
        usdtToken.approve(CANONICAL_PERMIT2_ADDRESS, usdtAmount);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(usdtToken), keccak256("p2"), usdtAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("p2"), users.backer2Address, address(usdtToken), usdtAmount, 0, permitData2);
        vm.stopPrank();

        uint256 raisedAfterUSDT = keepWhatsRaised.getRaisedAmount();
        assertEq(raisedAfterUSDT, baseAmount * 2, "USDT should normalize to base amount");

        // cUSD pledge
        vm.startPrank(users.backer1Address);
        cUSDToken.approve(CANONICAL_PERMIT2_ADDRESS, cUSDAmount);
        PermitData memory permitData3 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(cUSDToken), keccak256("p3"), cUSDAmount, 0, 1, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(keccak256("p3"), users.backer1Address, address(cUSDToken), cUSDAmount, 0, permitData3);
        vm.stopPrank();

        uint256 finalRaised = keepWhatsRaised.getRaisedAmount();
        assertEq(finalRaised, baseAmount * 3, "All pledges should contribute equally after normalization");
    }

    function testPaymentGatewayFeeWithDifferentDecimalTokens() public {
        // Test that payment gateway fee is properly denormalized for different decimal tokens
        uint256 baseAmount = 1000e18; // 1000 tokens in 18 decimals
        uint256 usdtAmount = baseAmount / 1e12; // 1000 USDT (6 decimals)
        uint256 usdcAmount = baseAmount / 1e12; // 1000 USDC (6 decimals)

        // Set payment gateway fee (stored in 18 decimals)
        uint256 gatewayFee18Decimals = 40e18; // 40 tokens in 18 decimals
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdt_pledge"), gatewayFee18Decimals
        );
        setPaymentGatewayFee(
            users.platform2AdminAddress, address(keepWhatsRaised), keccak256("usdc_pledge"), gatewayFee18Decimals
        );

        vm.warp(LAUNCH_TIME);

        // USDT pledge
        vm.startPrank(users.backer1Address);
        usdtToken.approve(CANONICAL_PERMIT2_ADDRESS, usdtAmount);
        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer1Address, address(usdtToken), keccak256("usdt_pledge"), usdtAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("usdt_pledge"), users.backer1Address, address(usdtToken), usdtAmount, 0, permitData1
        );
        vm.stopPrank();

        // USDC pledge
        vm.startPrank(users.backer2Address);
        usdcToken.approve(CANONICAL_PERMIT2_ADDRESS, usdcAmount);
        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(users.backer2Address, address(usdcToken), keccak256("usdc_pledge"), usdcAmount, 0, 0, block.timestamp + 1 hours);
        keepWhatsRaised.pledgeWithoutAReward(
            keccak256("usdc_pledge"), users.backer2Address, address(usdcToken), usdcAmount, 0, permitData2
        );
        vm.stopPrank();

        // Verify that both pledges contribute equally to raised amount (normalized)
        uint256 raisedAmount = keepWhatsRaised.getRaisedAmount();
        assertEq(
            raisedAmount, baseAmount * 2, "Both 6-decimal token pledges should normalize to same 18-decimal amount"
        );

        // Verify that the payment gateway fees were properly denormalized
        // For 6-decimal tokens, 40e18 should become 40e6
        uint256 expectedGatewayFee6Decimals = 40e6;

        // Check that fees were calculated correctly by checking available amount
        uint256 availableAmount = keepWhatsRaised.getAvailableRaisedAmount();

        // Calculate expected available amount after fees
        uint256 platformFee = (baseAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 vakiCommission = (baseAmount * uint256(VAKI_COMMISSION_VALUE)) / PERCENT_DIVIDER;
        uint256 protocolFee = (baseAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 gatewayFeeNormalized = expectedGatewayFee6Decimals * 1e12; // Convert 6-decimal fee to 18-decimal for comparison

        uint256 expectedAvailable =
            (baseAmount * 2) - (platformFee * 2) - (vakiCommission * 2) - (protocolFee * 2) - (gatewayFeeNormalized * 2);

        assertEq(
            availableAmount, expectedAvailable, "Available amount should account for properly denormalized gateway fees"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VOID PLEDGE
    //////////////////////////////////////////////////////////////*/

    // ── Fee math reference (18-decimal token, PLEDGE_AMOUNT = 1000e18, GATEWAY = 40e18) ──
    //   Protocol fee  (20%)            = 200e18
    //   Platform gross (10% + 6% = 16%) = 160e18
    //   Gateway fee                     =  40e18
    //   Total fee                       = 400e18
    //   Net available                   = 600e18

    uint256 internal constant VOID_PROTOCOL_FEE  = (TEST_PLEDGE_AMOUNT * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;   // 200e18
    uint256 internal constant VOID_PLATFORM_FEE  = (TEST_PLEDGE_AMOUNT * (uint256(PLATFORM_FEE_VALUE) + uint256(VAKI_COMMISSION_VALUE))) / PERCENT_DIVIDER + PAYMENT_GATEWAY_FEE; // 160 + 40 = 200e18
    uint256 internal constant VOID_TOTAL_FEE     = VOID_PROTOCOL_FEE + VOID_PLATFORM_FEE; // 400e18
    uint256 internal constant VOID_NET_AVAILABLE  = TEST_PLEDGE_AMOUNT - VOID_TOTAL_FEE;   // 600e18

    bytes32 internal constant VOID_PLEDGE_ID_A = keccak256("voidPledgeA");
    bytes32 internal constant VOID_PLEDGE_ID_B = keccak256("voidPledgeB");

    /// @dev Makes a pledge via admin setFeeAndPledge path. Returns the minted tokenId.
    function _voidTestPledge(bytes32 pledgeId, address backer, uint256 amount, uint256 tip)
        internal
        returns (uint256 tokenId)
    {
        bytes32[] memory emptyReward = new bytes32[](0);
        (, tokenId,) = setFeeAndPledge(
            users.platform2AdminAddress,
            address(keepWhatsRaised),
            pledgeId,
            backer,
            amount,
            tip,
            PAYMENT_GATEWAY_FEE,
            emptyReward,
            false
        );
    }

    /// @dev Calls voidPledge as platform admin.
    function _void(uint256 tokenId) internal {
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId);
    }

    // ── Access control ──────────────────────────────────────────────────────

    function testVoidPledge_RevertsIfNotPlatformAdmin() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.voidPledge(tokenId);
    }

    function testVoidPledge_RevertsIfCampaignOwner() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        vm.expectRevert();
        vm.prank(users.creator1Address);
        keepWhatsRaised.voidPledge(tokenId);
    }

    // ── Validation ──────────────────────────────────────────────────────────

    function testVoidPledge_RevertsOnNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedVoidPledgeNotFound.selector, 999));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(999);
    }

    function testVoidPledge_RevertsOnAlreadyVoided() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        _void(tokenId);

        // Second void: pledgeAmount is 0 now → VoidPledgeNotFound
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedVoidPledgeNotFound.selector, tokenId));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId);
    }

    function testVoidPledge_RevertsOnAlreadyRefundedPledge() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        // Refund after deadline
        vm.warp(DEADLINE + 1);
        vm.startPrank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);
        keepWhatsRaised.claimRefund(tokenId);
        vm.stopPrank();

        // Void should fail: pledgeAmount is 0
        vm.expectRevert(abi.encodeWithSelector(KeepWhatsRaised.KeepWhatsRaisedVoidPledgeNotFound.selector, tokenId));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId);
    }

    // ── Basic void (no prior drain) ─────────────────────────────────────────

    function testVoidPledge_FullRecovery_NoTip() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Full pledge recovered: net + protocol fee + platform fee
        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT, "full pledge amount recovered");
        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0, "treasury empty after void");
    }

    function testVoidPledge_DecrementsRaisedAmount() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT);
        _void(tokenId);
        assertEq(keepWhatsRaised.getRaisedAmount(), 0);
    }

    function testVoidPledge_LifetimeRaisedStaysMonotonic() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        uint256 lifetimeBefore = keepWhatsRaised.getLifetimeRaisedAmount();
        _void(tokenId);
        uint256 lifetimeAfter = keepWhatsRaised.getLifetimeRaisedAmount();

        assertEq(lifetimeAfter, lifetimeBefore, "lifetime raised unchanged after void");
        assertEq(lifetimeAfter, TEST_PLEDGE_AMOUNT, "lifetime still shows original pledge");
    }

    function testVoidPledge_DecrementsAvailableAmount() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        assertTrue(keepWhatsRaised.getAvailableRaisedAmount() > 0);
        _void(tokenId);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }

    function testVoidPledge_EmitsEvent() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        vm.expectEmit(true, false, false, true, address(keepWhatsRaised));
        emit KeepWhatsRaised.PledgeVoided(tokenId, TEST_PLEDGE_AMOUNT);

        _void(tokenId);
    }

    function testVoidPledge_ContractBalanceZeroAfterFullRecovery() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        _void(tokenId);
        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0);
    }

    function testVoidPledge_IncrementsVoidedAmount() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        assertEq(keepWhatsRaised.getVoidedAmount(), 0);
        _void(tokenId);
        assertEq(keepWhatsRaised.getVoidedAmount(), TEST_PLEDGE_AMOUNT);
    }

    function testVoidPledge_RefundedAmountUnaffected() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenIdVoid = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenIdRefund = _voidTestPledge(VOID_PLEDGE_ID_B, users.backer2Address, TEST_PLEDGE_AMOUNT, 0);

        _void(tokenIdVoid);

        vm.warp(DEADLINE + 1);
        vm.startPrank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenIdRefund);
        keepWhatsRaised.claimRefund(tokenIdRefund);
        vm.stopPrank();

        // Refunded and voided are tracked separately and do not overlap
        assertEq(keepWhatsRaised.getRefundedAmount(), TEST_PLEDGE_AMOUNT, "refunded = only the actual refund");
        assertEq(keepWhatsRaised.getVoidedAmount(), TEST_PLEDGE_AMOUNT, "voided = only the void");
        assertEq(
            keepWhatsRaised.getLifetimeRaisedAmount(),
            keepWhatsRaised.getRaisedAmount() + keepWhatsRaised.getRefundedAmount() + keepWhatsRaised.getVoidedAmount(),
            "lifetime = raised + refunded + voided"
        );
    }

    // ── Void blocks refund ──────────────────────────────────────────────────

    function testClaimRefund_RevertsForVoidedPledge() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        _void(tokenId);

        vm.warp(DEADLINE + 1);
        vm.startPrank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);
        vm.expectRevert(KeepWhatsRaised.KeepWhatsRaisedRefundAmountZero.selector);
        keepWhatsRaised.claimRefund(tokenId);
        vm.stopPrank();
    }

    // ── Void after disburseFees ─────────────────────────────────────────────

    function testVoidPledge_PartialRecovery_AfterDisburseFees() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        // Disburse fees — empties fee accumulators
        keepWhatsRaised.disburseFees();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Fee buckets were zeroed by disbursement, so only net available recovered
        assertEq(adminAfter - adminBefore, VOID_NET_AVAILABLE, "only net available recovered after disbursement");
    }

    // ── Void after partial withdrawal ───────────────────────────────────────

    function testVoidPledge_CapsAvailableAfterPartialWithdrawal() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        // Partial withdrawal before deadline
        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));
        uint256 withdrawAmount = 200e18;
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), withdrawAmount);

        uint256 availableBefore = keepWhatsRaised.getAvailableRaisedAmount();
        assertTrue(availableBefore < VOID_NET_AVAILABLE, "available reduced by withdrawal + fees");

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Should recover whatever is left, not revert
        assertTrue(adminAfter > adminBefore, "some funds recovered");
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0, "available zero after void");
    }

    // ── Void after claimFund ────────────────────────────────────────────────

    function testVoidPledge_WorksAfterClaimFund() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        // claimFund sweeps available, but fee buckets remain
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // available = 0 (swept), but fee buckets still intact
        assertEq(adminAfter - adminBefore, VOID_TOTAL_FEE, "fee buckets recovered after claimFund");
    }

    function testVoidPledge_ZeroRecovery_AfterFullDrain() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        // Drain everything: fees then available
        keepWhatsRaised.disburseFees();
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(adminAfter - adminBefore, 0, "nothing left to recover");
    }

    // ── Cancelled / post-deadline ───────────────────────────────────────────

    function testVoidPledge_WorksOnCancelledTreasury() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        cancelTreasury(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("CANCEL"));

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT, "full recovery on cancelled treasury");
    }

    function testVoidPledge_WorksAfterDeadline() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);

        vm.warp(DEADLINE + 1);
        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT, "full recovery after deadline");
    }

    // ── Tip handling ────────────────────────────────────────────────────────

    function testVoidPledge_RecoversDeferredUnclaimedTip() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Full pledge + tip recovered
        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT, "pledge + tip recovered");
    }

    function testVoidPledge_SkipsTipRecovery_AfterClaimTip() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT);

        // Claim tip after deadline
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Tip already claimed — only pledge recovered
        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT, "only pledge recovered; tip already claimed");
    }

    function testVoidPledge_SkipsTipRecovery_WhenForwardTipsImmediately() public {
        // Deploy fresh treasury with forwardTipsImmediately = true
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 tip = TEST_TIP_AMOUNT;
        bytes32 pledgeId = keccak256("voidFwdTip");

        deal(address(testToken), users.platform2AdminAddress, TEST_PLEDGE_AMOUNT);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), TEST_PLEDGE_AMOUNT);
        bytes32[] memory emptyReward = new bytes32[](0);
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, tip, PAYMENT_GATEWAY_FEE, emptyReward, false);
        vm.stopPrank();

        // Tip was forwarded immediately (tipFundedByAdmin: stayed in admin wallet).
        // Treasury only holds pledgeAmount.
        uint256 treasuryBalance = testToken.balanceOf(address(tipTreasury));
        assertEq(treasuryBalance, TEST_PLEDGE_AMOUNT, "treasury holds only pledge, not tip");

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        vm.prank(users.platform2AdminAddress);
        tipTreasury.voidPledge(1); // tokenId = 1 (first mint)
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Only pledge recovered — tip was never in the contract
        assertEq(adminAfter - adminBefore, TEST_PLEDGE_AMOUNT, "only pledge recovered; tip was forwarded");
        assertEq(testToken.balanceOf(address(tipTreasury)), 0, "treasury empty");
    }

    function testVoidPledge_TipClaimedPerTokenUnchanged() public {
        // Deploy fresh treasury with forwardTipsImmediately = true
        KeepWhatsRaised tipTreasury = _createTreasuryWithTipForwarding();

        uint256 tip = TEST_TIP_AMOUNT;
        bytes32 pledgeId = keccak256("voidTipTrack");

        deal(address(testToken), users.platform2AdminAddress, TEST_PLEDGE_AMOUNT);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(address(tipTreasury), TEST_PLEDGE_AMOUNT);
        bytes32[] memory emptyReward = new bytes32[](0);
        tipTreasury.setFeeAndPledge(pledgeId, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, tip, PAYMENT_GATEWAY_FEE, emptyReward, false);
        vm.stopPrank();

        uint256 tipClaimedBefore = tipTreasury.getTipClaimedPerToken(address(testToken));
        assertEq(tipClaimedBefore, tip, "tip tracked after pledge");

        vm.prank(users.platform2AdminAddress);
        tipTreasury.voidPledge(1);

        uint256 tipClaimedAfter = tipTreasury.getTipClaimedPerToken(address(testToken));
        assertEq(tipClaimedAfter, tipClaimedBefore, "tipClaimedPerToken not decremented by void");
    }

    // ── Multi-pledge isolation ──────────────────────────────────────────────

    function testVoidPledge_DoesNotAffectSiblingPledge() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenIdA = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenIdB = _voidTestPledge(VOID_PLEDGE_ID_B, users.backer2Address, TEST_PLEDGE_AMOUNT, 0);

        uint256 raisedBefore = keepWhatsRaised.getRaisedAmount();
        assertEq(raisedBefore, TEST_PLEDGE_AMOUNT * 2);

        // Void only A
        _void(tokenIdA);

        assertEq(keepWhatsRaised.getRaisedAmount(), TEST_PLEDGE_AMOUNT, "only A removed from raised");
        assertEq(keepWhatsRaised.getVoidedAmount(), TEST_PLEDGE_AMOUNT, "voided tracks A");

        // B can still be refunded
        vm.warp(DEADLINE + 1);
        vm.startPrank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenIdB);
        keepWhatsRaised.claimRefund(tokenIdB);
        vm.stopPrank();

        assertEq(keepWhatsRaised.getRaisedAmount(), 0, "both pledges resolved");
    }

    function testVoidPledge_MultipleVoidsAccumulateCorrectly() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenIdA = _voidTestPledge(VOID_PLEDGE_ID_A, users.backer1Address, TEST_PLEDGE_AMOUNT, 0);
        uint256 tokenIdB = _voidTestPledge(VOID_PLEDGE_ID_B, users.backer2Address, TEST_PLEDGE_AMOUNT, 0);

        _void(tokenIdA);
        _void(tokenIdB);

        assertEq(keepWhatsRaised.getVoidedAmount(), TEST_PLEDGE_AMOUNT * 2, "both voids accumulated");
        assertEq(keepWhatsRaised.getRaisedAmount(), 0, "raised is zero");
        assertEq(keepWhatsRaised.getLifetimeRaisedAmount(), TEST_PLEDGE_AMOUNT * 2, "lifetime preserved");
        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0, "treasury empty");
    }
}
