// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignInfo {
    function checkIfPlatformSelected(bytes32 platformBytes) external view returns (bool);
    function getTotalRaisedAmount() external view returns (uint256);
    function getProtocolAdminAddress() external view returns (address);
    function getPlatformAdminAddress(bytes32 platformBytes) external view returns (address);
    function getLaunchTime() external view returns (uint256);
    function getDeadline() external view returns (uint256);
    function getGoalAmount() external view returns (uint256);
    function getTokenAddress() external view returns (address);
    function getProtocolFeePercent() external view returns (uint256);
    function getIdentifierHash() external view returns (bytes32);
    function setPlatformInfo(bytes32 platformBytes, address platformTreasuryAddress) external;
    function transferOwnership(address newOwner) external;
    function updateLaunchTime(uint256 launchTime) external;
    function updateDeadline(uint256 deadline) external;
    function updateGoalAmount(uint256 goalAmount) external;
    function updateSelectedPlatform(bytes32 platformBytes, bool selection) external;
}
