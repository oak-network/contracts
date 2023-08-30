// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IGlobalParams.sol";

contract GlobalParams is IGlobalParams, Ownable, Pausable {
    using Counters for Counters.Counter;

    address private s_protocolAdminAddress;
    address private s_tokenAddress;
    uint256 private s_protocolFeePercent;
    mapping(bytes32 => bool) private s_platformIsListed;
    mapping(bytes32 => address) private s_platformAdminAddress;
    mapping(bytes32 => uint256) s_platformFeePercent;

    Counters.Counter private s_numberOfListedPlatforms;

    error GlobalParamsInvalidAddress(address account);
    error GlobalParamsPlatformNotListed(
        bytes32 platformBytes,
        address platformAdminAddress
    );
    error GlobalParamsPlatformAlreadyListed(bytes32 platformBytes);
    error GlobalParamsPlatformAdminNotSet(bytes32 platformBytes);
    error GlobalParamesFeePercentIsZero(bytes32 platformBytes);


    constructor(
        address protocolAdminAddress,
        address tokenAddress,
        uint256 protocolFeePercent
    ) {
        s_protocolAdminAddress = protocolAdminAddress;
        s_tokenAddress = tokenAddress;
        s_protocolFeePercent = protocolFeePercent;
    }

    modifier notAddressZero(address account) {
        _checkIfAddressZero(account);
        _;
    }

    function checkIfplatformIsListed(
        bytes32 platformBytes
    ) external view override returns (bool) {
        if (s_platformIsListed[platformBytes]) {
            return true;
        } else return false;
    }

    function getPlatformAdminAddress(
        bytes32 platformBytes
    ) external view override returns (address account) {
        account = s_platformAdminAddress[platformBytes];
        if (account == address(0)) {
            revert GlobalParamsPlatformAdminNotSet(platformBytes);
        }
    }

    function getNumberOfListedPlatforms()
        external
        view
        override
        returns (uint256)
    {
        return s_numberOfListedPlatforms.current();
    }

    function getProtocolAdminAddress()
        external
        view
        override
        returns (address)
    {
        return s_protocolAdminAddress;
    }

    function getTokenAddress() external view override returns (address) {
        return s_tokenAddress;
    }

    function getProtocolFeePercent() external view override returns (uint256) {
        return s_protocolFeePercent;
    }

    function getPlatformFeePercent(bytes32 platformBytes) external view override returns (uint256) {
        if (s_platformFeePercent[platformBytes] == 0) {
            revert GlobalParamesFeePercentIsZero(platformBytes);
        }
    }

    function _checkIfAddressZero(address account) internal pure {
        if (account == address(0)) {
            revert GlobalParamsInvalidAddress(account);
        }
    }

    function enlistPlatform(
        bytes32 platformBytes,
        address platformAdminAddress,
        uint256 platformFeePercent
    ) external onlyOwner {
        if (s_platformIsListed[platformBytes]) {
            revert GlobalParamsPlatformAlreadyListed(platformBytes);
        } else {
            s_platformIsListed[platformBytes] = true;
            s_platformAdminAddress[platformBytes] = platformAdminAddress;
            s_platformFeePercent[platformBytes] = platformFeePercent;
            s_numberOfListedPlatforms.increment();
        }
    }

    function delistPlatform(bytes32 platformBytes) external onlyOwner {
        if (s_platformIsListed[platformBytes]) {
            s_platformIsListed[platformBytes] = false;
            s_platformAdminAddress[platformBytes] = address(0);
            s_platformFeePercent[platformBytes] = 0;
            s_numberOfListedPlatforms.decrement();
        } else {
            revert GlobalParamsPlatformNotListed(platformBytes, address(0));
        }
    }

    function updateProtocolAdminAddress(
        address protocolAdminAddress
    ) external override onlyOwner notAddressZero(protocolAdminAddress) {
        s_protocolAdminAddress = protocolAdminAddress;
    }

    function updateTokenAddress(
        address tokenAddress
    ) external override onlyOwner notAddressZero(tokenAddress) {
        s_tokenAddress = tokenAddress;
    }

    function updateProtocolFeePercent(
        uint256 protocolFeePercent
    ) external override onlyOwner {
        s_protocolFeePercent = protocolFeePercent;
    }

    function updatePlatformAdminAddress(
        bytes32 platformBytes,
        address platformAdminAddress
    ) external override onlyOwner notAddressZero(platformAdminAddress) {
        if (s_platformIsListed[platformBytes]) {
            s_platformAdminAddress[platformBytes] = platformAdminAddress;
        } else
            revert GlobalParamsPlatformNotListed(
                platformBytes,
                platformAdminAddress
            );
    }
}
