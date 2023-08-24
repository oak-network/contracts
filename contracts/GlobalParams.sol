// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GlobalParams is Ownable, Pausable {
    error GlobalParamsInvalidAddress(address account);
    error GlobalParamsPlatformNotListed(bytes32 platformBytes, address platformAdminAddress)

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

    function checkIfplatformIsListed(bytes32 _platformBytes) external view returns (bool) {
        if (platformIsListed[_platformBytes]) {
            return true;
        }
        else
            return false;
    }

    function _checkIfAddressZero(address _account) internal pure {
        if (_account == address(0)) {
            revert GlobalParamsInvalidAddress(_account);
        }
    }

    function updateProtocolAdminAddress(
        address _protocolAdminAddress
    ) external onlyOwner notAddressZero(_protocolAdminAddress) {
        protocolAdminAddress = _protocolAdminAddress;
    }

    function updateTokenAddress(
        address _tokenAddress
    ) external onlyOwner notAddressZero(_tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function updateProtocolFeePercent(
        uint256 _protocolFeePercent
    ) external onlyOwner {
        protocolFeePercent = _protocolFeePercent;
    }

    function updatePlatformAdminAddress(
        bytes32 _platformBytes,
        address _platformAdminAddress
    ) external onlyOwner {
        if (platformIsListed[_platformBytes]) {
            platformAdminAddress[_platformBytes] = _platformAdminAddress;
        }
        else 
            revert GlobalParamsPlatformNotListed(_platformBytes, _platformAdminAddress);
        
    }
}
