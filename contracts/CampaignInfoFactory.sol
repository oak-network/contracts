// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignInfo.sol";
import "./CampaignRegistry.sol";

contract CampaignInfoFactory {
    event campaignCreation(
        string identifier,
        address indexed campaignInfoAddress
    );

    CampaignInfo newCampaignInfo;
    address campaignRegistry;

    constructor(address _registry) {
        campaignRegistry = _registry;
    }

    function createCampaign(
        address _creator,
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform
    ) external {
        newCampaignInfo = new CampaignInfo(
            _identifier,
            _originPlatform,
            _creatorUrl,
            _reachPlatform,
            campaignRegistry,
            _creator
        );
        address newCampaignAddress = address(newCampaignInfo);
        require(newCampaignAddress != address(0));

        CampaignRegistry(campaignRegistry).setCampaignInfoAddress(
            _identifier,
            newCampaignAddress
        );

        emit campaignCreation(_identifier, newCampaignAddress);
    }
}
