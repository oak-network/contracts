// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title DataRegistryKeys
 * @notice Centralized storage for all dataRegistry keys used in GlobalParams
 * @dev This library provides a single source of truth for all dataRegistry keys
 * to ensure consistency across contracts and prevent key collisions.
 */
library DataRegistryKeys {
    // Time-related keys
    bytes32 public constant BUFFER_TIME = keccak256("bufferTime");
}
