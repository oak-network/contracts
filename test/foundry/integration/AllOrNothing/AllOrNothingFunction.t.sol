// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./AllOrNothing.t.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {IReward} from "src/interfaces/IReward.sol";

contract AllOrNothingFunction_Integration_Shared_Test is
    AllOrNothing_Integration_Shared_Test
{
    function test_addRewards() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Verify all rewards were added correctly
        // First reward
        Reward memory resultReward1 = allOrNothing.getReward(REWARD_NAMES[0]);
        assertEq(REWARDS[0].rewardValue, resultReward1.rewardValue);
        assertEq(REWARDS[0].isRewardTier, resultReward1.isRewardTier);
        assertEq(REWARDS[0].itemId[0], resultReward1.itemId[0]);
        assertEq(REWARDS[0].itemValue[0], resultReward1.itemValue[0]);
        assertEq(REWARDS[0].itemQuantity[0], resultReward1.itemQuantity[0]);

        // Second reward
        Reward memory resultReward2 = allOrNothing.getReward(REWARD_NAMES[1]);
        assertEq(REWARDS[1].rewardValue, resultReward2.rewardValue);
        assertEq(REWARDS[1].isRewardTier, resultReward2.isRewardTier);
        assertEq(REWARDS[1].itemId.length, resultReward2.itemId.length);
        assertEq(REWARDS[1].itemId[0], resultReward2.itemId[0]);
        assertEq(REWARDS[1].itemId[1], resultReward2.itemId[1]);
        assertEq(REWARDS[1].itemValue[0], resultReward2.itemValue[0]);
        assertEq(REWARDS[1].itemValue[1], resultReward2.itemValue[1]);
        assertEq(REWARDS[1].itemQuantity[0], resultReward2.itemQuantity[0]);
        assertEq(REWARDS[1].itemQuantity[1], resultReward2.itemQuantity[1]);

        // Third reward
        Reward memory resultReward3 = allOrNothing.getReward(REWARD_NAMES[2]);
        assertEq(REWARDS[2].rewardValue, resultReward3.rewardValue);
        assertEq(REWARDS[2].isRewardTier, resultReward3.isRewardTier);
        assertEq(REWARDS[2].itemId.length, resultReward3.itemId.length);
    }

    function test_pledgeForAReward() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        (
            Vm.Log[] memory logs,
            uint256 tokenId,
            bytes32[] memory rewards
        ) = pledgeForAReward(
                users.backer1Address,
                address(testUSD),
                address(allOrNothing),
                PLEDGE_AMOUNT,
                SHIPPING_FEE,
                LAUNCH_TIME,
                REWARD_NAME_1_HASH
            );

        uint256 backerBalance = testUSD.balanceOf(users.backer1Address);
        uint256 treasuryBalance = testUSD.balanceOf(address(allOrNothing));
        uint256 backerNftBalance = allOrNothing.balanceOf(users.backer1Address);
        address nftOwnerAddress = allOrNothing.ownerOf(pledgeForARewardTokenId);

        assertEq(users.backer1Address, nftOwnerAddress);
        assertEq(PLEDGE_AMOUNT + SHIPPING_FEE, treasuryBalance);
        assertEq(1, backerNftBalance);
    }

    function test_claimRefund() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        (, uint256 rewardTokenId, ) = pledgeForAReward(
            users.backer1Address,
            address(testUSD),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        (, uint256 tokenId) = pledgeWithoutAReward(
            users.backer1Address,
            address(testUSD),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            LAUNCH_TIME
        );

        (
            Vm.Log[] memory refundLogs,
            uint256 refundedTokenId,
            uint256 refundAmount,
            address claimer
        ) = claimRefund(users.backer1Address, address(allOrNothing), tokenId);

        assertEq(refundedTokenId, tokenId);
        assertEq(refundAmount, PLEDGE_AMOUNT);
        assertEq(claimer, users.backer1Address);
    }

    function test_disburseFees() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        pledgeForAReward(
            users.backer1Address,
            address(testUSD),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            address(testUSD),
            address(allOrNothing),
            GOAL_AMOUNT,
            LAUNCH_TIME
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;

        (
            Vm.Log[] memory logs,
            uint256 protocolShare,
            uint256 platformShare
        ) = disburseFees(address(allOrNothing), DEADLINE);

        uint256 expectedProtocolShare = (totalPledged * PROTOCOL_FEE_PERCENT) /
            PERCENT_DIVIDER;
        uint256 expectedPlatformShare = (totalPledged * PLATFORM_FEE_PERCENT) /
            PERCENT_DIVIDER;

        assertEq(
            protocolShare,
            expectedProtocolShare,
            "Incorrect protocol fee"
        );
        assertEq(
            platformShare,
            expectedPlatformShare,
            "Incorrect platform fee"
        );
    }

    function test_withdraw() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        pledgeForAReward(
            users.backer1Address,
            address(testUSD),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            address(testUSD),
            address(allOrNothing),
            GOAL_AMOUNT,
            LAUNCH_TIME
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;
        disburseFees(address(allOrNothing), DEADLINE);

        (Vm.Log[] memory logs, address to, uint256 amount) = withdraw(
            address(allOrNothing),
            DEADLINE
        );

        uint256 protocolShare = (totalPledged * PROTOCOL_FEE_PERCENT) /
            PERCENT_DIVIDER;
        uint256 platformShare = (totalPledged * PLATFORM_FEE_PERCENT) /
            PERCENT_DIVIDER;
        uint256 expectedAmount = totalPledged +
            SHIPPING_FEE -
            protocolShare -
            platformShare;

        assertEq(
            to,
            users.creator1Address,
            "Incorrect address receiving the funds"
        );
        assertEq(amount, expectedAmount, "Incorrect withdrawal amount");
    }
}
