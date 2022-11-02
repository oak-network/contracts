// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library FeeSplit {
    uint256 constant percentDivider = 10000;

    function splitProportionately(
        uint256 feePercent,
        bytes32[] memory platforms,
        uint256[] memory pledgedAmountByPlatforms
    ) public pure
    returns (uint256[] memory) 
    {
        bytes32[] memory tempPlatforms = platforms;
        uint256[]
            memory tempPledgedAmountByPlatforms = pledgedAmountByPlatforms;
        require(
            tempPlatforms.length == tempPledgedAmountByPlatforms.length,
            "FeeSplit: platforms and pledgedAmountByPlatforms length unequal"
        );
        uint256[] memory feeShareByPlatforms = new uint256[] (tempPlatforms.length);
        for (uint256 i = 0; i < tempPlatforms.length; i++) {
            feeShareByPlatforms[i] =
                (tempPledgedAmountByPlatforms[i] * feePercent) /
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
        uint256 reachPlatformComissionPercent = feePercent -
            originPlatformCommissionPercent;
        uint256[]
            memory tempPledgedAmountByReachPlatforms = pledgedAmountByReachPlatforms;
        uint256[] memory feeShareByReachPlatforms;
        uint256 feeShareByOriginPlatform = (pledgedAmountByOriginPlatform *
            originPlatformCommissionPercent) / percentDivider;
        for (uint256 i = 0; i < tempPledgedAmountByReachPlatforms.length; i++) {
            feeShareByReachPlatforms[i] =
                (tempPledgedAmountByReachPlatforms[i] *
                    reachPlatformComissionPercent) /
                percentDivider;
        }
        return (feeShareByOriginPlatform, feeShareByReachPlatforms);
    }
}
