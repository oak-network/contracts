// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignTreasury {
    function disburseFees() external;
    function withdraw() external;
    function claimRefund(uint256 tokenId) external;
    function getplatformBytes() external view returns (bytes32);
    function getplatformFeePercent() external view returns (uint256);
    function getRaisedAmount() external view returns (uint256);
}
