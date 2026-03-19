// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";
import {Base_Test} from "../../Base.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PermitData} from "src/interfaces/IPermit2.sol";

/// @notice Common testing logic needed by all KeepWhatsRaised integration tests.
abstract contract KeepWhatsRaised_Integration_Shared_Test is IReward, LogDecoder, Base_Test {
    bytes32 internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH = keccak256(
        "KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)"
    );
    string internal constant KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING =
        "KWRPledgeForRewardWitness witness)KWRPledgeForRewardWitness(bytes32 pledgeId,address backer,bytes32 rewardsHash,uint256 tip)TokenPermissions(address token,uint256 amount)";
    bytes32 internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPEHASH = keccak256(
        "KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)"
    );
    string internal constant KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING =
        "KWRPledgeWithoutRewardWitness witness)KWRPledgeWithoutRewardWitness(bytes32 pledgeId,address backer,uint256 pledgeAmount,uint256 tip)TokenPermissions(address token,uint256 amount)";

    address campaignAddress;
    address treasuryAddress;
    KeepWhatsRaised internal keepWhatsRaised;

    uint256 pledgeForARewardTokenId;
    uint256 private _resetCounter;

    /// @dev Initial dependent functions setup included for KeepWhatsRaised Integration Tests.
    function setUp() public virtual override {
        super.setUp();
        console.log("setUp: enlistPlatform");

        // Enlist Platform
        enlistPlatform(PLATFORM_2_HASH);
        console.log("enlisted platform");

        registerTreasuryImplementation(PLATFORM_2_HASH);
        console.log("registered treasury");

        approveTreasuryImplementation(PLATFORM_2_HASH);
        console.log("approved treasury");

        // Create Campaign
        createCampaign(PLATFORM_2_HASH);
        console.log("created campaign");

        // Deploy Treasury Contract
        deploy(PLATFORM_2_HASH);
        console.log("deployed treasury");

        // Create FeeValues struct
        KeepWhatsRaised.FeeValues memory feeValues = KeepWhatsRaised.FeeValues({
            flatFeeValue: uint256(FLAT_FEE_VALUE),
            cumulativeFlatFeeValue: uint256(CUMULATIVE_FLAT_FEE_VALUE),
            grossPercentageFeeValues: new uint256[](2)
        });
        feeValues.grossPercentageFeeValues[0] = uint256(PLATFORM_FEE_VALUE);
        feeValues.grossPercentageFeeValues[1] = uint256(VAKI_COMMISSION_VALUE);

        // Configure Treasury with fee values
        configureTreasury(users.platform2AdminAddress, treasuryAddress, CONFIG, CAMPAIGN_DATA, FEE_KEYS, feeValues);
        console.log("configured treasury");
    }

    /**
     * @notice Implements enlistPlatform helper function.
     * @param platformHash The platform bytes.
     */
    function enlistPlatform(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        globalParams.enlistPlatform(platformHash, users.platform2AdminAddress, PLATFORM_FEE_PERCENT, address(0));
        vm.stopPrank();
    }

    /**
     * @notice Adds platform data keys.
     * @param platformHash The platform bytes.
     */
    function addPlatformData(bytes32 platformHash) internal {
        vm.startPrank(users.platform2AdminAddress);

        // Add platform data keys (flat fees only, percentage fees are in GROSS_PERCENTAGE_FEE_KEYS)
        globalParams.addPlatformData(platformHash, FLAT_FEE_KEY);
        globalParams.addPlatformData(platformHash, CUMULATIVE_FLAT_FEE_KEY);

        // Add gross percentage fee keys (includes PLATFORM_FEE_KEY and VAKI_COMMISSION_KEY)
        for (uint256 i = 0; i < GROSS_PERCENTAGE_FEE_KEYS.length; i++) {
            globalParams.addPlatformData(platformHash, GROSS_PERCENTAGE_FEE_KEYS[i]);
        }

        vm.stopPrank();
    }

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.platform2AdminAddress);
        treasuryFactory.registerTreasuryImplementation(platformHash, 1, address(keepWhatsRaisedImplementation));
        vm.stopPrank();
    }

    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 1);
        vm.stopPrank();
    }

    /**
     * @notice Implements createCampaign helper function. It creates new campaign info contract
     * @param platformHash The platform bytes.
     */
    function createCampaign(bytes32 platformHash) internal {
        bytes32 identifierHash = keccak256(abi.encodePacked(platformHash));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = platformHash;

        // Pass empty arrays since fees are now configured via configureTreasury
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
        vm.startPrank(users.platform2AdminAddress);
        vm.recordLogs();

        // Deploy the treasury contract
        treasuryFactory.deploy(platformHash, campaignAddress, 1);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // Decode the TreasuryDeployed event
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            entries, "TreasuryFactoryTreasuryDeployed(bytes32,uint256,address,address)", address(treasuryFactory)
        );

        require(topics.length >= 3, "Expected indexed params missing");

        treasuryAddress = abi.decode(data, (address));

        keepWhatsRaised = KeepWhatsRaised(treasuryAddress);
    }

    /**
     * @notice Implements configureTreasury helper function.
     */
    function configureTreasury(
        address caller,
        address treasury,
        KeepWhatsRaised.Config memory _config,
        ICampaignData.CampaignData memory campaignData,
        KeepWhatsRaised.FeeKeys memory _feeKeys,
        KeepWhatsRaised.FeeValues memory _feeValues
    ) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).configureTreasury(_config, campaignData, _feeKeys, _feeValues);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to create FeeValues struct
     */
    function createFeeValues() internal pure returns (KeepWhatsRaised.FeeValues memory) {
        KeepWhatsRaised.FeeValues memory feeValues;
        feeValues.flatFeeValue = uint256(FLAT_FEE_VALUE);
        feeValues.cumulativeFlatFeeValue = uint256(CUMULATIVE_FLAT_FEE_VALUE);
        feeValues.grossPercentageFeeValues = new uint256[](2);
        feeValues.grossPercentageFeeValues[0] = uint256(PLATFORM_FEE_VALUE);
        feeValues.grossPercentageFeeValues[1] = uint256(VAKI_COMMISSION_VALUE);
        return feeValues;
    }

    /**
     * @notice Approves withdrawal for the treasury.
     */
    function approveWithdrawal(address caller, address treasury) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).approveWithdrawal();
        vm.stopPrank();
    }

    /**
     * @notice Updates the deadline of the campaign.
     */
    function updateDeadline(address caller, address treasury, uint256 newDeadline) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).updateDeadline(newDeadline);
        vm.stopPrank();
    }

    /**
     * @notice Updates the goal amount of the campaign.
     */
    function updateGoalAmount(address caller, address treasury, uint256 newGoalAmount) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).updateGoalAmount(newGoalAmount);
        vm.stopPrank();
    }

    /**
     * @notice Adds rewards to the campaign.
     */
    function addRewards(address caller, address treasury, bytes32[] memory rewardNames, Reward[] memory rewards)
        internal
    {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).addRewards(rewardNames, rewards);
        vm.stopPrank();
    }

    /**
     * @notice Removes a reward from the campaign.
     */
    function removeReward(address caller, address treasury, bytes32 rewardName) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).removeReward(rewardName);
        vm.stopPrank();
    }

    /**
     * @notice Sets payment gateway fee for a pledge.
     */
    function setPaymentGatewayFee(address caller, address treasury, bytes32 pledgeId, uint256 fee) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).setPaymentGatewayFee(pledgeId, fee);
        vm.stopPrank();
    }

    /**
     * @notice Implements setFeeAndPledge helper function.
     */
    function setFeeAndPledge(
        address caller,
        address treasury,
        bytes32 pledgeId,
        address backer,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 fee,
        bytes32[] memory reward,
        bool isPledgeForAReward
    ) internal returns (Vm.Log[] memory logs, uint256 tokenId, bytes32[] memory rewards) {
        vm.startPrank(caller);
        vm.recordLogs();

        // Approve tokens from admin (caller) since admin will be the token source
        if (isPledgeForAReward) {
            // Calculate total pledge amount from rewards
            uint256 totalPledgeAmount = 0;
            for (uint256 i = 0; i < reward.length; i++) {
                totalPledgeAmount += KeepWhatsRaised(treasury).getReward(reward[i]).rewardValue;
            }
            testToken.approve(treasury, totalPledgeAmount + tip);
        } else {
            testToken.approve(treasury, pledgeAmount + tip);
        }

        KeepWhatsRaised(treasury).setFeeAndPledge(
            pledgeId, backer, address(testToken), pledgeAmount, tip, fee, reward, isPledgeForAReward
        );

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])", treasury);

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, tip, tokenId, rewards
        (,,, tokenId, rewards) = abi.decode(data, (bytes32, uint256, uint256, uint256, bytes32[]));

        vm.stopPrank();
    }

    /**
     * @notice Implements pledgeForAReward helper function with tip.
     */
    function pledgeForAReward(
        address caller,
        address token,
        address keepWhatsRaisedAddress,
        bytes32 pledgeId,
        uint256 pledgeAmount,
        uint256 tip,
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

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(caller, address(token), pledgeId, tip, reward, 0, block.timestamp + 1 hours);

        KeepWhatsRaised(keepWhatsRaisedAddress).pledgeForAReward(pledgeId, caller, token, tip, reward, permitData);

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs, "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])", keepWhatsRaisedAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, tip, tokenId, rewards
        (,,, tokenId, rewards) = abi.decode(data, (bytes32, uint256, uint256, uint256, bytes32[]));

        vm.stopPrank();
    }

    /**
     * @notice Implements pledgeWithoutAReward helper function with tip.
     */
    function pledgeWithoutAReward(
        address caller,
        address token,
        address keepWhatsRaisedAddress,
        bytes32 pledgeId,
        uint256 pledgeAmount,
        uint256 tip,
        uint256 launchTime
    ) internal returns (Vm.Log[] memory logs, uint256 tokenId) {
        vm.startPrank(caller);
        vm.recordLogs();

        // Approve MockPermit2 (at canonical address) instead of the treasury directly.
        IERC20(token).approve(CANONICAL_PERMIT2_ADDRESS, type(uint256).max);
        vm.warp(launchTime);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(caller, address(token), pledgeId, pledgeAmount, tip, 0, block.timestamp + 1 hours);

        KeepWhatsRaised(keepWhatsRaisedAddress).pledgeWithoutAReward(pledgeId, caller, token, pledgeAmount, tip, permitData);

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs, "Receipt(address,address,bytes32,uint256,uint256,uint256,bytes32[])", keepWhatsRaisedAddress
        );

        // Indexed params: backer (topics[1]), pledgeToken (topics[2])
        // Data params: reward, pledgeAmount, tip, tokenId, rewards
        (,,, tokenId,) = abi.decode(data, (bytes32, uint256, uint256, uint256, bytes32[]));
        vm.stopPrank();
    }

    /**
     * @notice Implements withdraw helper function with amount parameter.
     */
    function withdraw(address caller, address keepWhatsRaisedAddress, uint256 amount, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, address to, uint256 withdrawalAmount, uint256 fee)
    {
        vm.warp(warpTime);
        vm.startPrank(caller);
        vm.recordLogs();

        KeepWhatsRaised(keepWhatsRaisedAddress).withdraw(address(testToken), amount);

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "WithdrawalWithFeeSuccessful(address,uint256,uint256)", keepWhatsRaisedAddress);

        to = address(uint160(uint256(topics[1])));

        (withdrawalAmount, fee) = abi.decode(data, (uint256, uint256));

        vm.stopPrank();
    }

    /**
     * @notice Implements claimRefund helper function.
     */
    function claimRefund(address caller, address keepWhatsRaisedAddress, uint256 tokenId)
        internal
        returns (Vm.Log[] memory logs, uint256 refundedTokenId, uint256 refundAmount, address claimer)
    {
        vm.startPrank(caller);

        // Approve treasury to burn NFT
        CampaignInfo(campaignAddress).approve(keepWhatsRaisedAddress, tokenId);

        vm.recordLogs();

        KeepWhatsRaised(keepWhatsRaisedAddress).claimRefund(tokenId);

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "RefundClaimed(uint256,uint256,address)", keepWhatsRaisedAddress);

        refundedTokenId = uint256(topics[1]);
        claimer = address(uint160(uint256(topics[2])));

        refundAmount = abi.decode(data, (uint256));

        vm.stopPrank();
    }

    /**
     * @notice Implements claimTip helper function.
     */
    function claimTip(address caller, address keepWhatsRaisedAddress, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, uint256 amount, address claimer)
    {
        vm.warp(warpTime);
        vm.startPrank(caller);
        vm.recordLogs();

        KeepWhatsRaised(keepWhatsRaisedAddress).claimTip();

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "TipClaimed(uint256,address)", keepWhatsRaisedAddress);

        claimer = address(uint160(uint256(topics[1])));
        amount = abi.decode(data, (uint256));

        vm.stopPrank();
    }

    /**
     * @notice Implements claimFund helper function.
     */
    function claimFund(address caller, address keepWhatsRaisedAddress, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, uint256 amount, address claimer)
    {
        vm.warp(warpTime);
        vm.startPrank(caller);
        vm.recordLogs();

        KeepWhatsRaised(keepWhatsRaisedAddress).claimFund();

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "FundClaimed(uint256,address)", keepWhatsRaisedAddress);

        claimer = address(uint160(uint256(topics[1])));

        amount = abi.decode(data, (uint256));

        vm.stopPrank();
    }

    /**
     * @notice Implements disburseFees helper function.
     */
    function disburseFees(address keepWhatsRaisedAddress, uint256 warpTime)
        internal
        returns (Vm.Log[] memory logs, uint256 protocolShare, uint256 platformShare)
    {
        vm.warp(warpTime);
        vm.recordLogs();

        KeepWhatsRaised(keepWhatsRaisedAddress).disburseFees();

        logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "FeesDisbursed(address,uint256,uint256)", keepWhatsRaisedAddress);

        // topics[1] is the indexed token
        (protocolShare, platformShare) = abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Helper to cancel treasury.
     */
    function cancelTreasury(address caller, address treasury, bytes32 message) internal {
        vm.startPrank(caller);
        KeepWhatsRaised(treasury).cancelTreasury(message);
        vm.stopPrank();
    }

    function _buildSignedKeepWhatsRaisedRewardPermitData(
        address backer,
        address token,
        bytes32 pledgeId,
        uint256 tip,
        bytes32[] memory rewardSelection,
        uint256 nonce,
        uint256 deadline
    ) internal returns (PermitData memory) {
        uint256 pledgeAmount;
        for (uint256 i = 0; i < rewardSelection.length; i++) {
            pledgeAmount += keepWhatsRaised.getReward(rewardSelection[i]).rewardValue;
        }

        uint256 totalAmount = _denormalizeForToken(token, pledgeAmount) + tip;
        bytes32 rewardsHash = keccak256(abi.encodePacked(rewardSelection));
        bytes32 witness = keccak256(
            abi.encode(KWR_PLEDGE_FOR_REWARD_WITNESS_TYPEHASH, pledgeId, backer, rewardsHash, tip)
        );

        return _buildSignedPermitData(
            backer, treasuryAddress, token, totalAmount, witness, KWR_PLEDGE_FOR_REWARD_WITNESS_TYPE_STRING, nonce, deadline
        );
    }

    function _buildSignedKeepWhatsRaisedNoRewardPermitData(
        address backer,
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
            treasuryAddress,
            token,
            pledgeAmount + tip,
            witness,
            KWR_PLEDGE_WITHOUT_REWARD_WITNESS_TYPE_STRING,
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

    /**
     * @notice Deploys a fresh campaign and unconfigured KeepWhatsRaised treasury,
     *         reassigning campaignAddress, treasuryAddress, and keepWhatsRaised.
     *         Use this in tests that need to call configureTreasury for the first time.
     */
    function _resetTreasury() internal {
        _resetCounter++;
        bytes32 newIdentifierHash = keccak256(abi.encodePacked("resetTreasury", _resetCounter));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = PLATFORM_2_HASH;
        bytes32[] memory emptyArray = new bytes32[](0);

        vm.prank(users.creator1Address);
        campaignInfoFactory.createCampaign(
            users.creator1Address,
            newIdentifierHash,
            selectedPlatformHash,
            emptyArray,
            emptyArray,
            CAMPAIGN_DATA,
            "Fresh Treasury NFT",
            "FRESH",
            "ipfs://QmFresh",
            "ipfs://QmFreshContract"
        );

        address newCampaignAddress = campaignInfoFactory.identifierToCampaignInfo(newIdentifierHash);

        vm.prank(users.platform2AdminAddress);
        address newTreasury = treasuryFactory.deploy(PLATFORM_2_HASH, newCampaignAddress, 1);

        campaignAddress = newCampaignAddress;
        treasuryAddress = newTreasury;
        keepWhatsRaised = KeepWhatsRaised(newTreasury);
    }
}
