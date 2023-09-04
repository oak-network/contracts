// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/IGlobalParams.sol";

abstract contract AdminAccessChecker {
    IGlobalParams internal immutable GLOBAL_PARAMS;
    error AdminAccessCheckerUnauthorized();

    constructor(address globalParams) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
    }

    modifier onlyProtocolAdmin() {
        _checkIfProtocolAdmin();
        _;
    }

    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    function _checkIfProtocolAdmin() private view {
        if (msg.sender != GLOBAL_PARAMS.getProtocolAdminAddress()) {
            revert AdminAccessCheckerUnauthorized();
        }
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (msg.sender != GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes)) {
            revert AdminAccessCheckerUnauthorized();
        }
    }
}
