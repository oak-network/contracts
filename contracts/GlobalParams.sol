// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Interface/IGlobalParams.sol";

contract GlobalParams is IGlobalParams, Ownable, Pausable {
    using Counters for Counters.Counter;

    error GlobalParamsInvalidAddress(address account);
    error GlobalParamsPlatformNotListed(
        bytes32 platformBytes,
        address platformAdminAddress
    );
    error GlobalParamsPlatformAlreadyListed(bytes32 platformBytes);
    error GlobalParamsPlatformAdminNotSet(bytes32 platformBytes);

    Counters.Counter private numberOfListedPlatforms;

    address public protocolAdminAddress;
    address public tokenAddress;
    uint256 public protocolFeePercent;
    mapping(bytes32 => bool) private platformIsListed;
    mapping(bytes32 => address) private platformAdminAddress;

    constructor(
        address _protocolAdminAddress,
        address _tokenAddress,
        uint256 _protocolFeePercent
    ) {
        protocolAdminAddress = _protocolAdminAddress;
        tokenAddress = _tokenAddress;
        protocolFeePercent = _protocolFeePercent;
    }

    modifier notAddressZero(address _account) {
        _checkIfAddressZero(_account);
        _;
    }

    function checkIfplatformIsListed(
        bytes32 _platformBytes
    ) external view override returns (bool) {
        if (platformIsListed[_platformBytes]) {
            return true;
        } else return false;
    }

    function getPlatformAdminAddress(
        bytes32 _platformBytes
    ) external view override returns (address account) {
        account = platformAdminAddress[_platformBytes];
        if (account == address(0)) {
            revert GlobalParamsPlatformAdminNotSet(_platformBytes);
        }
    }

    function _checkIfAddressZero(address _account) internal pure {
        if (_account == address(0)) {
            revert GlobalParamsInvalidAddress(_account);
        }
    }

    function enlistPlatform(
        bytes32 _platformBytes,
        address _platformAdminAddress
    ) external {
        if (platformIsListed[_platformBytes]) {
            revert GlobalParamsPlatformAlreadyListed(_platformBytes);
        } else {
            platformIsListed[_platformBytes] = true;
            platformAdminAddress[_platformBytes] = _platformAdminAddress;
            numberOfListedPlatforms.increment();
        }
    }

    function delistPlatform(bytes32 _platformBytes) external {
        if (platformIsListed[_platformBytes]) {
            platformIsListed[_platformBytes] = false;
            platformAdminAddress[_platformBytes] = address(0);
            numberOfListedPlatforms.decrement();
        } else {
            revert GlobalParamsPlatformNotListed(_platformBytes, address(0));
        }
    }

    function updateProtocolAdminAddress(
        address _protocolAdminAddress
    ) external override onlyOwner notAddressZero(_protocolAdminAddress) {
        protocolAdminAddress = _protocolAdminAddress;
    }

    function updateTokenAddress(
        address _tokenAddress
    ) external override onlyOwner notAddressZero(_tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function updateProtocolFeePercent(
        uint256 _protocolFeePercent
    ) external override onlyOwner {
        protocolFeePercent = _protocolFeePercent;
    }

    function updatePlatformAdminAddress(
        bytes32 _platformBytes,
        address _platformAdminAddress
    ) external override onlyOwner notAddressZero(_platformAdminAddress) {
        if (platformIsListed[_platformBytes]) {
            platformAdminAddress[_platformBytes] = _platformAdminAddress;
        } else
            revert GlobalParamsPlatformNotListed(
                _platformBytes,
                _platformAdminAddress
            );
    }
}
