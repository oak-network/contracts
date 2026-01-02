// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TreasuryFactoryStorage
 * @notice Storage contract for TreasuryFactory using ERC-7201 namespaced storage
 * @dev This contract contains the storage layout and accessor functions for TreasuryFactory
 */
library TreasuryFactoryStorage {
    /// @custom:storage-location erc7201:ccprotocol.storage.TreasuryFactory
    struct Storage {
        mapping(bytes32 => mapping(uint256 => address)) implementationMap;
        mapping(address => bool) approvedImplementations;
    }

    // keccak256(abi.encode(uint256(keccak256("ccprotocol.storage.TreasuryFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TREASURY_FACTORY_STORAGE_LOCATION =
        0x96b7de8c171ef460648aea35787d043e89feb6b6de2623a1e6f17a91b9c9e900;

    function _getTreasuryFactoryStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := TREASURY_FACTORY_STORAGE_LOCATION
        }
    }
}
