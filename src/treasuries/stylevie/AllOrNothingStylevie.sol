// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../interfaces/ICampaignInfo.sol";
import "../../utils/BaseTreasury.sol";
import "../../utils/TimestampChecker.sol";

/**
 * @title MinimumOrder
 * @notice A Solidity contract for managing minimum order-based campaigns.
 * Users can pre-order items or rewards, and when a predefined success metric is reached,
 * the campaign succeeds, and backers receive their rewards.
 */
contract AllOrNothingStylevie is BaseTreasury, ERC721Burnable, TimestampChecker {
    using Counters for Counters.Counter;

    mapping(uint256 => uint256) private s_discountTiers;
    bool private isTotalOrderDiscount;
    bool private discountRuleSet;

    bytes32 private constant FUNDING_GOAL =
        0x2b7183f0b4f0ac8573e5967ca4300c369d135f68d864f0c38ccb8686567200fe;
    bytes32 private constant UNITS_GOAL =
        0xb5d766586a98b3528cc817c01bbf9821f4ab10f642a8d39ca9cc93d903042020;

    // Immutable variable to store the success metric
    bytes32 internal immutable SUCCESS_METRIC;

    uint256 private s_orderAmount;

    struct Item {
        bytes32 itemId;
        uint256 price;
        uint256 quantity;
        bool isLimited;
    }

    mapping(bytes32 => Item) activeItems;

    // Mapping to store order value for tokens
    mapping(uint256 => uint256) private s_tokenToOrderValue;

    Counters.Counter private s_tokenIdCounter;
    Counters.Counter internal s_orderCount;

    event Receipt(
        address indexed backer,
        uint256 orderValue,
        uint256 discountedValue,
        uint256 tokenId,
        bytes32[] itemId,
        uint256[] quantity
    );

    /**
     * @dev Event emitted when a reward is added to the campaign.
     * @param rewardName The name of the reward.
     * @param reward The reward details including value, item IDs, values, and quantities.
     */
    // event RewardAdded(bytes32 indexed rewardName, Reward reward);

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
    error OrderTransferFailed();

    /**
     * @dev Throws an error indicating that the input is invalid.
     */
    error InvalidInput();

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
        SUCCESS_METRIC = INFO.getPlatformData(
            /// keccak256 hash of `SUCCESS_METRIC`
            0x505b21d484708007a33b5d79afbe1f461e5696c598efd6e59f6a3112e1c11ed9
        );
    }

    /**
     * @notice Function to get the number of pre-orders made.
     * @return The number of pre-orders.
     */
    function getNumberOfOrders() internal view returns (uint256) {
        return s_orderCount.current();
    }


    /**
     * @notice Function to get the total raised amount during the campaign.
     * @return The total raised amount.
     */
    function getRaisedAmount() external view returns (uint256) {
        return s_orderAmount;
    }

    function addItems(
        Item[] calldata itemsInput
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        for (uint256 i = 0; i < itemsInput.length; i++) {
            Item calldata input = itemsInput[i];
            Item storage item = activeItems[input.itemId];
            item.price = input.price;
            item.quantity = input.quantity;
            item.isLimited = input.isLimited;
        }
    }

    function setDiscountTier(
        uint256 minOrderValue,
        uint256 discountPercent
    ) external onlyCampaignOwner whenCampaignNotPaused whenNotPaused {
        if (!discountRuleSet) {
            if (minOrderValue == 0) {
                isTotalOrderDiscount = true;
                s_discountTiers[0] = discountPercent;
            } else {
                s_discountTiers[minOrderValue] = discountPercent;
            }
            discountRuleSet = true;
        } else {
            if (isTotalOrderDiscount || minOrderValue == 0) {
                revert InvalidInput();
            } else {
                s_discountTiers[minOrderValue] = discountPercent;
            }
        }
    }

    function order(
        address backer,
        uint256 minOrderValue,
        bytes32[] calldata itemId,
        uint256[] calldata quantity
    )
        public
        virtual
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
        whenCampaignNotPaused
        whenNotPaused
    {
        uint256 tokenId = s_tokenIdCounter.current();
        uint256 orderValue;

        for (uint256 i = 0; i < itemId.length; i++) {
            orderValue += activeItems[itemId[i]].price * quantity[i];
        }

        uint256 discountAmount = (orderValue * s_discountTiers[minOrderValue]) /
            PERCENT_DIVIDER;
        uint256 discountedValue = orderValue - discountAmount;
        bool success = TOKEN.transferFrom(
            backer,
            address(this),
            discountedValue
        );
        if (!success) {
            revert OrderTransferFailed();
        }
        s_tokenIdCounter.increment();
        _safeMint(backer, tokenId, abi.encodePacked(backer, discountedValue));
        s_orderAmount += discountAmount;
        s_tokenToOrderValue[tokenId] = discountedValue;
        s_orderCount.increment();
        emit Receipt(
            backer,
            orderValue,
            discountedValue,
            tokenId,
            itemId,
            quantity
        );
    }

    /**
     * @notice Function for backers to claim a refund if the campaign has not met the success metric.
     * @param tokenId The unique token ID associated with the refund.
     */
    function claimRefund(
        uint256 tokenId
    ) external whenCampaignNotPaused whenNotPaused {
        uint256 amount = s_tokenToOrderValue[tokenId];
        s_tokenToOrderValue[tokenId] = 0;
        burn(tokenId);
        bool success = TOKEN.transfer(msg.sender, amount);
        emit RefundClaimed(tokenId, amount, msg.sender);
        if (!success) {
            revert OrderTransferFailed();
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
        if (SUCCESS_METRIC == UNITS_GOAL) {
            return s_orderCount.current() >= INFO.getGoalAmount();
        } else return INFO.getTotalRaisedAmount() >= INFO.getGoalAmount();
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
