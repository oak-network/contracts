// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignInfoFactory {


    event campaignCreation(
        string identifier,
        address indexed campaignInfoAddress
    );
    function createCampaign(
        address _creator,
        string memory _identifier,
        bytes32 _originPlatform,
        string memory _creatorUrl,
        bytes32[] memory _reachPlatform,
        uint256 _earlyPledgeAmount
    ) external;
}
