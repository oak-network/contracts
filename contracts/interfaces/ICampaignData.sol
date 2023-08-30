// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignData {

    struct CampaignData {
        uint256 launchTime;
        uint256 deadline;
        uint256 goalAmount;
    }
}