// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ICampaignInfo.sol";
import "../utils/BaseTreasury.sol";
import "../utils/TimestampChecker.sol";

/**
 * @title MinimumOrder
 * @notice A Solidity contract for managing minimum order-based campaigns.
 * Users can pre-order items or rewards, and when a predefined success metric is reached,
 * the campaign succeeds, and backers receive their rewards.
 */
contract MinimumOrder is BaseTreasury, ERC721Burnable, TimestampChecker {
    using Counters for Counters.Counter;

    // Struct to define a reward
    struct Reward {
        uint256 rewardValue;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }

    // Immutable variable to store the success metric
    uint256 internal immutable SUCCESS_METRIC;

    uint256 private s_preOrderValueAmount;
    uint256 private s_platformFeePercent;

    // Mapping to store pledged amounts for tokens
    mapping(uint256 => uint256) private s_tokenToPledgedAmount;

    // Mapping to store rewards
    mapping(bytes32 => Reward) private s_reward;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter internal s_numberOfPreOrders;

    /**
     * @dev Event emitted when a backer makes a pledge.
     * @param backer The address of the backer.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged by the backer.
     * @param tokenId The unique token ID associated with the pledge.
     */
    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 tokenId
    );

    /**
     * @dev Event emitted when a reward is added to the campaign.
     * @param rewardName The name of the reward.
     * @param reward The reward details including value, item IDs, values, and quantities.
     */
    event RewardAdded(bytes32 indexed rewardName, Reward reward);

    /**
     * @dev Event emitted when a reward is removed from the campaign.
     * @param rewardName The name of the reward.
     */
    event RewardRemoved(bytes32 indexed rewardName);

    /**
     * @dev Event emitted when a refund is claimed by a backer.
     * @param tokenId The unique token ID associated with the refund.
     * @param refundAmount The amount refunded to the backer.
     * @param claimer The address of the backer who claimed the refund.
     */
    event RefundClaimed(uint256 tokenId, uint256 refundAmount, address claimer);

    /**
     * @dev Throws an error indicating that the pre-order transfer failed.
     */
    error PreOrderTransferFailed();

    /**
     * @dev Throws an error indicating that the pre-order input is invalid.
     */
    error PreOrderInvalidInput();

    /**
     * @dev Constructor for the MinimumOrder contract.
     * @param platformBytes The unique identifier of the platform.
     * @param infoAddress The address of the CampaignInfo contract providing campaign details.
     */
    constructor(
        bytes32 platformBytes,
        address infoAddress
    )
        ERC721("", "") // Initialize the ERC721 token with empty name and symbol
        BaseTreasury(platformBytes, infoAddress)
    {
        // Initialize the SUCCESS_METRIC from global platform data
        SUCCESS_METRIC = uint256(
            INFO.getPlatformData(
                /// bytes32 of `PreOrder0MinimumOrder(uint256)`
                0x5072654f72646572304d696e696d756d4f726465722875696e74323536290000
            )
        );
    }

    /**
     * @notice Function to get the number of pre-orders made.
     * @return The number of pre-orders.
     */
    function getNumberOfOrders() internal view returns (uint256) {
        return s_numberOfPreOrders.current();
    }

    /**
     * @notice Function to get reward details by name.
     * @param rewardName The name of the reward.
     * @return The reward details, including value, item IDs, values, and quantities.
     */
    function getReward(
        bytes32 rewardName
    ) external view returns (Reward memory) {
        if (s_reward[rewardName].rewardValue == 0) {
            revert PreOrderInvalidInput();
        }
        return s_reward[rewardName];
    }

    /**
     * @notice Function to get the total raised amount during the campaign.
     * @return The total raised amount.
     */
    function getRaisedAmount() external view returns (uint256) {
        return s_preOrderValueAmount;
    }

    /**
     * @notice Function to add a new reward to the campaign.
     * Only the campaign owner can add rewards.
     * @param rewardName The name of the reward.
     * @param reward The reward details, including value, item IDs, values, and quantities.
     */
    function addReward(
        bytes32 rewardName,
        Reward calldata reward
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        Reward storage tempReward = s_reward[rewardName];
        if (
            tempReward.rewardValue != 0 &&
            tempReward.itemId.length > 0 &&
            tempReward.itemId.length == tempReward.itemValue.length &&
            tempReward.itemId.length == tempReward.itemQuantity.length
        ) {
            s_reward[rewardName] = reward;
            emit RewardAdded(rewardName, tempReward);
        } else {
            revert PreOrderInvalidInput();
        }
    }

    /**
     * @notice Function to remove a reward from the campaign.
     * Only the campaign owner can remove rewards.
     * @param rewardName The name of the reward to be removed.
     */
    function removeReward(
        bytes32 rewardName
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        uint256 tempRewardValue = s_reward[rewardName].rewardValue;
        if (tempRewardValue == 0) {
            revert PreOrderInvalidInput();
        }
        delete s_reward[rewardName];
        emit RewardRemoved(rewardName);
    }

    /**
     * @notice Function for backers to pre-order a reward.
     * The pre-order can only be made within the specified campaign timeframe.
     * @param backer The address of the backer making the pre-order.
     * @param rewardName The name of the reward to pre-order.
     */
    function preOrderForAReward(
        address backer,
        bytes32 rewardName
    )
        public
        virtual
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        uint256 tokenId = s_tokenIdCounter.current();
        uint256 rewardValue = s_reward[rewardName].rewardValue;
        bool success = TOKEN.transferFrom(backer, address(this), rewardValue);
        if (!success) {
            revert PreOrderTransferFailed();
        }
        s_tokenIdCounter.increment();
        _safeMint(backer, tokenId, abi.encodePacked(backer, " ", rewardName));
        s_preOrderValueAmount += rewardValue;
        s_tokenToPledgedAmount[tokenId] = rewardValue;
        s_numberOfPreOrders.increment();
        emit Receipt(backer, rewardName, rewardValue, tokenId);
    }

    /**
     * @notice Function for backers to claim a refund if the campaign has not met the success metric.
     * @param tokenId The unique token ID associated with the refund.
     */
    function claimRefund(
        uint256 tokenId
    ) external whenCampaignNotPaused whenNotPaused {
        uint256 amount = s_tokenToPledgedAmount[tokenId];
        s_tokenToPledgedAmount[tokenId] = 0;
        burn(tokenId);
        bool success = TOKEN.transfer(msg.sender, amount);
        emit RefundClaimed(tokenId, amount, msg.sender);
        if (!success) {
            revert PreOrderTransferFailed();
        }
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
        return (s_numberOfPreOrders.current() >= SUCCESS_METRIC);
    }

    /**
     * @notice Function to check if an address is supported by the ERC721 contract.
     * @param interfaceId The ERC721 interface ID to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
