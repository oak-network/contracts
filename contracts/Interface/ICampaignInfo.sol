// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICampaignContainers.sol";

interface ICampaignInfo {
    function totalCurrentBalance() external view returns (uint256);

    function totalRaisedBalance() external view returns (uint256);

    function treasuryAddress(bytes32 platform) external view returns (address);

    function token() external view returns (address);

    function feeSplitModel() external view returns (bytes32);

    function launchTime() external view returns (uint256);

    function deadline() external view returns (uint256);

    function platforms() external view returns (bytes32[] memory);

    function getCampaignData()
        external
        view
        returns (string memory, uint256, uint256, uint256, string memory);

    function claimFee(bytes32 platform) external;

    function setPlatformInfo(
        bytes32 _platformId,
        address _treasury,
        address _token
    ) external;

    function updateLaunchTime(uint256 _launchTime) external;

    function updateDeadline(uint256 _deadline) external;

    function updateGoal(uint256 _goalAmount) external;

    function pause() external;

    function unpause() external;

    function transferOwnership(address newOwner) external;
}
