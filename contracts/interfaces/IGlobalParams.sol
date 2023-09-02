// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IGlobalParams {
    function checkIfplatformIsListed(
        bytes32 _platformBytes
    ) external view returns (bool);

    function getPlatformAdminAddress(
        bytes32 _platformBytes
    ) external view returns (address);

    function getNumberOfListedPlatforms() external view returns (uint256);

    function getProtocolAdminAddress() external view returns (address);

    function getTokenAddress() external view returns (address);

    function getProtocolFeePercent() external view returns (uint256);

    function getPlatformData(
        bytes32 platformDataKey
    ) external view returns (bytes32 platformDataValue);

    function getPlatformDataOwner(
        bytes32 platformDataKey
    ) external view returns (bytes32 platformBytes);

    function getPlatformFeePercent(
        bytes32 platformBytes
    ) external view returns (uint256);

    function updateProtocolAdminAddress(address _protocolAdminAddress) external;

    function updateTokenAddress(address _tokenAddress) external;

    function updateProtocolFeePercent(uint256 _protocolFeePercent) external;

    function updatePlatformAdminAddress(
        bytes32 _platformBytes,
        address _platformAdminAddress
    ) external;
}
