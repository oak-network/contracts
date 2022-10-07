// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";

contract CampaignInfoFactory is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter campaignId;
    CampaignInfo newCampaignInfo;
    
    mapping(uint256 => address) campaignIdToAddress;

}