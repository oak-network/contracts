// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Interface/ICampaignInfoFactory.sol";
import "../Interface/ICampaignRegistry.sol";
import "../Interface/ICampaignInfo.sol";
import "../Interface/ICampaignContainers.sol";
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

    modifier onlyCampaignOwner(address campaignInfo) {
        //require(campaignOwners[campaignInfo] == msg.sender);
        require(
            address(0x9Aee2Bb8906D3f3B1BB957765eb76a880bc47788) == msg.sender
        );
        _;
    }

    function createCampaign(
        address _creator,
        address _originPlatformAddress,
        address _originPlatformToken,
        uint256 _earlyPledgeAmount,
        bytes32 _originPlatformHex,
        string memory _identifier,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform
    ) external onlyCampaignOwner(_creator) {
        ICampaignInfoFactory(campaignInfoFactory).createCampaign(
            address(this),
            _identifier,
            _originPlatformHex,
            _creatorUrl,
            _reachPlatform,
            _earlyPledgeAmount
        );
        address infoAddress = ICampaignRegistry(campaignRegistry)
            .getCampaignInfoAddress(_identifier);
        campaignOwners[infoAddress] = _creator;
        newTreasury = new CampaignTreasury(
            campaignRegistry,
            infoAddress,
            _originPlatformHex
        );
        address treasury = address(newTreasury);
        ICampaignInfo(infoAddress).setPlatformInfo(
            _originPlatformHex,
            _originPlatformAddress,
            treasury,
            _originPlatformToken
        );
    }

    function setTreasury(
        address campaignInfo,
        bytes32 platform,
        address platformWallet,
        address token
    ) external onlyCampaignOwner(campaignInfo) {
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

    function setLaunch(
        address campaignInfo,
        uint256 launchTime,
        uint256 deadline,
        uint256 goalAmount,
        bool enableLatePledge
    ) external onlyCampaignOwner(campaignInfo) {
        ICampaignInfo(campaignInfo).setLaunch(
            launchTime,
            deadline,
            goalAmount,
            enableLatePledge
        );
    }

    function addContainers(
        address campaignInfo,
        address creator,
        bytes32[] calldata id,
        ICampaignContainers.Container[] calldata container
    ) external onlyCampaignOwner(campaignInfo) {
        uint256 len = id.length;
        require(len == container.length);
        for (uint256 i=0; i < len; i++) {
            ICampaignInfo(campaignInfo).addContainer(
                creator,
                id[i],
                container[i]
            );
        }
    }
}
