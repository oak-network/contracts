// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/IGlobalParams.sol";
import "../interfaces/ICampaignInfo.sol";

abstract contract AccessChecker {
    ICampaignInfo internal immutable INFO;
    error AccessCheckerUnauthorized();

    constructor(address campaignInfo) {
        INFO = ICampaignInfo(campaignInfo);
    }

    modifier onlyProtocolAdmin(bytes32 protocolAdmin) {
        _checkIfProtocolAdmin();
        _;
    }

    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    modifier onlyCampaignOwner() {
        _checkIfCampaignOwner();
        _;
    }

    function _checkIfProtocolAdmin() internal view {
        if (msg.sender != INFO.getProtocolAdminAddress()) {
            revert AccessCheckerUnauthorized();
        }
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) internal view {
        if (msg.sender != INFO.getPlatformAdminAddress(platformBytes)) {
            revert AccessCheckerUnauthorized();
        }
    }

    function _checkIfCampaignOwner() private view {
        if (INFO.owner() != msg.sender) {
            revert AccessCheckerUnauthorized();
        }
    }
}
