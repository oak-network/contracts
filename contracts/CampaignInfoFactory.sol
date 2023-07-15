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
        address _token,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _goal,
        string memory _identifier,
        bytes32[] memory _platforms
    ) external override {
        newCampaignInfo = new CampaignInfo(
            registry,
            _creator,
            _token,
            _launchTime,
            _deadline,
            _goal,
            _identifier,
            _platforms
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
