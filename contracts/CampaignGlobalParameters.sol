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
    address private _protocolAdmin;
    mapping (bytes32 => address) _platformAdmins;

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

    function protocolAdmin() external view returns (address) {
        return _protocolAdmin;
    }

    function platformAdmin(bytes32 platformHex)  returns (address) {
        return _platformAdmins[platformHex];
    }

    function setPlatformAdmin(bytes32 platformHex_, address platformAdmin_)  returns () {
        _platformAdmins[platformHex_] = platformAdmin_;
    }

    function setProtocolAdmin(address protocolAdmin_) external onlyOwner {
        _protocolAdmin = protocolAdmin_;
    }

    function setDenominator(uint256 denominator_) external onlyOwner {
        _denominator = denominator_;
    }

    function setRewardedPlatform(bytes32 rewardedPlatform_) external onlyOwner {
        _rewardedPlatform = rewardedPlatform_;
    }

    function setPlatformTotalFeePercent(uint256 platformTotalFeePercent_) external onlyOwner {
        _platformTotalFeePercent = platformTotalFeePercent_;
    }

    function setRewardPlatformFeePercent(uint256 rewardPlatformFeePercent_) external onlyOwner {
        _rewardPlatformFeePercent = rewardPlatformFeePercent_;
    }

    function setSpecifiedTime(uint256 specifiedTime_) external onlyOwner {
        _specifiedTime = specifiedTime_;
    }
}
