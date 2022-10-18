// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";
import "./CampaignRegistry.sol";

contract CampaignInfoFactory is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public campaignId;
    CampaignInfo newCampaignInfo;
    address campaignRegistry;
    bool initialized;
    
    mapping(uint256 => address) public campaignIdToAddress;

    function setRegistry(address _campaignRegistry) public onlyOwner {
        campaignRegistry = _campaignRegistry;
        initialized = true;
    }

    function createCampaign(
        uint256 creatorId, 
        uint256 goal, 
        uint256 launchTime, 
        uint256 deadline, 
        bytes32[] memory multilistClients
    ) external onlyOwner
    {
        require(initialized);
        newCampaignInfo = new CampaignInfo(creatorId, goal, launchTime, deadline, multilistClients);
        require(address(newCampaignInfo) != address(0));
        CampaignRegistry(campaignRegistry).setCampaignInfoAddress
        (
            campaignId.current(), 
            address(newCampaignInfo)
        );
        campaignId.increment();
    }

}