// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IGlobalParams} from "./interfaces/IGlobalParams.sol";
import {ICampaignInfoFactory} from "./interfaces/ICampaignInfoFactory.sol";
import {CampaignInfoFactoryStorage} from "./storage/CampaignInfoFactoryStorage.sol";
import {DataRegistryKeys} from "./constants/DataRegistryKeys.sol";

/**
 * @title CampaignInfoFactory
 * @notice Factory contract for creating campaign information contracts.
 * @dev UUPS Upgradeable contract with ERC-7201 namespaced storage
 */
contract CampaignInfoFactory is Initializable, ICampaignInfoFactory, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @dev Emitted when invalid input is provided.
     */
    error CampaignInfoFactoryInvalidInput();

    /**
     * @dev Emitted when campaign creation fails.
     */
    error CampaignInfoFactoryCampaignInitializationFailed();
    error CampaignInfoFactoryPlatformNotListed(bytes32 platformHash);
    error CampaignInfoFactoryCampaignWithSameIdentifierExists(bytes32 identifierHash, address cloneExists);

    /**
     * @dev Emitted when the campaign currency has no tokens.
     */
    error CampaignInfoInvalidTokenList();

    /**
     * @dev Constructor that disables initializers to prevent implementation contract initialization
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the CampaignInfoFactory contract.
     * @param initialOwner The address that will own the factory
     * @param globalParams The address of the global parameters contract.
     * @param campaignImplementation The address of the campaign implementation contract.
     * @param treasuryFactoryAddress The address of the treasury factory contract.
     */
    function initialize(
        address initialOwner,
        IGlobalParams globalParams,
        address campaignImplementation,
        address treasuryFactoryAddress
    ) public initializer {
        if (
            address(globalParams) == address(0) || campaignImplementation == address(0)
                || treasuryFactoryAddress == address(0) || initialOwner == address(0)
        ) {
            revert CampaignInfoFactoryInvalidInput();
        }

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        CampaignInfoFactoryStorage.Storage storage $ = CampaignInfoFactoryStorage._getCampaignInfoFactoryStorage();
        $.globalParams = globalParams;
        $.implementation = campaignImplementation;
        $.treasuryFactoryAddress = treasuryFactoryAddress;
    }

    /**
     * @dev Function that authorizes an upgrade to a new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @inheritdoc ICampaignInfoFactory
     * @notice Creates a new campaign with NFT
     * @param creator The campaign creator address
     * @param identifierHash The unique identifier hash for the campaign
     * @param selectedPlatformHash Array of selected platform hashes
     * @param platformDataKey Array of platform data keys
     * @param platformDataValue Array of platform data values
     * @param campaignData The campaign data
     * @param nftName NFT collection name
     * @param nftSymbol NFT collection symbol
     * @param nftImageURI NFT image URI for individual tokens
     * @param contractURI IPFS URI for contract-level metadata (constructed off-chain)
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
    ) external override {
        if (creator == address(0)) {
            revert CampaignInfoFactoryInvalidInput();
        }
        if (platformDataKey.length != platformDataValue.length) {
            revert CampaignInfoFactoryInvalidInput();
        }

        CampaignInfoFactoryStorage.Storage storage $ = CampaignInfoFactoryStorage._getCampaignInfoFactoryStorage();

        // Cache globalParams to save gas on repeated storage reads
        IGlobalParams globalParams = $.globalParams;

        // Retrieve time constraints from GlobalParams dataRegistry
        uint256 campaignLaunchBuffer = uint256(globalParams.getFromRegistry(DataRegistryKeys.CAMPAIGN_LAUNCH_BUFFER));
        uint256 minimumCampaignDuration =
            uint256(globalParams.getFromRegistry(DataRegistryKeys.MINIMUM_CAMPAIGN_DURATION));

        // Validate campaign timing constraints
        if (campaignData.launchTime < block.timestamp + campaignLaunchBuffer) {
            revert CampaignInfoFactoryInvalidInput();
        }
        if (campaignData.deadline < campaignData.launchTime + minimumCampaignDuration) {
            revert CampaignInfoFactoryInvalidInput();
        }

        bool isValid;
        for (uint256 i = 0; i < platformDataKey.length; i++) {
            isValid = globalParams.checkIfPlatformDataKeyValid(platformDataKey[i]);
            if (!isValid) {
                revert CampaignInfoFactoryInvalidInput();
            }
            if (platformDataValue[i] == bytes32(0)) {
                revert CampaignInfoFactoryInvalidInput();
            }
        }
        address cloneExists = $.identifierToCampaignInfo[identifierHash];
        if (cloneExists != address(0)) {
            revert CampaignInfoFactoryCampaignWithSameIdentifierExists(identifierHash, cloneExists);
        }
        bool isListed;
        bytes32 platformHash;
        for (uint256 i = 0; i < selectedPlatformHash.length; i++) {
            platformHash = selectedPlatformHash[i];
            isListed = globalParams.checkIfPlatformIsListed(platformHash);
            if (!isListed) {
                revert CampaignInfoFactoryPlatformNotListed(platformHash);
            }
        }

        // Get accepted tokens for the campaign currency
        address[] memory acceptedTokens = globalParams.getTokensForCurrency(campaignData.currency);
        if (acceptedTokens.length == 0) {
            revert CampaignInfoInvalidTokenList();
        }

        bytes memory args = abi.encode($.treasuryFactoryAddress, globalParams.getProtocolFeePercent(), identifierHash);
        address clone = Clones.cloneWithImmutableArgs($.implementation, args);

        // Initialize with all parameters including NFT metadata
        (bool success,) = clone.call(
            abi.encodeWithSignature(
                "initialize(address,address,bytes32[],bytes32[],bytes32[],(uint256,uint256,uint256,bytes32),address[],string,string,string,string)",
                creator,
                address(globalParams),
                selectedPlatformHash,
                platformDataKey,
                platformDataValue,
                campaignData,
                acceptedTokens,
                nftName,
                nftSymbol,
                nftImageURI,
                contractURI
            )
        );
        if (!success) {
            revert CampaignInfoFactoryCampaignInitializationFailed();
        }
        $.identifierToCampaignInfo[identifierHash] = clone;
        $.isValidCampaignInfo[clone] = true;
        emit CampaignInfoFactoryCampaignCreated(identifierHash, clone);
        emit CampaignInfoFactoryCampaignInitialized();
    }

    /**
     * @inheritdoc ICampaignInfoFactory
     */
    function updateImplementation(address newImplementation) external override onlyOwner {
        if (newImplementation == address(0)) {
            revert CampaignInfoFactoryInvalidInput();
        }
        CampaignInfoFactoryStorage.Storage storage $ = CampaignInfoFactoryStorage._getCampaignInfoFactoryStorage();
        $.implementation = newImplementation;
    }

    /**
     * @notice Check if a campaign info address is valid
     * @param campaignInfo The campaign info address to check
     * @return bool True if valid, false otherwise
     */
    function isValidCampaignInfo(address campaignInfo) external view returns (bool) {
        CampaignInfoFactoryStorage.Storage storage $ = CampaignInfoFactoryStorage._getCampaignInfoFactoryStorage();
        return $.isValidCampaignInfo[campaignInfo];
    }

    /**
     * @notice Get campaign info address from identifier
     * @param identifierHash The identifier hash
     * @return address The campaign info address
     */
    function identifierToCampaignInfo(bytes32 identifierHash) external view returns (address) {
        CampaignInfoFactoryStorage.Storage storage $ = CampaignInfoFactoryStorage._getCampaignInfoFactoryStorage();
        return $.identifierToCampaignInfo[identifierHash];
    }
}
