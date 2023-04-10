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

    modifier onlyCampaignOwner(address campaignInfo) {
        require(campaignOwners[campaignInfo] == msg.sender);
        _;
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
            address(this),
            _identifier,
            _originPlatform,
            _creatorUrl,
            _reachPlatform,
            _earlyPledgeAmount
        );
        address infoAddress = ICampaignRegistry(campaignRegistry)
            .getCampaignInfoAddress(_identifier);
        campaignOwners[infoAddress] = _creator;
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

    function addItem(
        address campaignInfo,
        string calldata _itemId,
        string calldata _description
    ) external onlyCampaignOwner(campaignInfo) {
        ICampaignInfo(campaignInfo).addItem(_itemId, _description);
    }

    function addReward(
        address campaignInfo,
        string calldata name,
        uint256 rewardValue,
        string[] memory itemName,
        uint256[] memory itemQuantity
    ) external onlyCampaignOwner(campaignInfo) {
        ICampaignInfo(campaignInfo).addReward(
            name,
            rewardValue,
            itemName,
            itemQuantity
        );
    }

    function addItemAndReward(
        address campaignInfo,
        string calldata itemId,
        string calldata description,
        string calldata name,
        uint256 rewardValue,
        string[] memory itemName,
        uint256[] memory itemQuantity
    ) external onlyCampaignOwner(campaignInfo) {
        ICampaignInfo(campaignInfo).addItem(itemId, description);
        ICampaignInfo(campaignInfo).addReward(
            name,
            rewardValue,
            itemName,
            itemQuantity
        );
    }
}
