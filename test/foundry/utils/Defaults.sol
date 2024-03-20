// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Constants} from "./Constants.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults is Constants, ICampaignData {

    //Constant Variables
    uint256 public constant PROTOCOL_FEE_PERCENT = 20 * 100;
    uint256 public constant TOKEN_MINT_AMOUNT = 1_000_000e18;
    uint256 public constant PLATFORM_FEE_PERCENT = 10 * 100;
    bytes32 public constant PLATFORM_1_BYTES = bytes32(bytes("KickStarter"));
    bytes32 public constant REWARD_NAME_1_BYTES = bytes32(bytes("sampleReward"));
    uint256 public constant TREASURY_BYTE_CODE_INDEX = 1;
    uint256 public constant GOAL_AMOUNT = 100;
    uint256 public constant CAMPAIGN_DURATION = 10_000 seconds;
    uint256 public constant PRE_LAUNCH_PLEDGE_AMOUNT = 1e18;
    uint256 public constant PLEDGE_AMOUNT = 1_000e18;

    //Immutable Variables
    uint256 public immutable LAUNCH_TIME;
    uint256 public immutable DEADLINE;

    //Variables
    CampaignData public CAMPAIGN_DATA;
    AllOrNothing.Reward public REWARD1;

    constructor() {
        LAUNCH_TIME =  OCTOBER_1_2023 + 300 seconds;
        DEADLINE = LAUNCH_TIME + CAMPAIGN_DURATION;

        //Add Campaign Data
        CAMPAIGN_DATA = CampaignData({
            launchTime: LAUNCH_TIME,
            deadline: DEADLINE,
            goalAmount: GOAL_AMOUNT
        });

        //Add Reward Data
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory itemValue = new uint256[](1);
        uint256[] memory itemQuantity = new uint256[](1);
        itemIds[0] = bytes32(bytes("sampleItem"));
        itemValue[0] = 1_000e18;
        itemQuantity[0] = 10;
        REWARD1 = AllOrNothing.Reward({
            rewardValue: 1_000e18,
            isRewardTier: true,
            itemId: itemIds,
            itemValue: itemValue,
            itemQuantity: itemQuantity
        });
    }

}