// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract testFeeSplit {
    
    function splitWithVelocityOfFundraising(
        uint256 feePercent,
        uint256 originPlatformCommissionPercent,
        uint256 pledgedAmountByOriginPlatform,
        uint256[] calldata pledgedAmountByReachPlatforms
    ) public pure returns (uint256, uint256[] memory) {

        return (feeShareByOriginPlatform, feeShareByReachPlatforms);
    }    
}