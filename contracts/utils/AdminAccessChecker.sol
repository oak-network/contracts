// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/IGlobalParams.sol";

/**
 * @title AdminAccessChecker
 * @dev This abstract contract provides access control mechanisms to restrict the execution of specific functions
 * to authorized protocol administrators and platform administrators.
 */
abstract contract AdminAccessChecker {
    // Immutable reference to the IGlobalParams contract, which manages global parameters and admin addresses.
    IGlobalParams internal immutable GLOBAL_PARAMS;

    /**
     * @dev Throws when the caller is not authorized.
     */    
    error AdminAccessCheckerUnauthorized();

    /**
     * @dev Constructor to initialize the contract with the address of the global parameters contract.
     * @param globalParams The address of the IGlobalParams contract.
     */
    constructor(address globalParams) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
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
     * @dev Internal function to check if the sender is the protocol administrator.
     * If the sender is not the protocol admin, it reverts with AdminAccessCheckerUnauthorized error.
     */
    function _checkIfProtocolAdmin() private view {
        if (msg.sender != GLOBAL_PARAMS.getProtocolAdminAddress()) {
            revert AdminAccessCheckerUnauthorized();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.
     * @param platformBytes The unique identifier of the platform.
     */
    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (
            msg.sender != GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes)
        ) {
            revert AdminAccessCheckerUnauthorized();
        }
    }
}
