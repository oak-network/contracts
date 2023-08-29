// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignRegistry {
    function getCampaignInfoFactoryAddress() external view returns (address);
    function getTreasuryFactoryAddress() external view returns (address);
    function getCampaignInfoAddress(bytes32 identifierHash) external view returns (address campaignAddress);
    function setCampaignInfoAddress(bytes32 identifierHash, address campaignAddress) external;
}
