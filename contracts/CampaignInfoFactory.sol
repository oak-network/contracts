// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";
import "./CampaignRegistry.sol";

contract CampaignInfoFactory is Ownable {
    using Counters for Counters.Counter;

    event campaignCreation(address indexed campaignAddress, uint256 indexed campaignId);

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
        string memory _identifier,
        bytes32 _originPlatform,
        uint64 _goalAmount,
        uint64 _startsAt,
        uint64 _deadline,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatforms
    ) external onlyOwner returns(address, uint256)
    {
        require(initialized);
        newCampaignInfo = new CampaignInfo(_identifier, _originPlatform, _goalAmount, _startsAt, _deadline, _creatorUrl, _reachPlatforms, campaignRegistry);
        require(address(newCampaignInfo) != address(0));

        uint256 newCampaignId = campaignId.current();
        address newCampaignAddress = address(newCampaignInfo);

        CampaignRegistry(campaignRegistry).setCampaignInfoAddress
        (
            newCampaignId, 
            newCampaignAddress
        );
        campaignId.increment();
        
        emit campaignCreation(newCampaignAddress, newCampaignId);
        
        return (newCampaignAddress, newCampaignId);
    }

}