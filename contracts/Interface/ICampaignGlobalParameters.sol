// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignGlobalParameters {
    function denominator() external view returns (uint256);

    function rewardedPlatform() external view returns (bytes32);

    function percentDivider() external pure returns (uint256);

    function platformTotalFeePercent() external view returns (uint256);

    function rewardPlatformFeePercent() external view returns (uint256);

    function specifiedTime() external view returns (uint256);

    function protocolAdmin() external view returns (address);

    function platformAdmin(bytes32 platformHex) external view returns (address);

    function setPlatformAdmin(
        bytes32 platformHex,
        address platformAdmin
    ) external;

    function setProtocolAdmin(address protocolAdmin) external;

    function setDenominator(uint256 denominator) external;

    function setRewardedPlatform(bytes32 rewardedPlatform) external;

    function setPlatformTotalFeePercent(
        uint256 platformTotalFeePercent
    ) external;

    function setRewardPlatformFeePercent(
        uint256 rewardPlatformFeePercent
    ) external;

    function setSpecifiedTime(uint256 specifiedTime) external;
}
