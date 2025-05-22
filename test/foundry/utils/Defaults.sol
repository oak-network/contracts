// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Constants} from "./Constants.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";
import {IReward} from "src/interfaces/IReward.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults is Constants, ICampaignData, IReward {
    //Constant Variables
    uint256 public constant PROTOCOL_FEE_PERCENT = 20 * 100;
    uint256 public constant TOKEN_MINT_AMOUNT = 1_000_000e18;
    uint256 public constant PLATFORM_FEE_PERCENT = 10 * 100;
    bytes32 public constant PLATFORM_1_HASH =
        keccak256(abi.encodePacked("KickStarter"));
    bytes32 public constant REWARD_NAME_1_HASH =
        keccak256(abi.encodePacked("sampleReward"));
    bytes32 public constant CAMPAIGN_1_IDENTIFIER_HASH =
        keccak256(abi.encodePacked("Sample Campaign"));
    string public constant NAME = "Name";
    string public constant SYMBOL = "Symbol";
    uint256 public constant GOAL_AMOUNT = 100;
    uint256 public constant CAMPAIGN_DURATION = 10_000 seconds;
    uint256 public constant PLEDGE_AMOUNT = 1_000e18;
    uint256 public constant PERCENT_DIVIDER = 10000;
    uint256 public constant SHIPPING_FEE = 10;

    //Immutable Variables
    uint256 public immutable LAUNCH_TIME;
    uint256 public immutable DEADLINE;

    //Token details
    string tokenName = "TestToken";
    string tokenSymbol = "TST";

    //Variables
    CampaignData public CAMPAIGN_DATA;
    AllOrNothing.Reward public REWARD1;

    // Public reward data for tests
    bytes32[] public REWARD_NAMES;
    Reward[] public REWARDS;

    constructor() {
        LAUNCH_TIME = OCTOBER_1_2023 + 300 seconds;
        DEADLINE = LAUNCH_TIME + CAMPAIGN_DURATION;

        //Add Campaign Data
        CAMPAIGN_DATA = CampaignData({
            launchTime: LAUNCH_TIME,
            deadline: DEADLINE,
            goalAmount: GOAL_AMOUNT
        });

        // Initialize the reward arrays
        setupRewardData();
    }

    // Setup the reward data that can be accessed by tests
    function setupRewardData() internal {
        // Create arrays for 3 rewards
        REWARD_NAMES = new bytes32[](3);
        REWARDS = new Reward[](3);

        // First reward
        REWARD_NAMES[0] = REWARD_NAME_1_HASH;

        bytes32[] memory itemIds1 = new bytes32[](1);
        uint256[] memory itemValues1 = new uint256[](1);
        uint256[] memory itemQuantities1 = new uint256[](1);
        itemIds1[0] = keccak256(abi.encodePacked("sampleItem"));
        itemValues1[0] = 1_000e18;
        itemQuantities1[0] = 10;

        REWARDS[0] = Reward({
            rewardValue: 1_000e18,
            isRewardTier: true,
            itemId: itemIds1,
            itemValue: itemValues1,
            itemQuantity: itemQuantities1
        });

        // Second reward (example with 2 items)
        REWARD_NAMES[1] = keccak256(abi.encodePacked("premiumReward"));

        bytes32[] memory itemIds2 = new bytes32[](2);
        uint256[] memory itemValues2 = new uint256[](2);
        uint256[] memory itemQuantities2 = new uint256[](2);
        itemIds2[0] = keccak256(abi.encodePacked("premiumItem1"));
        itemValues2[0] = 2_000e18;
        itemQuantities2[0] = 5;
        itemIds2[1] = keccak256(abi.encodePacked("premiumItem2"));
        itemValues2[1] = 500e18;
        itemQuantities2[1] = 2;

        REWARDS[1] = Reward({
            rewardValue: 2_500e18,
            isRewardTier: true,
            itemId: itemIds2,
            itemValue: itemValues2,
            itemQuantity: itemQuantities2
        });

        // Third reward (example with no items, just a value)
        REWARD_NAMES[2] = keccak256(abi.encodePacked("basicReward"));

        bytes32[] memory emptyIds = new bytes32[](0);
        uint256[] memory emptyValues = new uint256[](0);
        uint256[] memory emptyQuantities = new uint256[](0);

        REWARDS[2] = Reward({
            rewardValue: 500e18,
            isRewardTier: false,
            itemId: emptyIds,
            itemValue: emptyValues,
            itemQuantity: emptyQuantities
        });
    }
}
