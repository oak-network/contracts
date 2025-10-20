// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {TimeConstrainedPaymentTreasury} from "src/treasuries/TimeConstrainedPaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";
import {Base_Test} from "../../Base.t.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

/// @notice Common testing logic needed by all TimeConstrainedPaymentTreasury integration tests.
abstract contract TimeConstrainedPaymentTreasury_Integration_Shared_Test is LogDecoder, Base_Test {
    address campaignAddress;
    address treasuryAddress;
    TimeConstrainedPaymentTreasury internal timeConstrainedPaymentTreasury;

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

    /// @dev Initial dependent functions setup included for TimeConstrainedPaymentTreasury Integration Tests.
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
        globalParams.enlistPlatform(platformHash, users.platform1AdminAddress, PLATFORM_FEE_PERCENT);
        vm.stopPrank();
    }

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        TimeConstrainedPaymentTreasury implementation = new TimeConstrainedPaymentTreasury();
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(platformHash, 3, address(implementation));
        vm.stopPrank();
    }

    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 3);
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
            CAMPAIGN_DATA
        );

        campaignAddress = campaignInfoFactory.identifierToCampaignInfo(identifierHash);
        campaignInfo = CampaignInfo(campaignAddress);

        // Store the actual campaign times for testing
        campaignLaunchTime = campaignInfo.getLaunchTime();
        campaignDeadline = campaignInfo.getDeadline();

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
            3, // TimeConstrainedPaymentTreasury type
            "TimeConstrainedPaymentTreasury",
            "TCPT"
        );

        timeConstrainedPaymentTreasury = TimeConstrainedPaymentTreasury(treasuryAddress);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to advance time to within the allowed range
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
     * @notice Helper function to advance time to after deadline + buffer time
     */
    function advanceToAfterDeadline() internal {
        vm.warp(campaignDeadline + BUFFER_TIME + 1);
    }

    /**
     * @notice Helper function to advance time to after launch time but before deadline
     */
    function advanceToAfterLaunch() internal {
        vm.warp(campaignLaunchTime + 1);
    }
}
