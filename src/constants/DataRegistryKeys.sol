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
    bytes32 public constant MAX_PAYMENT_EXPIRATION = keccak256("maxPaymentExpiration");
    bytes32 public constant CAMPAIGN_LAUNCH_BUFFER = keccak256("campaignLaunchBuffer");
    bytes32 public constant MINIMUM_CAMPAIGN_DURATION = keccak256("minimumCampaignDuration");

    /**
     * @notice Generates a namespaced registry key scoped to a specific platform.
     * @param baseKey The base registry key.
     * @param platformHash The identifier of the platform.
     * @return platformKey The platform-scoped registry key.
     */
    function scopedToPlatform(bytes32 baseKey, bytes32 platformHash) internal pure returns (bytes32 platformKey) {
        platformKey = keccak256(abi.encode(baseKey, platformHash));
    }
}
