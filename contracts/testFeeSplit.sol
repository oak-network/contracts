// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract testFeeSplit {
    uint256 constant percentDivider = 10000;
    
    function splitWithVelocityOfFundraising(
        uint256 feePercent,
        uint256 rewardPercent,
        bytes32[] calldata platforms,
        uint256[] pledgedAmountByPlatformsInSequence,
        uint256 lockTime
    ) public pure returns (bytes32, uint256, uint256[] memory) {
        uint256 regularPercent = feePercent -
            rewardPercent;
        uint256 timePassed = block.timestamp - lockTime;
        uint256[] memory feeShareByPlatforms = new uint256[] (platforms.length - 1);
        uint256 rewardedPlatformIndex;
        uint256 pledgedAmountByRewardedPlatform;
        for (uint256 i = 0; i < platforms.length; i++) {
            feeShareByPlatforms[i] =
                (pledgedAmountByPlatformsInSequence[i] * feePercent) /
                percentDivider;
            if (feeShareByPlatforms[i] > pledgedAmountByRewardedPlatform) {
                rewardedPlatformIndex = i;
                pledgedAmountByRewardedPlatform = feeShareByPlatforms[i];
            }
        }
        bytes32 rewardedPlatform = platforms[rewardedPlatformIndex];
        return (rewardedPlatform, pledgedAmountByRewardedPlatform, feeShareByPlatforms);
    }    
}