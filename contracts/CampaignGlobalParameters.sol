// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CampaignGlobalParameters is Ownable {
    uint256 private _denominator = 2;
    bytes32 private _rewardedPlatform;
    uint256 private constant _percentDivider = 10000;
    uint256 private _platformTotalFeePercent;
    uint256 private _rewardPlatformFeePercent;
    uint256 private _specifiedTime;

    function denominator() external view returns (uint256) {
        return _denominator;
    }

    function rewardedPlatform() external view returns (bytes32) {
        return _rewardedPlatform;
    }

    function percentDivider() external pure returns (uint256) {
        return _percentDivider;
    }

    function platformTotalFeePercent() external view returns (uint256) {
        return _platformTotalFeePercent;
    }

    function rewardPlatformFeePercent() external view returns (uint256) {
        return _rewardPlatformFeePercent;
    }

    function specifiedTime() external view returns (uint256) {
        return _specifiedTime;
    }

    function setDenominator(uint256 denominator) external onlyOwner {
        _denominator = denominator;
    }

    function setRewardedPlatform(bytes32 rewardedPlatform) external onlyOwner {
        _rewardedPlatform = rewardedPlatform;
    }

    function setPlatformTotalFeePercent(uint256 platformTotalFeePercent) external onlyOwner {
        _platformTotalFeePercent = platformTotalFeePercent;
    }

    function setRewardPlatformFeePercent(uint256 rewardPlatformFeePercent) external onlyOwner {
        _rewardPlatformFeePercent = rewardPlatformFeePercent;
    }

    function setSpecifiedTime(uint256 specifiedTime) external onlyOwner {
        _specifiedTime = specifiedTime;
    }
}
