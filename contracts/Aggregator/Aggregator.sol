// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Interface/ICampaignInfoFactory.sol";
import "../Interface/ICampaignRegistry.sol";
import "../Interface/ICampaignInfo.sol";
import "../CampaignTreasury.sol";

contract Aggregator {
    mapping(address => address) campaignOwners;
    address campaignInfoFactory;
    address campaignRegistry;

    CampaignTreasury newTreasury;

    function initialize(
        address _campaignInfoFactory,
        address _campaignRegisty
    ) external {
        campaignInfoFactory = _campaignInfoFactory;
        campaignRegistry = _campaignRegisty;
    }

    function createCampaign(
        address _creator,
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        uint256 _earlyPledgeAmount
    ) external {
        ICampaignInfoFactory(campaignInfoFactory).createCampaign(
            _creator,
            _identifier,
            _originPlatform,
            _creatorUrl,
            _reachPlatform,
            _earlyPledgeAmount
        );
        address infoAddress = ICampaignRegistry(campaignRegistry)
            .getCampaignInfoAddress(_identifier);
        campaignOwners[infoAddress] = msg.sender;
    }

    function setTreasury(
        address campaignInfo,
        bytes32 platform,
        address platformWallet,
        address token
    ) external {
        newTreasury = new CampaignTreasury(
            campaignRegistry,
            campaignInfo,
            platform
        );
        address treasury = address(newTreasury);
        ICampaignInfo(campaignInfo).setPlatformInfo(
            platform,
            platformWallet,
            treasury,
            token
        );
    }
}
