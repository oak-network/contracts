// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/ICampaignInfo.sol";

/**
 * @title CampaignAccessChecker
 * @dev This abstract contract provides access control mechanisms to restrict the execution of specific functions
 * to authorized protocol administrators, platform administrators, and campaign owners.
 */
abstract contract CampaignAccessChecker {
    // Immutable reference to the ICampaignInfo contract, which provides campaign-related information and admin addresses.
    ICampaignInfo internal immutable INFO;
    
    // Custom error to indicate unauthorized access attempts.
    error AccessCheckerUnauthorized();

    /**
     * @dev Constructor to initialize the contract with the address of the campaign information contract.
     * @param campaignInfo The address of the ICampaignInfo contract.
     */
    constructor(address campaignInfo) {
        INFO = ICampaignInfo(campaignInfo);
    }

    /**
     * @dev Modifier that restricts function access to protocol administrators only.
     * Users attempting to execute functions with this modifier must be the protocol admin.
     */
    modifier onlyProtocolAdmin() {
        _checkIfProtocolAdmin();
        _;
    }

    /**
     * @dev Modifier that restricts function access to platform administrators of a specific platform.
     * Users attempting to execute functions with this modifier must be the platform admin for the given platform.
     * @param platformBytes The unique identifier of the platform.
     */
    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    /**
     * @dev Modifier that restricts function access to the owner of the campaign.
     * Users attempting to execute functions with this modifier must be the owner of the campaign.
     */
    modifier onlyCampaignOwner() {
        _checkIfCampaignOwner();
        _;
    }

    /**
     * @dev Internal function to check if the sender is the protocol administrator.
     * If the sender is not the protocol admin, it reverts with AccessCheckerUnauthorized error.
     */
    function _checkIfProtocolAdmin() private view {
        if (msg.sender != INFO.getProtocolAdminAddress()) {
            revert AccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AccessCheckerUnauthorized error.
     * @param platformBytes The unique identifier of the platform.
     */
    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (msg.sender != INFO.getPlatformAdminAddress(platformBytes)) {
            revert AccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the owner of the campaign.
     * If the sender is not the owner, it reverts with AccessCheckerUnauthorized error.
     */
    function _checkIfCampaignOwner() private view {
        if (INFO.owner() != msg.sender) {
            revert AccessCheckerUnauthorized();
        }
    }
}
