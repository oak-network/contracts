// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {GoalBasedPaymentTreasury} from "src/treasuries/GoalBasedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";
import {Base_Test} from "../../Base.t.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

/// @notice Common testing logic needed by all GoalBasedPaymentTreasury integration tests.
abstract contract GoalBasedPaymentTreasury_Integration_Shared_Test is LogDecoder, Base_Test {
    address campaignAddress;
    address treasuryAddress;
    GoalBasedPaymentTreasury internal goalBasedPaymentTreasury;

    // Payment test data
    bytes32 internal constant PAYMENT_ID_1 = keccak256("payment1");
    bytes32 internal constant PAYMENT_ID_2 = keccak256("payment2");
    bytes32 internal constant PAYMENT_ID_3 = keccak256("payment3");
    bytes32 internal constant ITEM_ID_1 = keccak256("item1");
    bytes32 internal constant ITEM_ID_2 = keccak256("item2");
    uint256 internal constant PAYMENT_AMOUNT_1 = 1000e18;
    uint256 internal constant PAYMENT_AMOUNT_2 = 2000e18;
    uint256 internal constant PAYMENT_EXPIRATION = 7 days;
    bytes32 internal constant BUYER_ID_1 = keccak256("buyer1");
    bytes32 internal constant BUYER_ID_2 = keccak256("buyer2");
    bytes32 internal constant BUYER_ID_3 = keccak256("buyer3");

    // Time constraint test data
    uint256 internal constant BUFFER_TIME = 1 days;
    uint256 internal campaignLaunchTime;
    uint256 internal campaignDeadline;
    uint256 internal campaignGoalAmount;

    /// @dev Initial dependent functions setup included for GoalBasedPaymentTreasury Integration Tests.
    function setUp() public virtual override {
        super.setUp();
        console.log("setUp: enlistPlatform");

        // Enlist Platform
        enlistPlatform(PLATFORM_1_HASH);
        console.log("enlisted platform");

        registerTreasuryImplementation(PLATFORM_1_HASH);
        console.log("registered treasury");

        approveTreasuryImplementation(PLATFORM_1_HASH);
        console.log("approved treasury");

        // Set buffer time in GlobalParams
        setBufferTime();
        console.log("set buffer time");

        // Create Campaign with specific time constraints
        createCampaignWithTimeConstraints(PLATFORM_1_HASH);
        console.log("created campaign with time constraints");

        // Deploy Treasury Contract
        deploy(PLATFORM_1_HASH);
        console.log("deployed treasury");
    }

    /**
     * @notice Sets buffer time in GlobalParams dataRegistry
     */
    function setBufferTime() internal {
        vm.startPrank(users.protocolAdminAddress);
        globalParams.addToRegistry(DataRegistryKeys.BUFFER_TIME, bytes32(BUFFER_TIME));
        vm.stopPrank();
    }

    /**
     * @notice Implements enlistPlatform helper function.
     * @param platformHash The platform bytes.
     */
    function enlistPlatform(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        globalParams.enlistPlatform(platformHash, users.platform1AdminAddress, PLATFORM_FEE_PERCENT, address(0));
        vm.stopPrank();
    }

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        GoalBasedPaymentTreasury implementation = new GoalBasedPaymentTreasury();
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(platformHash, 4, address(implementation));
        vm.stopPrank();
    }

    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 4);
        vm.stopPrank();
    }

    /**
     * @notice Creates campaign with specific time constraints for testing
     * @param platformHash The platform bytes.
     */
    function createCampaignWithTimeConstraints(bytes32 platformHash) internal {
        bytes32 identifierHash = keccak256(abi.encodePacked(platformHash));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = platformHash;

        bytes32[] memory platformDataKey = new bytes32[](0);
        bytes32[] memory platformDataValue = new bytes32[](0);

        vm.startPrank(users.creator1Address);
        vm.recordLogs();

        campaignInfoFactory.createCampaign(
            users.creator1Address,
            identifierHash,
            selectedPlatformHash,
            platformDataKey,
            platformDataValue,
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );

        campaignAddress = campaignInfoFactory.identifierToCampaignInfo(identifierHash);
        campaignInfo = CampaignInfo(campaignAddress);

        // Store the actual campaign times for testing
        campaignLaunchTime = campaignInfo.getLaunchTime();
        campaignDeadline = campaignInfo.getDeadline();
        campaignGoalAmount = campaignInfo.getGoalAmount();

        // Set specific launch time and deadline for testing
        vm.warp(campaignLaunchTime);
        vm.stopPrank();
    }

    /**
     * @notice Implements deploy helper function. It deploys new treasury contract
     * @param platformHash The platform bytes.
     */
    function deploy(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        vm.recordLogs();

        treasuryAddress = treasuryFactory.deploy(
            platformHash,
            campaignAddress,
            4 // GoalBasedPaymentTreasury type
        );

        goalBasedPaymentTreasury = GoalBasedPaymentTreasury(treasuryAddress);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to advance time to within the allowed range (before deadline)
     */
    function advanceToWithinRange() internal {
        uint256 currentTime = campaignLaunchTime + (campaignDeadline - campaignLaunchTime) / 2; // Middle of the range
        vm.warp(currentTime);
    }

    /**
     * @notice Helper function to advance time to before launch time
     */
    function advanceToBeforeLaunch() internal {
        vm.warp(campaignLaunchTime - 1);
    }

    /**
     * @notice Helper function to advance time to after deadline (but before buffer ends)
     */
    function advanceToAfterDeadline() internal {
        vm.warp(campaignDeadline + 1);
    }

    /**
     * @notice Helper function to advance time to after deadline + buffer time
     */
    function advanceToAfterDeadlinePlusBuffer() internal {
        vm.warp(campaignDeadline + BUFFER_TIME + 1);
    }

    /**
     * @notice Helper function to advance time to after launch time but before deadline
     */
    function advanceToAfterLaunch() internal {
        vm.warp(campaignLaunchTime + 1);
    }

    /**
     * @notice Helper function to advance time to exactly at the deadline
     */
    function advanceToDeadline() internal {
        vm.warp(campaignDeadline);
    }

    /**
     * @notice Helper function to advance time to exactly at the deadline + buffer
     */
    function advanceToDeadlinePlusBuffer() internal {
        vm.warp(campaignDeadline + BUFFER_TIME);
    }

    /**
     * @notice Helper function to create and fund a payment
     * @dev Uses expiration that extends past deadline + buffer to avoid expiration during tests
     */
    function _createAndFundPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        uint256 amount,
        address buyerAddress
    ) internal {
        // Fund buyer
        deal(address(testToken), buyerAddress, amount);

        // Buyer approves treasury
        vm.prank(buyerAddress);
        testToken.approve(treasuryAddress, amount);

        // Create payment with expiration that extends past deadline + buffer
        // This ensures payments don't expire during buffer period tests
        uint256 expiration = campaignDeadline + BUFFER_TIME + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        ICampaignPaymentTreasury.ExternalFees[] memory emptyExternalFees =
            new ICampaignPaymentTreasury.ExternalFees[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            paymentId, buyerId, itemId, address(testToken), amount, expiration, emptyLineItems, emptyExternalFees
        );

        // Transfer tokens from buyer to treasury
        vm.prank(buyerAddress);
        testToken.transfer(treasuryAddress, amount);
    }

    /**
     * @notice Helper function to create and process a crypto payment
     */
    function _createAndProcessCryptoPayment(bytes32 paymentId, bytes32 itemId, uint256 amount, address buyerAddress)
        internal
    {
        // Fund buyer
        deal(address(testToken), buyerAddress, amount);

        // Buyer approves treasury
        vm.prank(buyerAddress);
        testToken.approve(treasuryAddress, amount);

        // Process crypto payment
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            paymentId,
            itemId,
            buyerAddress,
            address(testToken),
            amount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    /**
     * @notice Helper function to fund the campaign to meet the goal
     */
    function _fundCampaignToMeetGoal() internal {
        // Fund with goal amount using crypto payments
        deal(address(testToken), users.backer1Address, campaignGoalAmount);
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, campaignGoalAmount);

        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.processCryptoPayment(
            keccak256("goalPayment"),
            ITEM_ID_1,
            users.backer1Address,
            address(testToken),
            campaignGoalAmount,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );
    }

    /**
     * @notice Helper function to fund the campaign with pending payments to meet goal
     */
    function _fundCampaignWithPendingPaymentsToMeetGoal() internal {
        // Create pending payment for goal amount
        deal(address(testToken), users.backer1Address, campaignGoalAmount);
        vm.prank(users.backer1Address);
        testToken.approve(treasuryAddress, campaignGoalAmount);

        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        ICampaignPaymentTreasury.LineItem[] memory emptyLineItems = new ICampaignPaymentTreasury.LineItem[](0);
        vm.prank(users.platform1AdminAddress);
        goalBasedPaymentTreasury.createPayment(
            keccak256("goalPendingPayment"),
            BUYER_ID_1,
            ITEM_ID_1,
            address(testToken),
            campaignGoalAmount,
            expiration,
            emptyLineItems,
            new ICampaignPaymentTreasury.ExternalFees[](0)
        );

        // Transfer tokens to treasury
        vm.prank(users.backer1Address);
        testToken.transfer(treasuryAddress, campaignGoalAmount);
    }

}

