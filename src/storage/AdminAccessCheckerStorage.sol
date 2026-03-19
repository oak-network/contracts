// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IGlobalParams} from "../interfaces/IGlobalParams.sol";

/**
 * @title AdminAccessCheckerStorage
 * @notice Storage contract for AdminAccessChecker using ERC-7201 namespaced storage
 * @dev This contract contains the storage layout and accessor functions for AdminAccessChecker
 */
library AdminAccessCheckerStorage {
    /// @custom:storage-location erc7201:oaknetwork.storage.AdminAccessChecker
    struct Storage {
        IGlobalParams globalParams;
    }

    // keccak256(abi.encode(uint256(keccak256("oaknetwork.storage.AdminAccessChecker")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ADMIN_ACCESS_CHECKER_STORAGE_LOCATION =
        0x7608703513d219ecdd1e84aa0951e3c83cfe601f872259e1340c97792f4b8200;

    function _getAdminAccessCheckerStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := ADMIN_ACCESS_CHECKER_STORAGE_LOCATION
        }
    }
}
