// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Counters} from "../utils/Counters.sol";
import {TimestampChecker} from "../utils/TimestampChecker.sol";
import {ICampaignTreasury} from "../interfaces/ICampaignTreasury.sol";
import {ICampaignInfo} from "../interfaces/ICampaignInfo.sol";
import {BaseTreasury} from "../utils/BaseTreasury.sol";
import {IReward} from "../interfaces/IReward.sol";

/**
 * @title AllOrNothing
 * @notice A contract for handling crowdfunding campaigns with rewards.
 */
contract AllOrNothing is
    IReward,
    BaseTreasury,
    TimestampChecker,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store the total collected amount (pledged amount and shipping fee) per token ID
    mapping(uint256 => uint256) private s_tokenToTotalCollectedAmount;
    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;
    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;
    // Mapping to store the token used for each pledge
    mapping(uint256 => address) private s_tokenIdToPledgeToken; 

    // Counter for reward tiers
    Counters.Counter private s_rewardCounter;

    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeToken The token used for the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tokenId The ID of the token representing the pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        address indexed pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
        uint256 tokenId,
        bytes32[] rewards
    );

    /**
     * @dev Emitted when rewards are added to the campaign.
     * @param rewardNames The names of the rewards.
     * @param rewards The details of the rewards.
     */
    event RewardsAdded(bytes32[] rewardNames, Reward[] rewards);

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
     * @dev Emitted when `disburseFees` after fee is disbursed already.
     */
    error AllOrNothingFeeAlreadyDisbursed();
    /**
     * @dev Emitted when a `Reward` already exists for given input.
     */
    error AllOrNothingRewardExists();

    /**
     * @dev Emitted when a token is not accepted for the campaign.
     */
    error AllOrNothingTokenNotAccepted(address token);

    /**
     * @dev Emitted when claiming an unclaimable refund.
     * @param tokenId The ID of the token representing the pledge.
     */
    error AllOrNothingNotClaimable(uint256 tokenId);

    /**
     * @dev Constructor for the AllOrNothing contract.
     */
    constructor() {}

    function initialize(
        bytes32 _platformHash,
        address _infoAddress
    ) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
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
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_tokenRaisedAmounts[token];
            if (amount > 0) {
                totalNormalized += _normalizeAmount(token, amount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getLifetimeRaisedAmount() external view override returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 amount = s_tokenLifetimeRaisedAmounts[token];
            if (amount > 0) {
                totalNormalized += _normalizeAmount(token, amount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getRefundedAmount() external view override returns (uint256) {
        address[] memory acceptedTokens = INFO.getAcceptedTokens();
        uint256 totalNormalized = 0;
        
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 lifetimeAmount = s_tokenLifetimeRaisedAmounts[token];
            uint256 currentAmount = s_tokenRaisedAmounts[token];
            uint256 refundedAmount = lifetimeAmount - currentAmount;
            if (refundedAmount > 0) {
                totalNormalized += _normalizeAmount(token, refundedAmount);
            }
        }
        
        return totalNormalized;
    }

    /**
     * @notice Adds multiple rewards in a batch.
     * @dev This function allows for both reward tiers and non-reward tiers.
     *      For both types, rewards must have non-zero value.
     *      If items are specified (non-empty arrays), the itemId, itemValue, and itemQuantity arrays must match in length.
     *      Empty arrays are allowed for both reward tiers and non-reward tiers.
     * @param rewardNames An array of reward names.
     * @param rewards An array of `Reward` structs containing reward details.
     */
    function addRewards(
        bytes32[] calldata rewardNames,
        Reward[] calldata rewards
    )
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (rewardNames.length != rewards.length) {
            revert AllOrNothingInvalidInput();
        }

        for (uint256 i = 0; i < rewardNames.length; i++) {
            bytes32 rewardName = rewardNames[i];
            Reward calldata reward = rewards[i];

            // Reward name must not be zero bytes and reward value must be non-zero
            if (rewardName == ZERO_BYTES || reward.rewardValue == 0) {
                revert AllOrNothingInvalidInput();
            }

            // If there are any items, their arrays must match in length
            if (
                (reward.itemId.length != reward.itemValue.length) ||
                (reward.itemId.length != reward.itemQuantity.length)
            ) {
                revert AllOrNothingInvalidInput();
            }

            // Check for duplicate reward
            if (s_reward[rewardName].rewardValue != 0) {
                revert AllOrNothingRewardExists();
            }

            s_reward[rewardName] = reward;
            s_rewardCounter.increment();
        }
        emit RewardsAdded(rewardNames, rewards);
    }

    /**
     * @notice Removes a reward from the campaign.
     * @param rewardName The name of the reward.
     */
    function removeReward(
        bytes32 rewardName
    )
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        if (s_reward[rewardName].rewardValue == 0) {
            revert AllOrNothingInvalidInput();
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Allows a backer to pledge for a reward.
     * @dev The first element of the `reward` array must be a reward tier and the other elements can be either reward tiers or non-reward tiers.
     *      The non-reward tiers cannot be pledged for without a reward.
     * @param backer The address of the backer making the pledge.
     * @param pledgeToken The token address to use for the pledge.
     * @param shippingFee The shipping fee amount.
     * @param reward An array of reward names.
     */
    function pledgeForAReward(
        address backer,
        address pledgeToken,
        uint256 shippingFee,
        bytes32[] calldata reward
    )
        external
        nonReentrant
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
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
            tempReward = s_reward[reward[i]];
            if (tempReward.rewardValue == 0) {
                revert AllOrNothingInvalidInput();
            }
            pledgeAmount += tempReward.rewardValue;
        }
        _pledge(backer, pledgeToken, reward[0], pledgeAmount, shippingFee, reward);
    }

    /**
     * @notice Allows a backer to pledge without selecting a reward.
     * @param backer The address of the backer making the pledge.
     * @param pledgeToken The token address to use for the pledge.
     * @param pledgeAmount The amount of the pledge.
     */
    function pledgeWithoutAReward(
        address backer,
        address pledgeToken,
        uint256 pledgeAmount
    )
        external
        nonReentrant
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(backer, pledgeToken, ZERO_BYTES, pledgeAmount, 0, emptyByteArray);
    }

    /**
     * @notice Allows a backer to claim a refund.
     * @param tokenId The ID of the token representing the pledge.
     */
    function claimRefund(
        uint256 tokenId
    )
        external
        currentTimeIsGreater(INFO.getLaunchTime())
        whenCampaignNotPaused
        whenNotPaused
    {
        if (block.timestamp >= INFO.getDeadline() && _checkSuccessCondition()) {
            revert AllOrNothingNotClaimable(tokenId);
        }
        
        // Get NFT owner before burning
        address nftOwner = INFO.ownerOf(tokenId);
        
        uint256 amountToRefund = s_tokenToTotalCollectedAmount[tokenId];
        uint256 pledgedAmount = s_tokenToPledgedAmount[tokenId];
        address pledgeToken = s_tokenIdToPledgeToken[tokenId];
        
        if (amountToRefund == 0) {
            revert AllOrNothingNotClaimable(tokenId);
        }
        
        s_tokenToTotalCollectedAmount[tokenId] = 0;
        s_tokenToPledgedAmount[tokenId] = 0;
        s_tokenRaisedAmounts[pledgeToken] -= pledgedAmount;
        delete s_tokenIdToPledgeToken[tokenId];
        
        // Burn the NFT (requires treasury approval from owner)
        INFO.burn(tokenId);
        
        IERC20(pledgeToken).safeTransfer(nftOwner, amountToRefund);
        emit RefundClaimed(tokenId, amountToRefund, nftOwner);
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function disburseFees()
        public
        override
        currentTimeIsGreater(INFO.getDeadline())
        whenNotPaused
        whenNotCancelled
    {
        if (s_feesDisbursed) {
            revert AllOrNothingFeeAlreadyDisbursed();
        }
        super.disburseFees();
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function withdraw() public override whenNotPaused whenNotCancelled {
        super.withdraw();
    }

    /**
     * @inheritdoc BaseTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (
            _msgSender() != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            _msgSender() != INFO.owner()
        ) {
            revert AllOrNothingUnAuthorized();
        }
        _cancel(message);
    }

    /**
     * @inheritdoc BaseTreasury
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

    function _pledge(
        address backer,
        address pledgeToken,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
        bytes32[] memory rewards
    ) private {
        // Validate token is accepted 
        if (!INFO.isTokenAccepted(pledgeToken)) {
            revert AllOrNothingTokenNotAccepted(pledgeToken);
        }
        
        // If this is for a reward, pledgeAmount and shippingFee are in 18 decimals
        // If not for a reward, amounts are already in token decimals
        uint256 pledgeAmountInTokenDecimals;
        uint256 shippingFeeInTokenDecimals;
        
        if (reward != ZERO_BYTES) {
            // Reward pledge: denormalize from 18 decimals to token decimals
            pledgeAmountInTokenDecimals = _denormalizeAmount(pledgeToken, pledgeAmount);
            shippingFeeInTokenDecimals = _denormalizeAmount(pledgeToken, shippingFee);
        } else {
            // Non-reward pledge: already in token decimals
            pledgeAmountInTokenDecimals = pledgeAmount;
            shippingFeeInTokenDecimals = shippingFee;
        }
        
        uint256 totalAmount = pledgeAmountInTokenDecimals + shippingFeeInTokenDecimals;
        
        IERC20(pledgeToken).safeTransferFrom(backer, address(this), totalAmount);
        
        s_tokenRaisedAmounts[pledgeToken] += pledgeAmountInTokenDecimals;
        
        uint256 tokenId = INFO.mintNFTForPledge(
            backer,
            reward,
            pledgeToken,
            pledgeAmountInTokenDecimals,
            shippingFeeInTokenDecimals,
            0
        );
        
        s_tokenToPledgedAmount[tokenId] = pledgeAmountInTokenDecimals;
        s_tokenToTotalCollectedAmount[tokenId] = totalAmount;
        s_tokenIdToPledgeToken[tokenId] = pledgeToken;
        s_tokenRaisedAmounts[pledgeToken] += pledgeAmountInTokenDecimals;
        s_tokenLifetimeRaisedAmounts[pledgeToken] += pledgeAmountInTokenDecimals;
        
        emit Receipt(
            backer,
            pledgeToken,
            reward,
            pledgeAmount,
            shippingFee,
            tokenId,
            rewards
        );
    }

}
