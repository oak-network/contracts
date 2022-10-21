// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignTreasury.sol";
import "./CampaignRegistry.sol";

contract CampaignInfo is Ownable {

    struct Campaign {
        bytes8 identifier;
        bytes8 originPlatform;
        uint64 goalAmount;
        uint64 startsAt;
        uint64 createdAt;
        uint64 deadline;
        bytes16 creatorUrl;
        bytes8[] reachPlatforms;
    }

    Campaign campaign;
    address registryAddress;

    mapping(bytes32 => address) treasuryAddresses;
    
    constructor(       
        bytes8 _identifier,
        bytes8 _originPlatform,
        uint64 _goalAmount,
        uint64 _startsAt,
        uint64 _deadline,
        bytes16 _creatorUrl,
        bytes8[] _reachPlatforms
    )
    {
        require(_startsAt + 30 days < _deadline);
        campaign.identifier = _identifier;
        campaign.originPlatform = _originPlatform;
        campaign.goalAmount = _goalAmount;
        campaign.startsAt = _startsAt;
        campaign.deadline = _deadline;
        campaign.creatorUrl = _creatorUrl;
        campaign.reachPlatforms = _reachPlatforms;
    }
    
    function getTotalPledgeAmount() public view returns(uint256 pledgedAmount) {
        for (uint256 i = 0; i < campaign.multilistClients.length; i++) {
            pledgedAmount = pledgedAmount + 
            //CampaignTreasury(treasuryAddresses[campaign.multilistClients[i]]).getPledgeAmount();
            CampaignTreasury(CampaignRegistry(registryAddress).getTreasuryAddress(address(this), campaign.multilistClients[i])).getPledgeAmount();
        }
    }

    function getTotalCollectableByCreator() public view returns(uint256 totalCollectable) {

    }

    function editLaunchTime(uint256 launchTime) onlyOwner external {
        require(launchTime + 30 days < campaign.deadline);
        campaign.launchTime = launchTime;
    }

    function editDeadline(uint256 deadline) onlyOwner external {
        require(deadline - 30 days > campaign.launchTime);
        campaign.deadline = deadline;
    }

    function editCampaignDescription(bytes32 language, bytes32 creatorName, bytes32 campaignDesc) onlyOwner external {
        CampaignDescription storage campDesc = campaignDescription[language];
        campDesc.creatorName = creatorName;
        campDesc.campaignDesc = campaignDesc;
    }

    function setCampaignDescription(bytes32 language, bytes32 creatorName, bytes32 campaignDesc) onlyOwner external {
        CampaignDescription storage campDesc = campaignDescription[language];
        campDesc.creatorName = creatorName;
        campDesc.campaignDesc = campaignDesc;        
    }

    function setTreasuryAddress(bytes32 clientId, address treasuryAddress) onlyOwner external {
        treasuryAddresses[clientId] = treasuryAddress;
    } 

    function setFeePercentForClient(bytes32 clientId, uint256 feePercent) onlyOwner external {
        clientFeePercent[clientId] = feePercent; 
    }
}