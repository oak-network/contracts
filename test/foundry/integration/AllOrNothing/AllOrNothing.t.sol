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

/// @notice Common testing logic needed by all AllOrNothing integration tests.
abstract contract AllOrNothing_Integration_Shared_Test is
    IReward,
    LogDecoder,
    Base_Test
{
    address campaignAddress;
    address treasuryAddress;
    AllOrNothing internal allOrNothing;

    uint256 pledgeForARewardTokenId;

    /// @dev Initial dependent functions setup included for AllOrNothing Integration Tests.
    function setUp() public virtual override {
        super.setUp();
        console.log("setUp: enlistPlatform");

        //Enlist Platform
        enlistPlatform(PLATFORM_1_HASH);
        console.log("enlisted platform");

        registerTreasuryImplementation(PLATFORM_1_HASH);
        console.log("registered treasury");

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
     * @notice Implements enlistPlatform helper function.
     * @param platformHash The platform bytes.
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

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(
            platformHash,
            0,
            address(allOrNothingImplementation)
        );
        vm.stopPrank();
    }

    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 0);
        vm.stopPrank();
    }

    /**
     * @notice Implements createCampaign helper function. It creates new campaign info contract
     * @param platformHash The platform bytes.
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
     * @notice Implements deploy helper function. It deploys treasury contract.
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
     * @notice Implements pledgeForAReward helper function.
     */
    function pledgeForAReward(
        address caller,
        address token,
        address allOrNothingAddress,
        uint256 pledgeAmount,
        uint256 shippingFee,
        uint256 launchTime,
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
        vm.recordLogs();

        testToken.approve(allOrNothingAddress, pledgeAmount + shippingFee);
        vm.warp(launchTime);

        bytes32[] memory reward = new bytes32[](1);
        reward[0] = rewardName;

        AllOrNothing(allOrNothingAddress).pledgeForAReward(
            caller,
            address(token),
            shippingFee,
            reward
        );

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs,
            "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])",
            allOrNothingAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, shippingFee, tokenId, rewards
        (, , , tokenId, rewards) = abi.decode(
            data,
            (bytes32, uint256, uint256, uint256, bytes32[])
        );

        vm.stopPrank();
    }

    /**
     * @notice Implements pledgeWithoutAReward helper function.
     */
    function pledgeWithoutAReward(
        address caller,
        address token,
        address allOrNothingAddress,
        uint256 pledgeAmount,
        uint256 launchTime
    ) internal returns (Vm.Log[] memory logs, uint256 tokenId) {
        vm.startPrank(caller);
        vm.recordLogs();

        testToken.approve(allOrNothingAddress, pledgeAmount);
        vm.warp(launchTime);

        AllOrNothing(allOrNothingAddress).pledgeWithoutAReward(
            caller,
            address(token),
            pledgeAmount
        );

        logs = vm.getRecordedLogs();

        // Decode receipt event if available
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs,
            "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])",
            allOrNothingAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, shippingFee, tokenId, rewards
        (, , , tokenId, ) = abi.decode(
            data,
            (bytes32, uint256, uint256, uint256, bytes32[])
        );
        vm.stopPrank();
    }

    /**
     * @notice Implements claimRefund helper function.
     */
    function claimRefund(
        address caller,
        address allOrNothingAddress,
        uint256 tokenId,
        uint256 warpTime
    )
        internal
        returns (
            Vm.Log[] memory logs,
            uint256 refundedTokenId,
            uint256 refundAmount,
            address claimer
        )
    {
        vm.warp(warpTime);
        vm.startPrank(caller);
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
     * @notice Implements disburseFees helper function.
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

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs,
            "FeesDisbursed(address,uint256,uint256)",
            allOrNothingAddress
        );

        // topics[1] is the indexed token
        (protocolShare, platformShare) = abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Implements withdraw helper function.
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
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs,
            "WithdrawalSuccessful(address,address,uint256)",
            allOrNothingAddress
        );

        // topics[1] is the indexed token
        // Decode the amount and the address of the receiver
        (to, amount) = abi.decode(data, (address, uint256));

        return (logs, to, amount);
    }
}
