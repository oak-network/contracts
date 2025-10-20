// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {GlobalParamsStorage} from "../storage/GlobalParamsStorage.sol";
import {DataRegistryKeys} from "../constants/DataRegistryKeys.sol";

/**
 * @title DataRegistryHelper
 * @notice Helper contract for accessing dataRegistry values from GlobalParams
 * @dev This contract provides convenient functions to retrieve and validate dataRegistry values
 */
abstract contract DataRegistryHelper {
    
    /**
     * @dev Retrieves a uint256 value from the dataRegistry
     * @param key The dataRegistry key
     * @return value The retrieved value
     */
    function _getRegistryUint(bytes32 key) internal view returns (uint256 value) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        bytes32 valueBytes = $.dataRegistry[key];
        value = uint256(valueBytes);
    }
    
    /**
     * @dev Gets the buffer time from dataRegistry
     * @return bufferTime The buffer time value
     */
    function _getBufferTime() internal view returns (uint256 bufferTime) {
        return _getRegistryUint(DataRegistryKeys.BUFFER_TIME);
    }
}
