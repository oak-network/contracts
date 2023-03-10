// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./CampaignInfo.sol";
import "./CampaignRegistry.sol";

contract CampaignInfoFactory is Ownable {
    event campaignCreation(
        string identifier,
        address indexed campaignInfoAddress
    );

    CampaignInfo newCampaignInfo;
    address campaignRegistry;
    bool initialized;

    function setRegistry(address _campaignRegistry) public onlyOwner {
        campaignRegistry = _campaignRegistry;
        initialized = true;
    }

    function createCampaign(
        string memory _identifier,
        bytes32 _originPlatform,
        uint256 _goalAmount,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _platformTotalFeePercent,
        uint256 _rewardPlatformFeePercent,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform
    ) external onlyOwner {
        require(initialized);
        newCampaignInfo = new CampaignInfo(
            _identifier,
            _originPlatform,
            _goalAmount,
            _launchTime,
            _deadline,
            _platformTotalFeePercent,
            _rewardPlatformFeePercent,
            _creatorUrl,
            _reachPlatform,
            campaignRegistry
        );
        require(address(newCampaignInfo) != address(0));

        address newCampaignAddress = address(newCampaignInfo);

        CampaignRegistry(campaignRegistry).setCampaignInfoAddress(
            _identifier,
            newCampaignAddress
        );

        emit campaignCreation(_identifier, newCampaignAddress);
    }
}
