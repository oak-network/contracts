// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import the MinimumOrder contract
import "./MinimumOrder.sol";

/**
 * @title OutOfStock
 * @notice A Solidity contract for managing minimum order-based campaigns with an out-of-stock limit.
 * Users can pre-order items or rewards until the out-of-stock limit is reached.
 * When the predefined success metric is reached or the out-of-stock limit is reached, the campaign ends.
 */
contract OutOfStock is MinimumOrder {
    // Custom error to handle the out-of-stock limit being reached
    error OutOfStockLimitReached();

    /**
     * @dev Constructor for the OutOfStock contract.
     * @param platformBytes The unique identifier of the platform.
     * @param infoAddress The address of the CampaignInfo contract providing campaign details.
     */
    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) MinimumOrder(platformBytes, infoAddress) {}

    /**
     * @notice Function for backers to pre-order a reward, checking against the out-of-stock limit.
     * The pre-order can only be made within the specified campaign timeframe.
     * @param backer The address of the backer making the pre-order.
     * @param rewardName The name of the reward to pre-order.
     */
    function preOrderForAReward(
        address backer,
        bytes32 rewardName
    )
        public
        override
        currentTimeIsWithinRange(INFO.getLaunchTime(), INFO.getDeadline())
    {
        // Check if the out-of-stock limit will be reached with the new pre-order
        if (MinimumOrder.getNumberOfOrders() + 1 > SUCCESS_METRIC) {
            revert OutOfStockLimitReached();
        }
        MinimumOrder.preOrderForAReward(backer, rewardName);
    }
}
