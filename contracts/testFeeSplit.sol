// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract testFeeSplit {
    
    function splitWithVelocityOfFundraising(
        uint256 feePercent,
        uint256 rewardPercent,
        bytes32[] calldata platforms,
        uint256[] pledgedAmountByPlatformsInSequence,
        uint256 lockTime
    ) public pure returns (bytes32, uint256, uint256[] memory) {
        uint256 regularPercent = feePercent -
            rewardPercent;

        return (feeShareByOriginPlatform, feeShareByReachPlatforms);
    }    
}