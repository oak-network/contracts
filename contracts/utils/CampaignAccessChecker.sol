// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/ICampaignInfo.sol";

abstract contract CampaignAccessChecker {
    ICampaignInfo internal immutable INFO;
    error AccessCheckerUnauthorized();

    constructor(address campaignInfo) {
        INFO = ICampaignInfo(campaignInfo);
    }

    modifier onlyProtocolAdmin() {
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

    function _checkIfProtocolAdmin() private view {
        if (msg.sender != INFO.getProtocolAdminAddress()) {
            revert AccessCheckerUnauthorized();
        }
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
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
