// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
   
contract CampaignInfo is Ownable, Pausable {
    address public protocolAdminAddress;
    address public tokenAddress;
    uint256 public protocolFeePercent;
    mapping(bytes32 => bool) private platformIsListed;
    mapping(bytes32 => address) private platformAdminAddress;

    constructor(address _protocolAdminAddress, address _tokenAddress, uint256 _protocolFeePercent) {
        protocolAdminAddress = _protocolAdminAddress;
        tokenAddress = _tokenAddress;
        protocolFeePercent = _protocolFeePercent;
    }

    function updateProtocolAdminAddress(address _protocolAdminAddress) external onlyOwner {
        protocolAdminAddress = _protocolAdminAddress;
    }

    function updateTokenAddress(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    function updateProtocolFeePercent(uint256 _protocolFeePercent) external onlyOwner {
        protocolFeePercent = _protocolFeePercent;
    }

    function updatePlatformAdminAddress(bytes32 _platformBytes, address _platformAdminAddress) external onlyOwner {
        platformAdminAddress[_platformBytes] = _platformAdminAddress;
    }
}
