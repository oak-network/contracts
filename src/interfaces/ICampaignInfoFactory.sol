// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICampaignData.sol";

/**
 * @title ICampaignInfoFactory
 * @notice An interface for creating and managing campaign information contracts.
 */
interface ICampaignInfoFactory is ICampaignData {
    /**
     * @notice Emitted when a campaign is successfully created.
     * @param identifierHash The unique identifier hash of the campaign.
     * @param campaignInfoAddress The address of the created campaign information contract.
     */
    event CampaignInfoFactoryCampaignCreated(
        bytes32 indexed identifierHash,
        address indexed campaignInfoAddress
    );

    /**
     * @notice Creates a new campaign information contract.
     * @param creator The address of the creator of the campaign.
     * @param identifierHash The unique identifier hash of the campaign.
     * @param selectedPlatformBytes An array of platform identifiers selected for the campaign.
     * @param platformDataKey An array of platform-specific data keys.
     * @param platformDataValue An array of platform-specific data values.
     * @param campaignData The struct containing campaign launch details.
     */
    function createCampaign(
        address creator,
        bytes32 identifierHash,
        bytes32[] calldata selectedPlatformBytes,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external;
}
