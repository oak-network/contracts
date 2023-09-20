// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignInfoFactory.sol";

/**
 * @title CampaignInfoFactory
 * @notice Factory contract for creating campaign information contracts.
 */
contract CampaignInfoFactory is ICampaignInfoFactory, Ownable {
    bytes private constant bytecode = type(CampaignInfo).creationCode;

    IGlobalParams private GLOBAL_PARAMS;
    address private s_treasuryFactoryAddress;
    bool private s_initialized;

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

    /**
     * @param globalParams The address of the global parameters contract.
     */
    constructor(IGlobalParams globalParams) {
        GLOBAL_PARAMS = globalParams;
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

    /**
     * @inheritdoc ICampaignInfoFactory
     */
    function createCampaign(
        address creator,
        bytes32 identifierHash,
        bytes32[] calldata selectedPlatformBytes,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external override {
        if (platformDataKey.length != platformDataValue.length) {
            revert CampaignInfoFactoryInvalidInput();
        }
        address info = address(
            new CampaignInfo{salt: identifierHash}(
                GLOBAL_PARAMS,
                s_treasuryFactoryAddress,
                GLOBAL_PARAMS.getTokenAddress(),
                creator,
                GLOBAL_PARAMS.getProtocolFeePercent(),
                identifierHash,
                selectedPlatformBytes,
                platformDataKey,
                platformDataValue,
                campaignData
            )
        );
        if (info == address(0)) {
            revert CampaignInfoFactoryCampaignCreationFailed();
        }
        emit CampaignInfoFactoryCampaignCreated(identifierHash, info);
    }
}
