// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";
import "./CampaignRegistry.sol";

contract CampaignInfoFactory is Ownable {

    event campaignCreation(string identifier, address indexed campaignInfoAddress);

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
        uint64 _launchTime,
        uint64 _deadline,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform
    ) external onlyOwner returns(address)
    {
        require(initialized);
        newCampaignInfo = new CampaignInfo(_identifier, _originPlatform, _goalAmount, _launchTime, _deadline, _creatorUrl, _reachPlatform, campaignRegistry);
        require(address(newCampaignInfo) != address(0));

        address newCampaignAddress = address(newCampaignInfo);

        CampaignRegistry(campaignRegistry).setCampaignInfoAddress
        (
            _identifier, 
            newCampaignAddress
        );
        
        emit campaignCreation(_identifier, newCampaignAddress);
        
        return newCampaignAddress;
    }

}