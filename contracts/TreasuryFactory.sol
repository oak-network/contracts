// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./models/AllOrNothing.sol";
import "./models/KeepWhatsRaised.sol";
import "./models/PreOrder.sol";
import "./interfaces/IGlobalParams.sol";

contract TreasuryFactory {

    mapping (bytes32 => bytes) private platformByteCode;
    IGlobalParams private immutable GLOBAL_PARAMS;

    error TreasuryFactoryUnauthorized();

    constructor(address globalParams) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
    }

    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    modifier onlyProtocolAdmin() {
        _checkIfProtocolAdmin();
        _;
    }

    function addByteCode(bytes32 platformBytes, bytes calldata byteCode) external onlyPlatformAdmin(platformBytes) {
        platformByteCode[platformBytes] = byteCode;
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) private {
        if (GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes) != msg.sender) {
            revert TreasuryFactoryUnauthorized();
        }
    }

    function _checkIfProtocolAdmin() private {
        if (GLOBAL_PARAMS.getProtocolAdminAddress() != msg.sender) {
            revert TreasuryFactoryUnauthorized();
        }
    }
}
