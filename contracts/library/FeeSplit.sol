// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library FeeSplit {
    uint256 constant percentDivider = 10000;

    function splitProportionately(
        uint256 feePercent,
        bytes32[] calldata platforms,
        uint256[] calldata pledgedAmountByPlatforms
    ) public pure returns (uint256[] memory) {}

    function splitWithOriginatorCommission(
        uint256 feePercent,
        uint256 originPlatformCommissionPercent,
        uint256 pledgedAmountByOriginPlatform,
        uint256[] calldata pledgedAmountByReachPlatforms
    ) public pure returns (uint256, uint256[] memory) {}
}
