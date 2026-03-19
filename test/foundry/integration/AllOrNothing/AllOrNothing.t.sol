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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PermitData} from "src/interfaces/IPermit2.sol";

/// @notice Common testing logic needed by all AllOrNothing integration tests.
abstract contract AllOrNothing_Integration_Shared_Test is IReward, LogDecoder, Base_Test {
    bytes32 internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH = keccak256(
        "PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)"
    );
    string internal constant AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
        "PledgeForRewardWitness witness)PledgeForRewardWitness(address backer,bytes32 rewardsHash,uint256 shippingFee)TokenPermissions(address token,uint256 amount)";
    bytes32 internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH =
        keccak256("PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)");
    string internal constant AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
        "PledgeWithoutRewardWitness witness)PledgeWithoutRewardWitness(address backer,uint256 pledgeAmount)TokenPermissions(address token,uint256 amount)";

    address campaignAddress;
    address treasuryAddress;
    AllOrNothing internal allOrNothing;
    mapping(address => uint256) internal aonNonceCounter;

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
            PLATFORM_FEE_PERCENT,
            address(0) // Platform adapter - can be set later with setPlatformAdapter
        );
        vm.stopPrank();
    }

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(platformHash, 0, address(allOrNothingImplementation));
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
            CAMPAIGN_DATA,
            "Campaign Pledge NFT",
            "PLEDGE",
            "ipfs://QmExampleImageURI",
            "ipfs://QmExampleContractURI"
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        (bytes32[] memory topics,) = decodeTopicsAndData(
            entries, "CampaignInfoFactoryCampaignCreated(bytes32,address)", address(campaignInfoFactory)
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
        treasuryFactory.deploy(platformHash, campaignAddress, 0);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // Decode the TreasuryDeployed event
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            entries, "TreasuryFactoryTreasuryDeployed(bytes32,uint256,address,address)", address(treasuryFactory)
        );

        require(topics.length >= 3, "Expected indexed params missing");

        // treasuryAddress is in data, campaignAddress is in topics[2] (but we already know it)
        treasuryAddress = abi.decode(data, (address));

        allOrNothing = AllOrNothing(treasuryAddress);
    }

    function addRewards(address caller, address treasury, bytes32[] memory rewardNames, Reward[] memory rewards)
        internal
    {
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
    ) internal returns (Vm.Log[] memory logs, uint256 tokenId, bytes32[] memory rewards) {
        vm.startPrank(caller);
        vm.recordLogs();

        // Approve MockPermit2 (at canonical address) instead of the treasury directly.
        IERC20(token).approve(CANONICAL_PERMIT2_ADDRESS, type(uint256).max);
        vm.warp(launchTime);

        bytes32[] memory reward = new bytes32[](1);
        reward[0] = rewardName;

        uint256 nonce = aonNonceCounter[caller]++;
        PermitData memory permitData = _buildSignedAllOrNothingRewardPermitData(caller, address(token), shippingFee, reward, nonce, block.timestamp + 1 hours);

        AllOrNothing(allOrNothingAddress).pledgeForAReward(caller, address(token), shippingFee, reward, permitData);

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs, "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])", allOrNothingAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, shippingFee, tokenId, rewards
        (,,, tokenId, rewards) = abi.decode(data, (bytes32, uint256, uint256, uint256, bytes32[]));

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

        // Approve MockPermit2 (at canonical address) instead of the treasury directly.
        IERC20(token).approve(CANONICAL_PERMIT2_ADDRESS, type(uint256).max);
        vm.warp(launchTime);

        uint256 nonce = aonNonceCounter[caller]++;
        PermitData memory permitData = _buildSignedAllOrNothingNoRewardPermitData(caller, address(token), pledgeAmount, nonce, block.timestamp + 1 hours);

        AllOrNothing(allOrNothingAddress).pledgeWithoutAReward(caller, address(token), pledgeAmount, permitData);

        logs = vm.getRecordedLogs();

        // Decode receipt event if available
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs, "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])", allOrNothingAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, shippingFee, tokenId, rewards
        (,,, tokenId,) = abi.decode(data, (bytes32, uint256, uint256, uint256, bytes32[]));
        vm.stopPrank();
    }

    /**
     * @notice Implements claimRefund helper function.
     */
    function claimRefund(address caller, address allOrNothingAddress, uint256 tokenId, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, uint256 refundedTokenId, uint256 refundAmount, address claimer)
    {
        vm.warp(warpTime);
        vm.startPrank(caller);

        // Approve treasury to burn NFT
        CampaignInfo(campaignAddress).approve(allOrNothingAddress, tokenId);

        vm.recordLogs();

        AllOrNothing(allOrNothingAddress).claimRefund(tokenId);

        logs = vm.getRecordedLogs();

        bytes memory data = decodeEventFromLogs(logs, "RefundClaimed(uint256,uint256,address)", allOrNothingAddress);

        (refundedTokenId, refundAmount, claimer) = abi.decode(data, (uint256, uint256, address));

        vm.stopPrank();
    }

    /**
     * @notice Implements disburseFees helper function.
     */
    function disburseFees(address allOrNothingAddress, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, uint256 protocolShare, uint256 platformShare)
    {
        vm.warp(warpTime);
        vm.recordLogs();

        AllOrNothing(allOrNothingAddress).disburseFees();

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "FeesDisbursed(address,uint256,uint256)", allOrNothingAddress);

        // topics[1] is the indexed token
        (protocolShare, platformShare) = abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Implements withdraw helper function.
     */
    function withdraw(address allOrNothingAddress, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, address to, uint256 amount)
    {
        vm.warp(warpTime);
        // Start recording logs and simulate the withdrawal process
        vm.recordLogs();

        // Execute withdraw function in the contract
        AllOrNothing(allOrNothingAddress).withdraw();

        // Capture the logs from the transaction
        logs = vm.getRecordedLogs();

        // Decode the data from the logs
        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "WithdrawalSuccessful(address,address,uint256)", allOrNothingAddress);

        // topics[1] is the indexed token
        // Decode the amount and the address of the receiver
        (to, amount) = abi.decode(data, (address, uint256));

        return (logs, to, amount);
    }

    function _buildSignedAllOrNothingRewardPermitData(
        address backer,
        address token,
        uint256 shippingFee,
        bytes32[] memory rewardSelection,
        uint256 nonce,
        uint256 deadline
    ) internal returns (PermitData memory) {
        uint256 pledgeAmount;
        for (uint256 i = 0; i < rewardSelection.length; i++) {
            pledgeAmount += allOrNothing.getReward(rewardSelection[i]).rewardValue;
        }

        uint256 totalAmount = _denormalizeForToken(token, pledgeAmount) + _denormalizeForToken(token, shippingFee);
        bytes32 rewardsHash = keccak256(abi.encodePacked(rewardSelection));
        bytes32 witness = keccak256(
            abi.encode(AON_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, backer, rewardsHash, shippingFee)
        );

        return _buildSignedPermitData(
            backer, treasuryAddress, token, totalAmount, witness, AON_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING, nonce, deadline
        );
    }

    function _buildSignedAllOrNothingNoRewardPermitData(
        address backer,
        address token,
        uint256 pledgeAmount,
        uint256 nonce,
        uint256 deadline
    ) internal returns (PermitData memory) {
        bytes32 witness =
            keccak256(abi.encode(AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH, backer, pledgeAmount));

        return _buildSignedPermitData(
            backer,
            treasuryAddress,
            token,
            pledgeAmount,
            witness,
            AON_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING,
            nonce,
            deadline
        );
    }

    function _denormalizeForToken(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();

        if (decimals == 18) {
            return amount;
        }

        if (decimals < 18) {
            return amount / (10 ** (18 - decimals));
        }

        return amount * (10 ** (decimals - 18));
    }
}
