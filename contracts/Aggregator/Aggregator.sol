// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Interface/ICampaignInfoFactory.sol";
import "../Interface/ICampaignRegistry.sol";


contract Aggregator {
    mapping(address => address) campaignOwners;
    address campaignInfoFactory;
    address campaignRegistry;

    function createCampaign(
        address _creator,
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        uint256 _earlyPledgeAmount
    ) external {
        campaignOwners[]
        ICampaignInfoFactory(campaignInfoFactory).createCampaign(_creator, _identifier, _originPlatform, _creatorUrl, _reachPlatform, _earlyPledgeAmount);
        address infoAddress = ICampaignRegistry(campaignRegisty).getCampaignInfoAddress();
        campaignOwners[infoAddress] = msg.sender;
    }

}
