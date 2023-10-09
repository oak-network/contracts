// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BaseTreasury.sol";
import "../utils/FiatEnabled.sol";

/**
 * @title AllOrNothing
 * @notice A contract for handling crowdfunding campaigns with rewards.
 */
contract AllOrNothing is
    BaseTreasury,
    TimestampChecker,
    FiatEnabled,
    ERC721Burnable
{
    using Counters for Counters.Counter;

    // Struct to represent a reward
    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    // Constant for the pre-launch pledge amount
    uint256 private constant PRELAUNCH_PLEDGE = 1 ether;

    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;

    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;

    // Counters for token IDs and rewards
    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tokenId The ID of the token representing the pledge.
     * @param isPreLaunchPledge Indicates whether it's a pre-launch pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId,
        bool isPreLaunchPledge,
        bytes32[] rewards
    );

    /**
     * @dev Emitted when a reward is added to the campaign.
     * @param rewardName The name of the reward.
     * @param reward The details of the reward.
     */
    event RewardAdded(bytes32 indexed rewardName, Reward reward);

    /**
     * @dev Emitted when a reward is removed from the campaign.
     * @param rewardName The name of the reward.
     */
    event RewardRemoved(bytes32 indexed rewardName);

    /**
     * @dev Emitted when a refund is claimed.
     * @param tokenId The ID of the token representing the pledge.
     * @param refundAmount The refund amount claimed.
     * @param claimer The address of the claimer.
     */
    event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);

    /**
     * @dev Emitted when an unauthorized action is attempted.
     */
    error AllOrNothingUnAuthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     */
    error AllOrNothingInvalidInput();

    /**
     * @dev Emitted when a token transfer fails.
     */
    error AllOrNothingTransferFailed();

    /**
     * @dev Emitted when the campaign is not successful.
     */
    error AllOrNothingNotSuccessful();

    /**
     * @dev Emitted when fees are not disbursed.
     */
    error AllOrNothingFeeNotDisbursed();
    /**
     * @dev Emitted when a `Reward` already exists for given input. 
     */
    error AllOrNothingRewardExists();

    /**
     * @dev Emitted when claiming an unclaimable refund.
     * @param tokenId The ID of the token representing the pledge.
     */
    error AllOrNothingNotClaimable(uint256 tokenId);

    /**
     * @dev Constructor for the AllOrNothing contract.
     * @param platformBytes The unique identifier of the platform.
     * @param infoAddress The address of the campaign information contract.
     */
    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) ERC721("", "") BaseTreasury(platformBytes, infoAddress) {
        s_tokenIdCounter.increment();
    }

    /**
     * @notice Retrieves the details of a reward.
     * @param rewardName The name of the reward.
     * @return reward The details of the reward as a `Reward` struct.
     */
    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory reward) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput();
        }
        return s_reward[rewardName];
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getRaisedAmount() external view override returns (uint256) {
        return s_fiatRaisedAmount + s_pledgedAmountInCrypto;
    }

    /**
     * @notice Adds a reward to the campaign.
     * @param rewardName The name of the reward.
     * @param reward The details of the reward as a `Reward` struct.
     */
    function addReward(
        bytes32 rewardName,
        Reward calldata reward
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        if (
            reward.rewardValue == 0 &&
            reward.itemId.length == 0 &&
            reward.itemId.length == reward.itemValue.length &&
            reward.itemId.length == reward.itemQuantity.length
        ) {
            revert AllOrNothingInvalidInput();
        }
        if (s_reward[rewardName].rewardValue != 0) {
            revert AllOrNothingRewardExists();
        }
        s_reward[rewardName] = reward;
        s_rewardCounter.increment();
        emit RewardAdded(rewardName, reward);
    }

    /**
     * @notice Removes a reward from the campaign.
     * @param rewardName The name of the reward.
     */
    function removeReward(
        bytes32 rewardName
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput();
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Updates the fiat pledge transaction.
     * @param fiatPledgeId The unique identifier of the fiat pledge.
     * @param fiatPledgeAmount The amount of the fiat pledge.
     */
    function updateFiatPledge(
        bytes32 fiatPledgeId,
        uint256 fiatPledgeAmount
    )
        external
        onlyPlatformAdmin(PLATFORM_BYTES)
        whenCampaignNotPaused
        whenNotPaused
    {
        _updateFiatTransaction(fiatPledgeId, fiatPledgeAmount);
    }

    /**
     * @notice Updates the state of fiat fee disbursement.
     * @param isDisbursed Whether fiat fees are disbursed.
     * @param protocolFeeAmount The protocol fee amount.
     * @param platformFeeAmount The platform fee amount.
     */
    function updateFiatFeeDisbursementState(
        bool isDisbursed,
        uint256 protocolFeeAmount,
        uint256 platformFeeAmount
    )
        external
        onlyPlatformAdmin(PLATFORM_BYTES)
        whenCampaignNotPaused
        whenNotPaused
    {
        _updateFiatFeeDisbursementState(
            isDisbursed,
            protocolFeeAmount,
            platformFeeAmount
        );
    }

    /**
     * @notice Allows a backer to make a pre-launch pledge.
     * @param backer The address of the backer making the pledge.
     */
    function pledgeOnPreLaunch(
        address backer
    )
        external
        currentTimeIsGreater(INFO.getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
    {
        uint256 prelaunchPledgeAmount = PRELAUNCH_PLEDGE;
        bool success = TOKEN.transferFrom(
            backer,
            address(this),
            prelaunchPledgeAmount
        );
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
        uint256 tokenId = s_tokenIdCounter.current();
        s_tokenIdCounter.increment();
        _safeMint(
            backer,
            tokenId,
            abi.encodePacked(backer, " PreLaunchPledge")
        );
        s_pledgedAmountInCrypto += prelaunchPledgeAmount;
        bytes32[] memory emptyByteArray = new bytes32[](0);
        emit Receipt(
            backer,
            ZERO_BYTES,
            prelaunchPledgeAmount,
            tokenId,
            true,
            emptyByteArray
        );
    }

    /**
     * @notice Allows a backer to pledge for a reward.
     * @param backer The address of the backer making the pledge.
     * @param reward An array of reward names.
     */
    function pledgeForAReward(
        address backer,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        uint256 tokenId = s_tokenIdCounter.current();
        bool success;
        uint256 rewardLen = reward.length;
        Reward storage tempReward = s_reward[reward[0]];
        if (
            backer == address(0) ||
            rewardLen > s_rewardCounter.current() ||
            reward[0] == ZERO_BYTES ||
            !tempReward.isRewardTier
        ) {
            revert AllOrNothingInvalidInput();
        }
        uint256 pledgeAmount = tempReward.rewardValue;
        for (uint256 i = 1; i < rewardLen; i++) {
            if (reward[i] == ZERO_BYTES) {
                revert AllOrNothingInvalidInput();
            }
            pledgeAmount += s_reward[reward[i]].rewardValue;
        }
        success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_tokenIdCounter.increment();
            _safeMint(
                backer,
                tokenId,
                abi.encodePacked(backer, " ", reward[0])
            );
            s_tokenToPledgedAmount[tokenId] = pledgeAmount;
            s_pledgedAmountInCrypto += pledgeAmount;
            emit Receipt(
                backer,
                reward[0],
                pledgeAmount,
                tokenId,
                false,
                reward
            );
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     */
    function pledgeWithoutAReward(
        address backer,
        uint256 pledgeAmount
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        bool success = TOKEN.transferFrom(backer, address(this), pledgeAmount);
        if (success) {
            s_pledgedAmountInCrypto += pledgeAmount;
            bytes32[] memory emptyByteArray = new bytes32[](0);
            emit Receipt(
                backer,
                ZERO_BYTES,
                pledgeAmount,
                0,
                false,
                emptyByteArray
            );
        } else {
            revert AllOrNothingTransferFailed();
        }
    }

    /**
     * @notice Allows a backer to claim a refund.
     * @param tokenId The ID of the token representing the pledge.
     */
    function claimRefund(
        uint256 tokenId
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        if (amount == 0) {
            revert AllOrNothingNotClaimable(tokenId);
        }
        s_tokenToPledgedAmount[tokenId] = 0;
        s_pledgedAmountInCrypto -= amount;
        burn(tokenId);
        bool success = TOKEN.transfer(msg.sender, amount);
        if (!success) {
            revert AllOrNothingTransferFailed();
        }
        emit RefundClaimed(tokenId, amount, msg.sender);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function disburseFees() public override currentTimeIsGreater(INFO.getDeadline()) {
        if (!s_cryptoFeeDisbursed) {
            super.disburseFees();
        }
    }

    /**
     * @dev Checks if the caller is the platform admin.
     */
    function _checkIfPlatformAdmin() internal view {
        if (msg.sender != INFO.getPlatformAdminAddress(PLATFORM_BYTES)) {
            revert AllOrNothingUnAuthorized();
        }
    }

    /**
     * @dev Checks if the success condition for the campaign is met.
     * @return True if the campaign is successful; otherwise, false.
     */
    function _checkSuccessCondition()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return INFO.getTotalRaisedAmount() >= INFO.getGoalAmount();
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}