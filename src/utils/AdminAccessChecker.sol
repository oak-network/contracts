// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IGlobalParams} from "../interfaces/IGlobalParams.sol";
import {AdminAccessCheckerStorage} from "../storage/AdminAccessCheckerStorage.sol";

/**
 * @title AdminAccessChecker
 * @dev This abstract contract provides access control mechanisms to restrict the execution of specific functions
 * to authorized protocol administrators and platform administrators.
 * @dev Updated to use ERC-7201 namespaced storage for upgradeable contracts
 */
abstract contract AdminAccessChecker is Context {

    /**
     * @dev Throws when the caller is not authorized.
     */
    error AdminAccessCheckerUnauthorized();

    /**
     * @dev Internal initializer function for AdminAccessChecker
     * @param globalParams The IGlobalParams contract instance
     */
    function __AccessChecker_init(IGlobalParams globalParams) internal {
        AdminAccessCheckerStorage.Storage storage $ = AdminAccessCheckerStorage._getAdminAccessCheckerStorage();
        $.globalParams = globalParams;
    }

    /**
     * @dev Returns the stored GLOBAL_PARAMS for internal use
     */
    function _getGlobalParams() internal view returns (IGlobalParams) {
        AdminAccessCheckerStorage.Storage storage $ = AdminAccessCheckerStorage._getAdminAccessCheckerStorage();
        return $.globalParams;
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
     * @dev Internal function to check if the sender is the protocol administrator.
     * If the sender is not the protocol admin, it reverts with AdminAccessCheckerUnauthorized error.
     */
    function _onlyProtocolAdmin() private view {
        AdminAccessCheckerStorage.Storage storage $ = AdminAccessCheckerStorage._getAdminAccessCheckerStorage();
        if (_msgSender() != $.globalParams.getProtocolAdminAddress()) {
            revert AdminAccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.
     * @param platformHash The unique identifier of the platform.
     */
    function _onlyPlatformAdmin(bytes32 platformHash) private view {
        AdminAccessCheckerStorage.Storage storage $ = AdminAccessCheckerStorage._getAdminAccessCheckerStorage();
        if (_msgSender() != $.globalParams.getPlatformAdminAddress(platformHash)) {
            revert AdminAccessCheckerUnauthorized();
        }
    }
}
