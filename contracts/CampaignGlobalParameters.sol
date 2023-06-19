// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interface/ICampaignGlobalParameters.sol";

contract CampaignGlobalParameters is ICampaignGlobalParameters, Ownable {
    uint256 private _denominator = 2;
    uint256 private constant _percentDivider = 10000;
    uint256 private _platformTotalFeePercent;
    uint256 private _rewardPlatformFeePercent;
    uint256 public protocolFeePercent;
    address public protocolAddress;

    mapping(bytes32 => address) public platformAddresses;

    constructor(address _protocolAddress) {
        transferOwnership(_protocolAddress);
    }

    function denominator() external view returns (uint256) {
        return _denominator;
    }

    function protocol() external view override returns (address) {
        return owner();
    }

    // function rewardedPlatform() external view returns (bytes32) {
    //     return _rewardedPlatform;
    // }

    function percentDivider() external pure returns (uint256) {
        return _percentDivider;
    }

    function platformTotalFeePercent() external view returns (uint256) {
        return _platformTotalFeePercent;
    }

    function rewardPlatformFeePercent() external view returns (uint256) {
        return _rewardPlatformFeePercent;
    }

    function setPlatformAddress(
        bytes32 platformHex_,
        address platformAddress_
    ) external {
        platformAddresses[platformHex_] = platformAddress_;
    }

    // function setProtocolAdmin(address protocolAdmin_) external onlyOwner {
    //     _protocolAdmin = protocolAdmin_;
    // }

    function setDenominator(uint256 denominator_) external onlyOwner {
        _denominator = denominator_;
    }

    // function setRewardedPlatform(bytes32 rewardedPlatform_) external onlyOwner {
    //     _rewardedPlatform = rewardedPlatform_;
    // }

    function setProtocolFeePercent(
        uint256 protocolFeePercent_
    ) external onlyOwner {
        protocolFeePercent = protocolFeePercent_;
    }

    function setPlatformTotalFeePercent(
        uint256 platformTotalFeePercent_
    ) external onlyOwner {
        _platformTotalFeePercent = platformTotalFeePercent_;
    }

    function setRewardPlatformFeePercent(
        uint256 rewardPlatformFeePercent_
    ) external onlyOwner {
        _rewardPlatformFeePercent = rewardPlatformFeePercent_;
    }

    function rewardedPlatform() external view override returns (bytes32) {}

    function setProtocolAdmin(address protocolAdmin) external override {}

    function platformAdmin(
        bytes32 platformHex
    ) external view override returns (address) {}
}
