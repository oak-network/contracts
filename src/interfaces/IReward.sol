// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
/**
 * @title IReward
 * @notice An interface for managing rewards in a campaign.
 */
interface IReward {

    struct Reward {
        uint256 rewardValue;
        bool isRewardTier;
        bytes32[] itemId;
        uint256[] itemValue;
        uint256[] itemQuantity;
    }
}
