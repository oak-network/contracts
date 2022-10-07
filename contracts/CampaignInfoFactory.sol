// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";

contract CampaignInfoFactory is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public campaignId;
    CampaignInfo newCampaignInfo;
    
    mapping(uint256 => address) public campaignIdToAddress;

    function createCampaign(
        uint256 creatorId, 
        uint256 goal, 
        uint256 launchTime, 
        uint256 deadline, 
        bytes32[] memory multilistClients
    ) external onlyOwner
    {
        newCampaignInfo = new CampaignInfo(creatorId, goal, launchTime, deadline, multilistClients);
        campaignIdToAddress[campaignId.current()] = address(newCampaignInfo);
        campaignId.increment();
    }

}