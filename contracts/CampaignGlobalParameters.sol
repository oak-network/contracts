// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
   
contract CampaignInfo is Ownable, Pausable {
    address public protocolAdminAddress;
    address public tokenAddress;
    uint256 public protocolFeePercent;
    mapping(bytes32 => address) public platformAdminAddress;
    mapping(bytes32 => bool) public platformIsListed;

}
