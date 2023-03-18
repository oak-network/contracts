// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CampaignFeeSplitter {
    function getFeeSplitsProportionately(
        uint256 feePercent,
        uint256 percentDivider,
        uint256[] memory pledgedAmountByPlatforms
    ) public pure returns (uint256[] memory) {
        uint256 length = pledgedAmountByPlatforms.length;
        uint256[] memory feeShareByPlatforms = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            feeShareByPlatforms[i] =
                (pledgedAmountByPlatforms[i] * feePercent) /
                percentDivider;
        }
        return feeShareByPlatforms;
    }

    function getFeeSplitsProportionatelyWithPlatformReward(
        uint256 totalFeePercent,
        uint256 percentDivider,
        uint256 platformRewardPercent,
        uint256 pledgedAmountByOrigin,
        uint256[] memory pledgedAmountsByReach
    ) public pure returns (uint256, uint256[] memory) {
        uint256 noOfReach = pledgedAmountsByReach.length;
        uint256 reachFeePercent = (totalFeePercent - platformRewardPercent) /
            (noOfReach + 1);
        uint256 feeByOrigin = (pledgedAmountByOrigin *
            (platformRewardPercent + reachFeePercent)) / percentDivider;
        return (
            feeByOrigin,
            getFeeSplitsProportionately(
                reachFeePercent,
                percentDivider,
                pledgedAmountsByReach
            )
        );
    }
}
