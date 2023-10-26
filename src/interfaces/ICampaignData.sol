// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
 * @title ICampaignData
 * @notice An interface for managing campaign data in a CCP.
 */
interface ICampaignData {
    /**
     * @dev Struct to represent campaign data, including launch time, deadline, and goal amount.
     */
    struct CampaignData {
        uint256 launchTime; // Timestamp when the campaign is launched.
        uint256 deadline; // Timestamp or block number when the campaign ends.
        uint256 goalAmount; // Funding goal amount that the campaign aims to achieve.
    }
}
