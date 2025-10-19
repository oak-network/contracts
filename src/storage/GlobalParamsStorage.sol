// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Counters} from "../utils/Counters.sol";

/**
 * @title GlobalParamsStorage
 * @notice Storage contract for GlobalParams using ERC-7201 namespaced storage
 * @dev This contract contains the storage layout and accessor functions for GlobalParams
 */
library GlobalParamsStorage {
    using Counters for Counters.Counter;

    /// @custom:storage-location erc7201:ccprotocol.storage.GlobalParams
    struct Storage {
        address protocolAdminAddress;
        uint256 protocolFeePercent;
        mapping(bytes32 => bool) platformIsListed;
        mapping(bytes32 => address) platformAdminAddress;
        mapping(bytes32 => uint256) platformFeePercent;
        mapping(bytes32 => bytes32) platformDataOwner;
        mapping(bytes32 => bool) platformData;
        mapping(bytes32 => bytes32) dataRegistry;
        mapping(bytes32 => address[]) currencyToTokens;
        Counters.Counter numberOfListedPlatforms;
    }

    // keccak256(abi.encode(uint256(keccak256("ccprotocol.storage.GlobalParams")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GLOBAL_PARAMS_STORAGE_LOCATION = 
        0x83d0145f7c1378f10048390769ec94f999b3ba6d94904b8fd7251512962b1c00;

    function _getGlobalParamsStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := GLOBAL_PARAMS_STORAGE_LOCATION
        }
    }
}
