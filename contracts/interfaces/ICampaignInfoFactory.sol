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
        CampaignData memory campaignData,
        bytes32[] memory selectedPlatformBytes
    ) external;
}
