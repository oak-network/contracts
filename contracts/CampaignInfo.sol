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
        bytes8[] memory _reachPlatforms
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
        bytes8[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256 length = campaign.reachPlatforms.length;
        for (uint256 i = 0; i < length; i++) {
            if(treasuryAddresses[tempReachPlatforms[i]] != address(0)) {
                pledgedAmount = pledgedAmount + 
                CampaignTreasury(treasuryAddresses[tempReachPlatforms[i]]).getPledgeAmount();
            }
        }
    }

    function getTotalCollectableByCreator() public view returns(uint256 totalCollectable) {

    }

    function getTreasuryAddress(bytes32 clientId) public view returns(address) {
        return treasuryAddresses[clientId];
    }

    function editStartAt(uint64 startsAt) onlyOwner external {
        require(startsAt + 30 days < campaign.deadline);
        campaign.startsAt = startsAt;
    }

    function editDeadline(uint64 deadline) onlyOwner external {
        require(deadline - 30 days > campaign.startsAt);
        campaign.deadline = deadline;
    }

    function setTreasuryAddress(bytes32 clientId, address treasuryAddress) onlyOwner external {
        treasuryAddresses[clientId] = treasuryAddress;
    } 

    // function setFeePercentForClient(bytes32 clientId, uint256 feePercent) onlyOwner external {
    //     clientFeePercent[clientId] = feePercent; 
    // }
}