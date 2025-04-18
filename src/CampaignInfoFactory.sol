// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./CampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignInfoFactory.sol";

/**
 * @title CampaignInfoFactory
 * @notice Factory contract for creating campaign information contracts.
 */
contract CampaignInfoFactory is ICampaignInfoFactory, Ownable {
    IGlobalParams private GLOBAL_PARAMS;
    address private s_treasuryFactoryAddress;
    bool private s_initialized;
    address private s_implementation;
    mapping(address => bool) public isValidCampaignInfo;
    mapping(bytes32 => address) public identifierToCampaignInfo;

    /**
     * @dev Emitted when the factory is initialized.
     */
    error CampaignInfoFactoryAlreadyInitialized();

    /**
     * @dev Emitted when invalid input is provided.
     */
    error CampaignInfoFactoryInvalidInput();

    /**
     * @dev Emitted when campaign creation fails.
     */
    error CampaignInfoFactoryCampaignCreationFailed();
    error CampaignInfoFactoryPlatformNotListed(bytes32 platformHash);
    error CampaignInfoFactoryCampaignWithSameIdentifierExists(
        bytes32 identifierHash,
        address cloneExists
    );

    /**
     * @param globalParams The address of the global parameters contract.
     */
    constructor(IGlobalParams globalParams, address campaignImplementation) Ownable(msg.sender) {
        GLOBAL_PARAMS = globalParams;
        s_implementation = campaignImplementation;
    }

    /**
     * @dev Initializes the factory with treasury factory address.
     * @param treasuryFactoryAddress The address of the treasury factory contract.
     * @param globalParams The address of the global parameters contract.
     */
    function _initialize(
        address treasuryFactoryAddress,
        address globalParams
    ) external onlyOwner {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
        if (s_initialized) {
            revert CampaignInfoFactoryAlreadyInitialized();
        }
        s_treasuryFactoryAddress = treasuryFactoryAddress;
        s_initialized = true;
    }

    function createCampaign(
        address creator,
        bytes32 identifierHash,
        bytes32[] calldata selectedPlatformHash,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external override {
        if (platformDataKey.length != platformDataValue.length) {
            revert CampaignInfoFactoryInvalidInput();
        }
        address cloneExists = identifierToCampaignInfo[identifierHash];
        if (cloneExists != address(0)) {
            revert CampaignInfoFactoryCampaignWithSameIdentifierExists(
                identifierHash,
                cloneExists
            );
        }
        bool isListed;
        bytes32 platformHash;
        for (uint256 i = 0; i < selectedPlatformHash.length; i++) {
            platformHash = selectedPlatformHash[i];
            isListed = GLOBAL_PARAMS.checkIfPlatformIsListed(platformHash);
            if (!isListed) {
                revert CampaignInfoFactoryPlatformNotListed(platformHash);
            }
        }

        bytes memory args = abi.encode(
            s_treasuryFactoryAddress,
            GLOBAL_PARAMS.getTokenAddress(),
            GLOBAL_PARAMS.getProtocolFeePercent(),
            identifierHash,
            campaignData.launchTime,
            campaignData.deadline,
            campaignData.goalAmount
        );
        address clone = Clones.cloneWithImmutableArgs(s_implementation, args);
        emit CampaignInfoFactoryCampaignCreated(identifierHash, clone);
        CampaignInfo(clone).initialize(
            creator,
            GLOBAL_PARAMS,
            selectedPlatformHash,
            platformDataKey,
            platformDataValue
        );
        identifierToCampaignInfo[identifierHash] = clone;
        isValidCampaignInfo[clone] = true;
    }
}
