// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ICampaignData} from "./ICampaignData.sol";

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
     * @notice Emitted when the campaign after creation is initialized.
     */
    event CampaignInfoFactoryCampaignInitialized();

    /**
     * @notice Creates a new campaign information contract with NFT.
     * @dev IMPORTANT: Protocol and platform fees are retrieved at execution time and locked 
     *      permanently in the campaign contract. Users should verify current fees before 
     *      calling this function or using intermediate contracts that check fees haven't 
     *      changed from expected values. The protocol fee is stored as immutable in the cloned 
     *      contract and platform fees are stored during initialization.
     * @param creator The address of the creator of the campaign.
     * @param identifierHash The unique identifier hash of the campaign.
     * @param selectedPlatformHash An array of platform identifiers selected for the campaign.
     * @param platformDataKey An array of platform-specific data keys.
     * @param platformDataValue An array of platform-specific data values.
     * @param campaignData The struct containing campaign launch details (including currency).
     * @param nftName NFT collection name
     * @param nftSymbol NFT collection symbol
     * @param nftImageURI NFT image URI for individual tokens
     * @param contractURI IPFS URI for contract-level metadata
     */
    function createCampaign(
        address creator,
        bytes32 identifierHash,
        bytes32[] calldata selectedPlatformHash,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData,
        string calldata nftName,
        string calldata nftSymbol,
        string calldata nftImageURI,
        string calldata contractURI
    ) external;

    /**
     * @notice Updates the campaign implementation address.
     * @param newImplementation The address of the camapaignInfo implementation contract.
     */
    function updateImplementation(address newImplementation) external;
}
