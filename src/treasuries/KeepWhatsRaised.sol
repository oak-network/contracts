// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "../utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BaseTreasury.sol";
import "../interfaces/IReward.sol";

/**
 * @title KeepWhatsRaised
 * @notice A contract that keeps all the funds raised, regardless of the success condition.
 */
abstract contract KeepWhatsRaised is
    IReward,
    BaseTreasury,
    TimestampChecker,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;

    // Counters for token IDs and rewards
    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

    string private s_name;
    string private s_symbol;

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
     * @dev Emitted when an unauthorized action is attempted.
     */
    error KeepWhatsRaisedUnAuthorized();

    /**
     * @dev Emitted when an invalid input is detected.
     */
    error KeepWhatsRaisedInvalidInput();

    /**
     * @dev Emitted when a `Reward` already exists for given input.
     */
    error KeepWhatsRaisedRewardExists();

    /**
     * @dev Constructor for the KeepWhatsRaised contract.
     */
    constructor() ERC721("", "") {}

    function initialize(
        bytes32 _platformHash,
        address _infoAddress,
        string calldata _name,
        string calldata _symbol
    ) external initializer {
        __BaseContract_init(_platformHash, _infoAddress);
        s_name = _name;
        s_symbol = _symbol;
    }

    function name() public view override returns (string memory) {
        return s_name;
    }

    function symbol() public view override returns (string memory) {
        return s_symbol;
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
            revert KeepWhatsRaisedInvalidInput();
        }
        return s_reward[rewardName];
    }

    /**
     * @inheritdoc ICampaignTreasury
     */
    function getRaisedAmount() external view override returns (uint256) {
        return s_pledgedAmount;
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
            revert KeepWhatsRaisedInvalidInput();
        }

        for (uint256 i = 0; i < rewardNames.length; i++) {
            bytes32 rewardName = rewardNames[i];
            Reward calldata reward = rewards[i];

            // Reward name must not be zero bytes and reward value must be non-zero
            if (rewardName == ZERO_BYTES || reward.rewardValue == 0) {
                revert KeepWhatsRaisedInvalidInput();
            }

            // If there are any items, their arrays must match in length
            if (
                (reward.itemId.length != reward.itemValue.length) ||
                (reward.itemId.length != reward.itemQuantity.length)
            ) {
                revert KeepWhatsRaisedInvalidInput();
            }

            // Check for duplicate reward
            if (s_reward[rewardName].rewardValue != 0) {
                revert KeepWhatsRaisedRewardExists();
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
            revert KeepWhatsRaisedInvalidInput();
        }
        delete s_reward[rewardName];
        s_rewardCounter.decrement();
        emit RewardRemoved(rewardName);
    }

    /**
     * @inheritdoc BaseTreasury
     * @dev This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.
     */
    function cancelTreasury(bytes32 message) public override {
        if (
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            msg.sender != INFO.owner()
        ) {
            revert KeepWhatsRaisedUnAuthorized();
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

    // The following functions are overrides required by Solidity.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
