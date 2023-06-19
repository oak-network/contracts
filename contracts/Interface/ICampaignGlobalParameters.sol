// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignGlobalParameters {
    function denominator() external view returns (uint256);

    function protocol() external view returns (address);
    function platformAddresses(bytes32 platformBytes) external view returns (address);

    function rewardedPlatform() external view returns (bytes32);

    function percentDivider() external pure returns (uint256);
    function protocolFeePercent() external view returns (uint256);
    
    function platformTotalFeePercent() external view returns (uint256);

    function rewardPlatformFeePercent() external view returns (uint256);

    function platformAdmin(bytes32 platformHex) external view returns (address);

    function setProtocolAdmin(address protocolAdmin) external;

    function setDenominator(uint256 denominator) external;

    function setPlatformTotalFeePercent(
        uint256 platformTotalFeePercent
    ) external;

    function setRewardPlatformFeePercent(
        uint256 rewardPlatformFeePercent
    ) external;
}
