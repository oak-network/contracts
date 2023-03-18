// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignFeeSplitter {
    function getFeeSplitsProportionately(
        uint256 percentDivider,
        uint256 feePercent,
        uint256[] memory pledgedAmountByPlatforms
    ) external pure returns (uint256[] memory);

    function getFeeSplitsProportionatelyWithPlatformReward(
        uint256 totalFeePercent,
        uint256 percentDivider,
        uint256 platformRewardPercent,
        uint256 pledgedAmountByOrigin,
        uint256[] memory pledgedAmountsByReach
    ) external pure returns (uint256, uint256[] memory);
}
