// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title CrossChainRegistryKeys
 * @notice Registry key helpers for cross-chain configuration stored in GlobalParams.
 */
library CrossChainRegistryKeys {
    bytes32 internal constant EXECUTOR = keccak256("crosschain.executor");
    bytes32 internal constant CHAIN_SUPPORTED = keccak256("crosschain.chainSupported");
    bytes32 internal constant CHAIN_PAUSED = keccak256("crosschain.chainPaused");
    bytes32 internal constant BRIDGE_ADAPTER = keccak256("crosschain.bridgeAdapter");
    bytes32 internal constant ALLOWED_SENDER = keccak256("crosschain.allowedSender");
    bytes32 internal constant CCIP_SELECTOR = keccak256("crosschain.ccipSelector");
    bytes32 internal constant LZ_EID = keccak256("crosschain.lzEid");
    bytes32 internal constant STARGATE_FOR_TOKEN = keccak256("crosschain.stargateForToken");

    /// @notice Key for the global cross-chain executor address.
    function executor() internal pure returns (bytes32) {
        return EXECUTOR;
    }

    /// @notice Key for chain support flag.
    function chainSupported(uint256 chainId) internal pure returns (bytes32) {
        return keccak256(abi.encode(CHAIN_SUPPORTED, chainId));
    }

    /// @notice Key for chain paused flag.
    function chainPaused(uint256 chainId) internal pure returns (bytes32) {
        return keccak256(abi.encode(CHAIN_PAUSED, chainId));
    }

    /// @notice Key for a bridge adapter address.
    function bridgeAdapter(bytes32 bridgeId) internal pure returns (bytes32) {
        return keccak256(abi.encode(BRIDGE_ADAPTER, bridgeId));
    }

    /// @notice Key for allowed source sender per chain and bridge.
    function allowedSender(uint256 chainId, bytes32 bridgeId) internal pure returns (bytes32) {
        return keccak256(abi.encode(ALLOWED_SENDER, chainId, bridgeId));
    }

    /// @notice Key for CCIP chain selector mapping.
    function ccipSelector(uint256 chainId) internal pure returns (bytes32) {
        return keccak256(abi.encode(CCIP_SELECTOR, chainId));
    }

    /// @notice Key for LayerZero eid mapping.
    function lzEid(uint256 chainId) internal pure returns (bytes32) {
        return keccak256(abi.encode(LZ_EID, chainId));
    }

    /// @notice Key for Stargate contract address per destination token.
    function stargateForToken(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(STARGATE_FOR_TOKEN, token));
    }
}
