// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CampaignInfo is Ownable {
    address[] treasuryAddresses;

    struct CampaignDescription {
        bytes32 creatorName;
        bytes32 campaignDesc;
    }

    struct Campaign {
        uint256 creatorId;
        uint256 goal;
        uint256 launchTime;
        uint256 deadline;
        bytes32[] multilistClients;
    }

    Campaign campaign;

    mapping(bytes32 => CampaignDescription) campaignDescription;
    mapping(bytes32 => uint256) clientFeePercent;

    constructor(
        uint256 creatorId, 
        uint256 goal, 
        uint256 launchTime, 
        uint256 deadline,
        bytes32[] memory multilistClients
    )
    {
        require(launchTime + 30 days < campaign.deadline);
        campaign.creatorId = creatorId;
        campaign.goal = goal;
        campaign.launchTime = launchTime;
        campaign.deadline = deadline;
        campaign.multilistClients = multilistClients;
    }

    function getTotalPledgeAmount() public view returns(uint256 pledgedAmount) {
    
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

    function setTreasuryAddress(address treasuryAddress) onlyOwner external {
        treasuryAddresses.push(treasuryAddress);
    } 

    function setFeePercentForClient(bytes32 clientId, uint256 feePercent) onlyOwner external {
        clientFeePercent[clientId] = feePercent; 
    }
}