// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Base_Test} from "../../Base.t.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "src/CampaignInfo.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";

/**
 * @title AllOrNothing Integration Test Shared Contract
 * @notice Common testing logic needed by all AllOrNothing integration tests.
 * @dev Abstract contract that provides shared setup and helper functions for AllOrNothing treasury testing.
 *      Handles platform enrollment, treasury implementation registration, campaign creation, and treasury deployment.
 *      Also provides utility functions for pledging, refunding, fee disbursement, and withdrawals.
 */
abstract contract AllOrNothing_Integration_Shared_Test is
    IReward,
    LogDecoder,
    Base_Test
{
    /// @dev Address of the created campaign contract
    address campaignAddress;

    /// @dev Address of the deployed treasury contract
    address treasuryAddress;

    /// @dev Instance of the AllOrNothing treasury contract
    AllOrNothing internal allOrNothing;

    /// @dev Token ID for pledges that include rewards
    uint256 pledgeForARewardTokenId;

    /**
     * @notice Initial setup for AllOrNothing integration tests
     * @dev Performs the complete setup sequence: platform enrollment, treasury registration,
     *      campaign creation, and treasury deployment. Called by inheriting test contracts.
     */
    function setUp() public virtual override {
        super.setUp();
        console.log("setUp: enlistPlatform");

        //Enlist Platform
        enlistPlatform(PLATFORM_1_HASH);
        console.log("enlisted platform");

        //Register Treasury Implementation
        registerTreasuryImplementation(PLATFORM_1_HASH);
        console.log("registered treasury");

        //Approve Treasury Implementation
        approveTreasuryImplementation(PLATFORM_1_HASH);
        console.log("approved treasury");

        //Create Campaign
        createCampaign(PLATFORM_1_HASH);
        console.log("created campaign");

        //Deploy Treasury Contract
        deploy(PLATFORM_1_HASH);
        console.log("deployed treasury");
    }

    /**
     * @notice Enlists a platform in the protocol
     * @dev Called by protocol admin to register a new platform with specified fee structure
     * @param platformHash The unique identifier hash for the platform
     */
    function enlistPlatform(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        globalParams.enlistPlatform(
            platformHash,
            users.platform1AdminAddress,
            PLATFORM_FEE_PERCENT
        );
        vm.stopPrank();
    }

    /**
     * @notice Registers a treasury implementation for a platform
     * @dev Called by platform admin to register AllOrNothing treasury implementation
     * @param platformHash The platform identifier to register the treasury for
     */
    function registerTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(
            platformHash,
            0,
            address(allOrNothingImplementation)
        );
        vm.stopPrank();
    }

    /**
     * @notice Approves a registered treasury implementation
     * @dev Called by protocol admin to approve a platform's treasury implementation
     * @param platformHash The platform identifier whose treasury implementation to approve
     */
    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 0);
        vm.stopPrank();
    }

    /**
     * @notice Creates a new campaign for testing
     * @dev Creates a campaign info contract and extracts the campaign address from emitted events
     * @param platformHash The platform identifier to create the campaign on
     */
    function createCampaign(bytes32 platformHash) internal {
        bytes32 identifierHash = keccak256(abi.encodePacked(platformHash));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        bytes32[] memory platformDataKey;
        bytes32[] memory platformDataValue;
        selectedPlatformHash[0] = platformHash;

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

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        (bytes32[] memory topics, ) = decodeTopicsAndData(
            entries,
            "CampaignInfoFactoryCampaignCreated(bytes32,address)",
            address(campaignInfoFactory)
        );

        require(topics.length == 3, "Unexpected topic length for event");

        campaignAddress = address(uint160(uint256(topics[2])));
    }

    /**
     * @notice Deploys a treasury contract for the created campaign
     * @dev Deploys AllOrNothing treasury and extracts the treasury address from emitted events
     * @param platformHash The platform identifier to deploy the treasury for
     */
    function deploy(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        vm.recordLogs();

        // Deploy the treasury contract
        treasuryFactory.deploy(platformHash, campaignAddress, 0, NAME, SYMBOL);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // Decode the TreasuryDeployed event
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            entries,
            "TreasuryFactoryTreasuryDeployed(bytes32,uint256,address,address)",
            address(treasuryFactory)
        );

        require(topics.length >= 3, "Expected indexed params missing");

        // treasuryAddress is in data, campaignAddress is in topics[2] (but we already know it)
        treasuryAddress = abi.decode(data, (address));

        allOrNothing = AllOrNothing(treasuryAddress);
    }

    /**
     * @notice Adds rewards to a treasury contract
     * @dev Helper function to add reward tiers to an AllOrNothing treasury
     * @param caller The address that will call the addRewards function
     * @param treasury The treasury contract address
     * @param rewardNames Array of reward names/identifiers
     * @param rewards Array of reward structs containing reward details
     */
    function addRewards(
        address caller,
        address treasury,
        bytes32[] memory rewardNames,
        Reward[] memory rewards
    ) internal {
        vm.startPrank(caller);
        AllOrNothing(treasury).addRewards(rewardNames, rewards);
        vm.stopPrank();
    }

    /**
     * @notice Simulates pledging for a specific reward
     * @dev Creates a pledge with reward selection and captures the receipt event
     * @param caller The address making the pledge
     * @param warpTime The block timestamp to warp to
     * @param allOrNothingAddress The treasury contract address
     * @param pledgeAmount The amount to pledge (automatically calculated from reward)
     * @param shippingFee The shipping fee for the reward
     * @param rewardName The identifier of the reward being pledged for
     * @return logs The transaction logs
     * @return tokenId The NFT token ID representing the pledge
     * @return rewards Array of reward names associated with the pledge
     */
    function pledgeForAReward(
        address caller,
        uint256 warpTime,
        address allOrNothingAddress,
        uint256 pledgeAmount,
        uint256 shippingFee,
        bytes32 rewardName
    )
        internal
        returns (
            Vm.Log[] memory logs,
            uint256 tokenId,
            bytes32[] memory rewards
        )
    {
        vm.startPrank(caller);
        vm.warp(warpTime);
        vm.recordLogs();

        testToken.approve(allOrNothingAddress, pledgeAmount + shippingFee);

        bytes32[] memory reward = new bytes32[](1);
        reward[0] = rewardName;

        AllOrNothing(allOrNothingAddress).pledgeForAReward(
            caller,
            shippingFee,
            reward
        );

        logs = vm.getRecordedLogs();

        bytes memory data = decodeEventFromLogs(
            logs,
            "Receipt(address,bytes32,uint256,uint256,uint256,bytes32[])",
            allOrNothingAddress
        );

        (, , tokenId, rewards) = abi.decode(
            data,
            (uint256, uint256, uint256, bytes32[])
        );

        vm.stopPrank();
    }

    /**
     * @notice Simulates pledging without selecting a reward
     * @dev Creates a pledge without reward selection and captures the receipt event
     * @param caller The address making the pledge
     * @param warpTime The block timestamp to warp to
     * @param allOrNothingAddress The treasury contract address
     * @param pledgeAmount The amount to pledge
     * @return logs The transaction logs
     * @return tokenId The NFT token ID representing the pledge
     */
    function pledgeWithoutAReward(
        address caller,
        uint256 warpTime,
        address allOrNothingAddress,
        uint256 pledgeAmount
    ) internal returns (Vm.Log[] memory logs, uint256 tokenId) {
        vm.startPrank(caller);
        vm.warp(warpTime);
        vm.recordLogs();

        testToken.approve(allOrNothingAddress, pledgeAmount);

        AllOrNothing(allOrNothingAddress).pledgeWithoutAReward(
            caller,
            pledgeAmount
        );

        logs = vm.getRecordedLogs();

        // Decode receipt event if available
        bytes memory data = decodeEventFromLogs(
            logs,
            "Receipt(address,bytes32,uint256,uint256,uint256,bytes32[])",
            allOrNothingAddress
        );

        (, , tokenId, ) = abi.decode(
            data,
            (uint256, uint256, uint256, bytes32[])
        );
        vm.stopPrank();
    }

    /**
     * @notice Simulates claiming a refund for a failed campaign
     * @dev Claims refund for a pledge token and captures the refund event
     * @param caller The address claiming the refund
     * @param warpTime The block timestamp to warp to
     * @param allOrNothingAddress The treasury contract address
     * @param tokenId The pledge token ID to refund
     * @return logs The transaction logs
     * @return refundedTokenId The token ID that was refunded
     * @return refundAmount The amount refunded
     * @return claimer The address that claimed the refund
     */
    function claimRefund(
        address caller,
        uint256 warpTime,
        address allOrNothingAddress,
        uint256 tokenId
    )
        internal
        returns (
            Vm.Log[] memory logs,
            uint256 refundedTokenId,
            uint256 refundAmount,
            address claimer
        )
    {
        vm.startPrank(caller);
        vm.warp(warpTime);
        vm.recordLogs();

        AllOrNothing(allOrNothingAddress).claimRefund(tokenId);

        logs = vm.getRecordedLogs();

        bytes memory data = decodeEventFromLogs(
            logs,
            "RefundClaimed(uint256,uint256,address)",
            allOrNothingAddress
        );

        (refundedTokenId, refundAmount, claimer) = abi.decode(
            data,
            (uint256, uint256, address)
        );

        vm.stopPrank();
    }

    /**
     * @notice Simulates fee disbursement for a successful campaign
     * @dev Disburses protocol and platform fees and captures the disbursement event
     * @param allOrNothingAddress The treasury contract address
     * @param warpTime The block timestamp to warp to
     * @return logs The transaction logs
     * @return protocolShare The amount allocated to protocol fees
     * @return platformShare The amount allocated to platform fees
     */
    function disburseFees(
        address allOrNothingAddress,
        uint256 warpTime
    )
        internal
        returns (
            Vm.Log[] memory logs,
            uint256 protocolShare,
            uint256 platformShare
        )
    {
        vm.warp(warpTime);
        vm.recordLogs();

        AllOrNothing(allOrNothingAddress).disburseFees();

        logs = vm.getRecordedLogs();

        bytes memory data = decodeEventFromLogs(
            logs,
            "FeesDisbursed(uint256,uint256)",
            allOrNothingAddress
        );

        (protocolShare, platformShare) = abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Simulates withdrawal of funds from a successful campaign
     * @dev Withdraws remaining funds to campaign creator and captures the withdrawal event
     * @param allOrNothingAddress The treasury contract address
     * @param warpTime The block timestamp to warp to
     * @return logs The transaction logs
     * @return to The address that received the withdrawal
     * @return amount The amount withdrawn
     */
    function withdraw(
        address allOrNothingAddress,
        uint256 warpTime
    ) internal returns (Vm.Log[] memory logs, address to, uint256 amount) {
        vm.warp(warpTime);
        // Start recording logs and simulate the withdrawal process
        vm.recordLogs();

        // Execute withdraw function in the contract
        AllOrNothing(allOrNothingAddress).withdraw();

        // Capture the logs from the transaction
        logs = vm.getRecordedLogs();

        // Decode the data from the logs
        bytes memory data = decodeEventFromLogs(
            logs,
            "WithdrawalSuccessful(address,uint256)",
            allOrNothingAddress
        );

        // Decode the amount and the address of the receiver
        (to, amount) = abi.decode(data, (address, uint256));

        return (logs, to, amount);
    }

    /**
     * @notice Removes a reward from a treasury contract
     * @dev Helper function to remove a reward from an AllOrNothing treasury
     * @param caller The address that will call the removeReward function
     * @param treasury The treasury contract address
     * @param rewardName The name of the reward to remove
     * @return logs The transaction logs
     */
    function removeReward(
        address caller,
        address treasury,
        bytes32 rewardName
    ) internal returns (Vm.Log[] memory logs) {
        vm.startPrank(caller);
        vm.recordLogs();

        AllOrNothing(treasury).removeReward(rewardName);

        logs = vm.getRecordedLogs();
        vm.stopPrank();
    }

    /**
     * @notice Pauses a treasury contract
     * @dev Helper function to pause an AllOrNothing treasury
     * @param caller The address that will call the pauseTreasury function
     * @param treasury The treasury contract address
     * @param reason The reason for pausing
     * @return logs The transaction logs
     */
    function pauseTreasury(
        address caller,
        address treasury,
        bytes32 reason
    ) internal returns (Vm.Log[] memory logs) {
        vm.startPrank(caller);
        vm.recordLogs();

        AllOrNothing(treasury).pauseTreasury(reason);

        logs = vm.getRecordedLogs();
        vm.stopPrank();
    }

    /**
     * @notice Unpauses a treasury contract
     * @dev Helper function to unpause an AllOrNothing treasury
     * @param caller The address that will call the unpauseTreasury function
     * @param treasury The treasury contract address
     * @param reason The reason for unpausing
     * @return logs The transaction logs
     */
    function unpauseTreasury(
        address caller,
        address treasury,
        bytes32 reason
    ) internal returns (Vm.Log[] memory logs) {
        vm.startPrank(caller);
        vm.recordLogs();

        AllOrNothing(treasury).unpauseTreasury(reason);

        logs = vm.getRecordedLogs();
        vm.stopPrank();
    }

    /**
     * @notice Cancels a treasury contract
     * @dev Helper function to cancel an AllOrNothing treasury
     * @param caller The address that will call the cancelTreasury function
     * @param treasury The treasury contract address
     * @param reason The reason for cancellation
     * @return logs The transaction logs
     */
    function cancelTreasury(
        address caller,
        address treasury,
        bytes32 reason
    ) internal returns (Vm.Log[] memory logs) {
        vm.startPrank(caller);
        vm.recordLogs();

        AllOrNothing(treasury).cancelTreasury(reason);

        logs = vm.getRecordedLogs();
        vm.stopPrank();
    }
}
