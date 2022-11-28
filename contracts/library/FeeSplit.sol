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

    function splitWithOriginatorCommission(
        uint256 feePercent,
        uint256 originPlatformCommissionPercent,
        uint256 pledgedAmountByOriginPlatform,
        uint256[] calldata pledgedAmountByReachPlatforms
    ) public pure returns (uint256, uint256[] memory) {
        uint256 noOfPlatforms = pledgedAmountByReachPlatforms.length;
        uint256 originPlatformTotalCommisionPercent = originPlatformCommissionPercent +
                (feePercent - originPlatformCommissionPercent) /
                (noOfPlatforms + 1);
        uint256 reachPlatformComissionPercent = (feePercent -
            originPlatformTotalCommisionPercent) / (noOfPlatforms + 1);
        uint256[] memory feeShareByReachPlatforms = new uint256[](
            noOfPlatforms
        );
        uint256 feeShareByOriginPlatform = (pledgedAmountByOriginPlatform *
            originPlatformTotalCommisionPercent) / percentDivider;
        feeShareByReachPlatforms = splitProportionately(reachFeePercent, pledgedAmountsByReach);

        return (feeShareByOriginPlatform, feeShareByReachPlatforms);
    }
    
}
