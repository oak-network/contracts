// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignInfoFactory {

    event campaignCreation(
        string identifier,
        address indexed campaignInfoAddress
    );

    function createCampaign(
        address _creator,
        address _token,
        uint256 _launchTime,
        uint256 _deadline,
        uint256 _goal,
        string memory _identifier,
        bytes32[] memory _platforms
    ) external;
}
