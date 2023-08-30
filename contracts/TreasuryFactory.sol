// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignRegistry.sol";
import "./interfaces/ICampaignInfo.sol";

contract TreasuryFactory {
    mapping(bytes32 => mapping(uint256 => bytes)) private s_platformByteCode;
    mapping(bytes => bool) private s_approvedByteCode;

    IGlobalParams private immutable GLOBAL_PARAMS;
    ICampaignRegistry private immutable CAMPAIGN_REGISTRY;

    error TreasuryFactoryUnauthorized();
    error TreasuryFactoryInvalidKey();
    error TreasuryFactoryByteCodeAlreadyApproved();
    error TreasuryFactoryByteCodeNotApproved();

    constructor(address globalParams, address campaignRegistry) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
        CAMPAIGN_REGISTRY = ICampaignRegistry(campaignRegistry);
    }

    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    modifier onlyProtocolAdmin() {
        _checkIfProtocolAdmin();
        _;
    }

    function addByteCode(
        bytes32 platformBytes,
        uint256 bytecCodeIndex,
        bytes calldata byteCode
    ) external onlyPlatformAdmin(platformBytes) {
        s_platformByteCode[platformBytes][bytecCodeIndex] = byteCode;
    }

    function enlistByteCode(
        bytes32 platformBytes,
        uint256 byteCodeIndex
    ) external onlyProtocolAdmin {
        bytes memory byteCode = s_platformByteCode[platformBytes][
            byteCodeIndex
        ];
        if (byteCode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        if (s_approvedByteCode[byteCode]) {
            revert TreasuryFactoryByteCodeAlreadyApproved();
        }
        s_approvedByteCode[byteCode] = true;
    }

    function delistByteCode(
        bytes32 platformBytes,
        uint256 byteCodeIndex
    ) external onlyProtocolAdmin {
        bytes storage byteCode = s_platformByteCode[platformBytes][
            byteCodeIndex
        ];
        if (byteCode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        s_approvedByteCode[byteCode] = false;
        delete s_platformByteCode[platformBytes][byteCodeIndex];
    }

    function deploy(
        bytes32 platformBytes,
        uint256 byteCodeIndex,
        bytes32 identifierHash
    ) external {
        bytes memory byteCode = s_platformByteCode[platformBytes][
            byteCodeIndex
        ];
        if (!s_approvedByteCode[byteCode]) {
            revert TreasuryFactoryByteCodeNotApproved();
        }
        address infoAddress = CAMPAIGN_REGISTRY.getCampaignInfoAddress(
            identifierHash
        );
        address tokenAddress = ICampaignInfo(infoAddress).getTokenAddress();
        uint256 platformFeePercent = 300; //ICampaignInfo(info).getPlatformFeePercent();
        bytes memory argsByteCode = abi.encodePacked(
            byteCode,
            abi.encode(
                platformBytes,
                platformFeePercent,
                infoAddress,
                tokenAddress
            )
        );
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (
            GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes) != msg.sender
        ) {
            revert TreasuryFactoryUnauthorized();
        }
    }

    function _checkIfProtocolAdmin() private view {
        if (GLOBAL_PARAMS.getProtocolAdminAddress() != msg.sender) {
            revert TreasuryFactoryUnauthorized();
        }
    }
}
