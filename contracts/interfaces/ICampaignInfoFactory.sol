// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICampaignData.sol";

interface ICampaignInfoFactory is ICampaignData {

    event campaignCreation(
        bytes32 indexed identifierHash,
        address indexed campaignInfoAddress
    );

    function createCampaign(
        address creator,
        bytes32 identifierHash,
        bytes32[] calldata selectedPlatformBytes,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external;
}
