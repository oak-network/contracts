// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library FeeSplit {
    uint256 constant percentDivider = 10000;

    function splitProportionately(
        uint256 feePercent,
        uint256[] calldata pledgedAmountByPlatforms
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

    function splitWithOriginReward(
        uint256 totalFeePercent,
        uint256 originRewardPercent,
        uint256 pledgedAmountByOrigin,
        uint256[] calldata pledgedAmountsByReach
    ) public pure returns (uint256, uint256[] memory) {
        uint256 noOfReach = pledgedAmountsByReach.length;
        uint256 reachFeePercent = (totalFeePercent - originRewardPercent) /
            (noOfReach + 1);
        uint256 feeByOrigin = (pledgedAmountByOrigin *
            (originRewardPercent + reachFeePercent)) / percentDivider;
        return (
            feeByOrigin,
            splitProportionately(reachFeePercent, pledgedAmountsByReach)
        );
    }
}
