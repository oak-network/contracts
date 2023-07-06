// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignInfo.sol";
import "./Interface/ICampaignRegistry.sol";
import "./Interface/ICampaignInfoFactory.sol";

contract CampaignInfoFactory is ICampaignInfoFactory {

    CampaignInfo newCampaignInfo;
    address registry;

    constructor(address _registry) {
        registry = _registry;
    }

    function createCampaign(
        address _creator,
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        uint256 _earlyPledgeAmount
    ) external {
        newCampaignInfo = new CampaignInfo(
            _identifier,
            _creatorUrl,
            registry,
            _creator, 
            _earlyPledgeAmount,
            _originPlatform,
            _reachPlatform
        );
        address newCampaignAddress = address(newCampaignInfo);
        require(newCampaignAddress != address(0));

        ICampaignRegistry(registry).setCampaignInfoAddress(
            _identifier,
            newCampaignAddress
        );

        emit campaignCreation(_identifier, newCampaignAddress);
    }
}
