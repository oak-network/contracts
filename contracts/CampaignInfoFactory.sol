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
        bytes8 _identifier,
        bytes8 _originPlatform,
        uint64 _goalAmount,
        uint64 _startsAt,
        uint64 _deadline,
        bytes16 _creatorUrl,
        bytes8[] memory _reachPlatforms
    ) external onlyOwner
    {
        require(initialized);
        newCampaignInfo = new CampaignInfo(_identifier, _originPlatform, _goalAmount, _startsAt, _deadline, _creatorUrl, _reachPlatforms);
        require(address(newCampaignInfo) != address(0));
        CampaignRegistry(campaignRegistry).setCampaignInfoAddress
        (
            campaignId.current(), 
            address(newCampaignInfo)
        );
        campaignId.increment();
    }

}