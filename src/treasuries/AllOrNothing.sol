// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "../utils/Counters.sol";
import "../utils/TimestampChecker.sol";
import "../utils/BaseTreasury.sol";
import "../interfaces/IReward.sol";

/**
 * @title AllOrNothing
 * @notice A contract for handling crowdfunding campaigns with rewards.
 */
contract AllOrNothing is
    IReward,
    BaseTreasury,
    TimestampChecker,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    // Mapping to store the pledged amount per token ID
    mapping(uint256 => uint256) private s_tokenToCollectedAmount;

    // Mapping to store reward details by name
    mapping(bytes32 => Reward) private s_reward;

    // Counters for token IDs and rewards
    Counters.Counter private s_tokenIdCounter;
    Counters.Counter private s_rewardCounter;

    string private s_name;
    string private s_symbol;

    /**
     * @dev Emitted when a backer makes a pledge.
     * @param backer The address of the backer making the pledge.
     * @param reward The name of the reward.
     * @param pledgeAmount The amount pledged.
     * @param tokenId The ID of the token representing the pledge.
     * @param rewards An array of reward names.
     */
    event Receipt(
        address indexed backer,
        bytes32 indexed reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
        uint256 tokenId,
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
     * @dev Emitted when `disburseFees` after fee is disbursed already.
     */
    error AllOrNothingFeeAlreadyDisbursed();
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
            revert AllOrNothingInvalidInput();
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
     * @notice Adds a reward to the campaign.
     * @param rewardName The name of the reward.
     * @param reward The details of the reward as a `Reward` struct.
     */
    function addReward(
        bytes32 rewardName,
        Reward calldata reward
    )
        external
        onlyCampaignOwner
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
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
     * @notice Adds multiple rewards in a batch.
     * @param rewardNames An array of reward names.
     * @param rewards An array of `Reward` structs containing reward details.
     */
    function addRewardsBatch(
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
     * @param backer The address of the backer making the pledge.
     * @param reward An array of reward names.
     */
    function pledgeForAReward(
        address backer,
        uint256 shippingFee,
        bytes32[] calldata reward
    )
        external
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
        whenCampaignNotCancelled
        whenNotCancelled
    {
        uint256 tokenId = s_tokenIdCounter.current();
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
        _pledge(backer, reward[0], pledgeAmount, shippingFee, tokenId, reward);
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
        whenCampaignNotCancelled
        whenNotCancelled
    {
        uint256 tokenId = s_tokenIdCounter.current();
        bytes32[] memory emptyByteArray = new bytes32[](0);

        _pledge(backer, ZERO_BYTES, pledgeAmount, 0, tokenId, emptyByteArray);
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
        if (block.timestamp >= INFO.getDeadline()) {
            if (_checkSuccessCondition()) {
                revert AllOrNothingNotClaimable(tokenId);
            }
        }
        uint256 amount = s_tokenToCollectedAmount[tokenId];
        if (amount == 0) {
            revert AllOrNothingNotClaimable(tokenId);
        }
        s_tokenToCollectedAmount[tokenId] = 0;
        s_pledgedAmount -= amount;
        burn(tokenId);
        TOKEN.safeTransfer(msg.sender, amount);
        emit RefundClaimed(tokenId, amount, msg.sender);
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
            msg.sender != INFO.getPlatformAdminAddress(PLATFORM_HASH) &&
            msg.sender != INFO.owner()
        ) {
            revert AllOrNothingUnAuthorized();
        }
        _cancel(message);
    }

    function _pledge(
        address backer,
        bytes32 reward,
        uint256 pledgeAmount,
        uint256 shippingFee,
        uint256 tokenId,
        bytes32[] memory rewards
    ) internal {
        uint256 totalAmount = pledgeAmount + shippingFee;
        TOKEN.safeTransferFrom(backer, address(this), totalAmount);
        s_tokenIdCounter.increment();
        _safeMint(backer, tokenId, abi.encodePacked(backer, reward));
        s_tokenToCollectedAmount[tokenId] = totalAmount;
        s_pledgedAmount += pledgeAmount;
        emit Receipt(
            backer,
            reward,
            pledgeAmount,
            shippingFee,
            tokenId,
            rewards
        );
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
