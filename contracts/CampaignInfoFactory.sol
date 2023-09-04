// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignInfoFactory.sol";

contract CampaignInfoFactory is ICampaignInfoFactory, Ownable {
    bytes private constant bytecode = type(CampaignInfo).creationCode;

    IGlobalParams private GLOBAL_PARAMS;
    address private s_treasuryFactoryAddress;
    bool private s_initialized;

    error CampaignInfoFactoryAlreadyInitialized();
    error CampaignInfoFactoryInvalidInput();
    error CampaignInfoFactoryCampaignCreationFailed();

    constructor(address globalParams) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
    }

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
        bytes32[] calldata selectedPlatformBytes,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue,
        CampaignData calldata campaignData
    ) external override {
        if (platformDataKey.length != platformDataValue.length) {
            revert CampaignInfoFactoryInvalidInput();
        }
        bytes memory argsByteCode = abi.encodePacked(
            bytecode,
            abi.encode(
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
        address info;
        assembly {
            info := create2(
                0,
                add(argsByteCode, 0x20),
                mload(argsByteCode),
                identifierHash
            )
        }
        if (info == address(0)) {
            revert CampaignInfoFactoryCampaignCreationFailed();
        }
        emit campaignCreated(identifierHash, info);
    }
}
