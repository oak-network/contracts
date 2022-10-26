// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignTreasury.sol";
import "./CampaignRegistry.sol";

contract CampaignInfo is Ownable {

    struct Campaign {
        string identifier;
        bytes32 originPlatform;
        uint64 goalAmount;
        uint64 startsAt;
        uint64 createdAt;
        uint64 deadline;
        string creatorUrl;
        bytes32[] reachPlatforms;
    }

    Campaign campaign;
    address registryAddress;

    mapping(bytes32 => address) treasuryAddresses;
    
    constructor(       
        string memory  _identifier,
        bytes32 _originPlatform,
        uint64 _goalAmount,
        uint64 _startsAt,
        uint64 _deadline,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatforms,
        address _registryAddress
    )
    {
        require(_startsAt + 30 days < _deadline);
        campaign.identifier = _identifier;
        campaign.originPlatform = _originPlatform;
        campaign.goalAmount = _goalAmount;
        campaign.startsAt = _startsAt;
        campaign.createdAt = uint64(block.timestamp);
        campaign.deadline = _deadline;
        campaign.creatorUrl = _creatorUrl;
        campaign.reachPlatforms = _reachPlatforms;
        registryAddress = _registryAddress;
    }

    modifier onlyRegistryOwner {
        require(msg.sender == CampaignRegistry(registryAddress).owner());
        _;
    }
    
    function getTotalPledgeAmount() public view returns(uint256 pledgedAmount) {
        bytes32[] memory tempReachPlatforms = campaign.reachPlatforms;
        uint256 length = campaign.reachPlatforms.length;
        for (uint256 i = 0; i < length; i++) {
            if(treasuryAddresses[tempReachPlatforms[i]] != address(0)) {
                pledgedAmount = pledgedAmount + 
                CampaignTreasury(treasuryAddresses[tempReachPlatforms[i]]).getPledgeAmount();
            }
        }
    }

    function getTreasuryAddress(bytes32 clientId) public view returns(address) {
        return treasuryAddresses[clientId];
    }

    function editStartAt(uint64 startsAt) onlyRegistryOwner external {
        require(startsAt + 30 days < campaign.deadline);
        campaign.startsAt = startsAt;
    }

    function editDeadline(uint64 deadline) onlyRegistryOwner external {
        require(deadline - 30 days > campaign.startsAt);
        campaign.deadline = deadline;
    }

    function setTreasuryAddress(bytes32 clientId, address treasuryAddress) onlyRegistryOwner external {
        treasuryAddresses[clientId] = treasuryAddress;
    } 
}