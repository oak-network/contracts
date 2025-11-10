// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Constants} from "./Constants.sol";
import {ICampaignData} from "src/interfaces/ICampaignData.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {IReward} from "src/interfaces/IReward.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults is Constants, ICampaignData, IReward {
    //Constant Variables
    uint256 public constant PROTOCOL_FEE_PERCENT = 20 * 100; 
    uint256 public constant TOKEN_MINT_AMOUNT = 1_000_000e18;
    uint256 public constant PLATFORM_FEE_PERCENT = 10 * 100; // 10%
    bytes32 public constant PLATFORM_1_HASH = keccak256(abi.encodePacked("KickStarter"));
    bytes32 public constant PLATFORM_2_HASH = keccak256(abi.encodePacked("Vaki"));
    bytes32 public constant REWARD_NAME_1_HASH = keccak256(abi.encodePacked("sampleReward"));
    bytes32 public constant CAMPAIGN_1_IDENTIFIER_HASH = keccak256(abi.encodePacked("Sample Campaign"));
    string public constant NAME = "Name";
    string public constant SYMBOL = "Symbol";
    uint256 public constant GOAL_AMOUNT = 100_000e18; // Increased to handle fees better
    uint256 public constant CAMPAIGN_DURATION = 30 days;
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

    // Fee Keys for KeepWhatsRaised
    bytes32 public constant FLAT_FEE_KEY = keccak256(abi.encodePacked("flatFee"));
    bytes32 public constant CUMULATIVE_FLAT_FEE_KEY = keccak256(abi.encodePacked("cumulativeFlatFee"));
    bytes32 public constant PLATFORM_FEE_KEY = keccak256(abi.encodePacked("platformFee"));
    bytes32 public constant VAKI_COMMISSION_KEY = keccak256(abi.encodePacked("vakiCommission"));

    // Fee Values
    bytes32 public constant FLAT_FEE_VALUE = bytes32(uint256(100e18)); // 100 token flat fee
    bytes32 public constant CUMULATIVE_FLAT_FEE_VALUE = bytes32(uint256(200e18)); // 200 token cumulative fee  
    bytes32 public constant PLATFORM_FEE_VALUE = bytes32(PLATFORM_FEE_PERCENT); // 10%
    bytes32 public constant VAKI_COMMISSION_VALUE = bytes32(uint256(6 * 100)); // 6% for regular campaigns

    // Payment Gateway Fees - proportional to pledge
    uint256 public constant PAYMENT_GATEWAY_FEE = 40e18; // 4% of 1000e18
    uint256 public constant PAYMENT_GATEWAY_FEE_PERCENTAGE = 4 * 100; // 4%

    // Config values for KeepWhatsRaised
    uint256 public constant MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION = 50_000e18;
    uint256 public constant WITHDRAWAL_DELAY = 7 days;
    uint256 public constant REFUND_DELAY = 14 days;
    uint256 public constant CONFIG_LOCK_PERIOD = 2 days;

    // Additional constants
    uint256 public constant TIP_AMOUNT = 10e18;
    uint256 public constant WITHDRAWAL_AMOUNT = 50_000e18;

    // Test Pledge IDs
    bytes32 public constant TEST_PLEDGE_ID_1 = keccak256(abi.encodePacked("pledge1"));
    bytes32 public constant TEST_PLEDGE_ID_2 = keccak256(abi.encodePacked("pledge2"));
    bytes32 public constant TEST_PLEDGE_ID_3 = keccak256(abi.encodePacked("pledge3"));

    KeepWhatsRaised.FeeKeys public FEE_KEYS;
    KeepWhatsRaised.Config public CONFIG;
    KeepWhatsRaised.Config public CONFIG_COLOMBIAN;
    bytes32[] public GROSS_PERCENTAGE_FEE_KEYS;
    bytes32[] public GROSS_PERCENTAGE_FEE_VALUES;

    constructor() {
        LAUNCH_TIME = OCTOBER_1_2023 + 2 hours; // 2 hours buffer to accommodate time constraints
        DEADLINE = LAUNCH_TIME + CAMPAIGN_DURATION;

        //Add Campaign Data
        CAMPAIGN_DATA = CampaignData({
            launchTime: LAUNCH_TIME,
            deadline: DEADLINE,
            goalAmount: GOAL_AMOUNT,
            currency: bytes32("USD")
        });

        // Initialize the reward arrays
        setupRewardData();

        setupKeepWhatsRaisedData();
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

    function setupKeepWhatsRaisedData() internal {
        // Setup gross percentage fee keys and values
        GROSS_PERCENTAGE_FEE_KEYS = new bytes32[](2);
        GROSS_PERCENTAGE_FEE_KEYS[0] = PLATFORM_FEE_KEY;
        GROSS_PERCENTAGE_FEE_KEYS[1] = VAKI_COMMISSION_KEY;

        GROSS_PERCENTAGE_FEE_VALUES = new bytes32[](2);
        GROSS_PERCENTAGE_FEE_VALUES[0] = PLATFORM_FEE_VALUE;
        GROSS_PERCENTAGE_FEE_VALUES[1] = VAKI_COMMISSION_VALUE;

        // Setup FEE_KEYS struct
        FEE_KEYS = KeepWhatsRaised.FeeKeys({
            flatFeeKey: FLAT_FEE_KEY,
            cumulativeFlatFeeKey: CUMULATIVE_FLAT_FEE_KEY,
            grossPercentageFeeKeys: GROSS_PERCENTAGE_FEE_KEYS
        });

        // Setup CONFIG struct for non-Colombian creator
        CONFIG = KeepWhatsRaised.Config({
            minimumWithdrawalForFeeExemption: MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION,
            withdrawalDelay: WITHDRAWAL_DELAY,
            refundDelay: REFUND_DELAY,
            configLockPeriod: CONFIG_LOCK_PERIOD,
            isColombianCreator: false
        });

        // Setup CONFIG struct for Colombian creator
        CONFIG_COLOMBIAN = KeepWhatsRaised.Config({
            minimumWithdrawalForFeeExemption: MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION,
            withdrawalDelay: WITHDRAWAL_DELAY,
            refundDelay: REFUND_DELAY,
            configLockPeriod: CONFIG_LOCK_PERIOD,
            isColombianCreator: true
        });
    }
}