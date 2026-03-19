// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TreasuryFactoryStorage
 * @notice Storage contract for TreasuryFactory using ERC-7201 namespaced storage
 * @dev This contract contains the storage layout and accessor functions for TreasuryFactory
 */
library TreasuryFactoryStorage {
    /// @custom:storage-location erc7201:oaknetwork.storage.TreasuryFactory
    struct Storage {
        mapping(bytes32 => mapping(uint256 => address)) implementationMap;
        mapping(address => bool) approvedImplementations;
    }

    // keccak256(abi.encode(uint256(keccak256("oaknetwork.storage.TreasuryFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TREASURY_FACTORY_STORAGE_LOCATION =
        0xac5f58af051caf3154d38fdfab53396f7d32e9ef6bb41b866435ed38c5426600;

    function _getTreasuryFactoryStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := TREASURY_FACTORY_STORAGE_LOCATION
        }
    }
}
