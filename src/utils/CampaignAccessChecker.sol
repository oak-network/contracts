// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ICampaignInfo} from "../interfaces/ICampaignInfo.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title CampaignAccessChecker
 * @dev This abstract contract provides access control mechanisms to restrict the execution of specific functions
 * to authorized protocol administrators, platform administrators, and campaign owners.
 */
abstract contract CampaignAccessChecker is Context {
    // Immutable reference to the ICampaignInfo contract, which provides campaign-related information and admin addresses.
    ICampaignInfo internal INFO;

    /**
     * @dev Throws when the caller is not authorized.
     */
    error AccessCheckerUnauthorized();

    /**
     * @dev Constructor to initialize the contract with the address of the campaign information contract.
     * @param campaignInfo The address of the ICampaignInfo contract.
     */
    function __CampaignAccessChecker_init(address campaignInfo) internal {
        INFO = ICampaignInfo(campaignInfo);
    }

    /**
     * @dev Modifier that restricts function access to protocol administrators only.
     * Users attempting to execute functions with this modifier must be the protocol admin.
     */
    modifier onlyProtocolAdmin() {
        _onlyProtocolAdmin();
        _;
    }

    /**
     * @dev Modifier that restricts function access to platform administrators of a specific platform.
     * Users attempting to execute functions with this modifier must be the platform admin for the given platform.
     * @param platformHash The unique identifier of the platform.
     */
    modifier onlyPlatformAdmin(bytes32 platformHash) {
        _onlyPlatformAdmin(platformHash);
        _;
    }

    /**
     * @dev Modifier that restricts function access to the owner of the campaign.
     * Users attempting to execute functions with this modifier must be the owner of the campaign.
     */
    modifier onlyCampaignOwner() {
        _onlyCampaignOwner();
        _;
    }

    /**
     * @dev Internal function to check if the sender is the protocol administrator.
     * If the sender is not the protocol admin, it reverts with AccessCheckerUnauthorized error.
     */
    function _onlyProtocolAdmin() private view {
        if (_msgSender() != INFO.getProtocolAdminAddress()) {
            revert AccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AccessCheckerUnauthorized error.
     * @param platformHash The unique identifier of the platform.
     */
    function _onlyPlatformAdmin(bytes32 platformHash) private view {
        if (_msgSender() != INFO.getPlatformAdminAddress(platformHash)) {
            revert AccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the owner of the campaign.
     * If the sender is not the owner, it reverts with AccessCheckerUnauthorized error.
     */
    function _onlyCampaignOwner() private view {
        if (INFO.owner() != _msgSender()) {
            revert AccessCheckerUnauthorized();
        }
    }
}
