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

}