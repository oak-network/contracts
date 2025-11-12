// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./AllOrNothing.t.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {TestToken} from "../../../mocks/TestToken.sol"; 

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
                address(testToken),
                address(allOrNothing),
                PLEDGE_AMOUNT,
                SHIPPING_FEE,
                LAUNCH_TIME,
                REWARD_NAME_1_HASH
            );

        uint256 backerBalance = testToken.balanceOf(users.backer1Address);
        uint256 treasuryBalance = testToken.balanceOf(address(allOrNothing));
        uint256 backerNftBalance = CampaignInfo(campaignAddress).balanceOf(users.backer1Address);
        address nftOwnerAddress = CampaignInfo(campaignAddress).ownerOf(tokenId);

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
            address(testToken),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );

        (, uint256 tokenId) = pledgeWithoutAReward(
            users.backer1Address,
            address(testToken),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            LAUNCH_TIME
        );

        (
            Vm.Log[] memory refundLogs,
            uint256 refundedTokenId,
            uint256 refundAmount,
            address claimer
        ) = claimRefund(users.backer1Address, address(allOrNothing), tokenId, LAUNCH_TIME + 1 days);

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
            address(testToken),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            address(testToken),
            address(allOrNothing),
            GOAL_AMOUNT,
            LAUNCH_TIME
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;

        (
            Vm.Log[] memory logs,
            uint256 protocolShare,
            uint256 platformShare
        ) = disburseFees(address(allOrNothing), DEADLINE + 1 days);

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
            address(testToken),
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            LAUNCH_TIME,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            address(testToken),
            address(allOrNothing),
            GOAL_AMOUNT,
            LAUNCH_TIME
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;
        disburseFees(address(allOrNothing), DEADLINE + 1 days);

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

    /*//////////////////////////////////////////////////////////////
                        MULTI-TOKEN FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_pledgeWithMultipleTokens() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Pledge with USDC (6 decimals)
        uint256 usdcPledgeAmount = getTokenAmount(address(usdcToken), PLEDGE_AMOUNT);
        uint256 usdcShippingFee = getTokenAmount(address(usdcToken), SHIPPING_FEE); 
        
        vm.startPrank(users.backer1Address);
        usdcToken.approve(address(allOrNothing), usdcPledgeAmount + usdcShippingFee);
        vm.warp(LAUNCH_TIME);
        
        bytes32[] memory reward1 = new bytes32[](1);
        reward1[0] = REWARD_NAME_1_HASH;
        allOrNothing.pledgeForAReward(
            users.backer1Address,
            address(usdcToken),
            usdcShippingFee, 
            reward1
        );
        vm.stopPrank();
        
        // Pledge with cUSD (18 decimals) - no conversion needed
        vm.startPrank(users.backer2Address);
        cUSDToken.approve(address(allOrNothing), PLEDGE_AMOUNT);
        allOrNothing.pledgeWithoutAReward(
            users.backer2Address,
            address(cUSDToken),
            PLEDGE_AMOUNT
        );
        vm.stopPrank();
        
        // Verify balances
        assertEq(usdcToken.balanceOf(address(allOrNothing)), usdcPledgeAmount + usdcShippingFee);
        assertEq(cUSDToken.balanceOf(address(allOrNothing)), PLEDGE_AMOUNT);
        
        // Verify normalized raised amount
        uint256 totalRaised = allOrNothing.getRaisedAmount();
        assertEq(totalRaised, PLEDGE_AMOUNT * 2, "Total raised should be sum of normalized amounts");
    }

    function test_getRaisedAmountNormalizesCorrectly() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );
        
        // Pledge same base amount in different tokens
        uint256 baseAmount = 1000e18;
        
        // USDC pledge (6 decimals)
        uint256 usdcAmount = baseAmount / 1e12;
        vm.startPrank(users.backer1Address);
        usdcToken.approve(address(allOrNothing), usdcAmount);
        vm.warp(LAUNCH_TIME);
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(usdcToken),
            usdcAmount
        );
        vm.stopPrank();
        
        uint256 raisedAfterUSDC = allOrNothing.getRaisedAmount();
        assertEq(raisedAfterUSDC, baseAmount, "USDC amount should be normalized to 18 decimals");
        
        // cUSD pledge (18 decimals)
        vm.startPrank(users.backer2Address);
        cUSDToken.approve(address(allOrNothing), baseAmount);
        allOrNothing.pledgeWithoutAReward(
            users.backer2Address,
            address(cUSDToken),
            baseAmount
        );
        vm.stopPrank();
        
        uint256 raisedAfterCUSD = allOrNothing.getRaisedAmount();
        assertEq(raisedAfterCUSD, baseAmount * 2, "Total should be sum of normalized amounts");
    }

    function test_disburseFeesWithMultipleTokens() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );
        
        // Pledge with USDC
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PLEDGE_AMOUNT);
        vm.startPrank(users.backer1Address);
        usdcToken.approve(address(allOrNothing), usdcAmount);
        vm.warp(LAUNCH_TIME);
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(usdcToken),
            usdcAmount
        );
        vm.stopPrank();
        
        // Pledge with cUSD to meet goal
        vm.startPrank(users.backer2Address);
        cUSDToken.approve(address(allOrNothing), GOAL_AMOUNT);
        allOrNothing.pledgeWithoutAReward(
            users.backer2Address,
            address(cUSDToken),
            GOAL_AMOUNT
        );
        vm.stopPrank();
        
        uint256 protocolBalanceUSDCBefore = usdcToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceUSDCBefore = usdcToken.balanceOf(users.platform1AdminAddress);
        uint256 protocolBalanceCUSDBefore = cUSDToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceCUSDBefore = cUSDToken.balanceOf(users.platform1AdminAddress);
        
        // Disburse fees
        vm.warp(DEADLINE + 1 days);
        allOrNothing.disburseFees();
        
        // Verify USDC fees
        uint256 expectedUSDCProtocolFee = (usdcAmount * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedUSDCPlatformFee = (usdcAmount * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        
        assertEq(
            usdcToken.balanceOf(users.protocolAdminAddress) - protocolBalanceUSDCBefore,
            expectedUSDCProtocolFee,
            "Incorrect USDC protocol fee"
        );
        assertEq(
            usdcToken.balanceOf(users.platform1AdminAddress) - platformBalanceUSDCBefore,
            expectedUSDCPlatformFee,
            "Incorrect USDC platform fee"
        );
        
        // Verify cUSD fees
        uint256 expectedCUSDProtocolFee = (GOAL_AMOUNT * PROTOCOL_FEE_PERCENT) / PERCENT_DIVIDER;
        uint256 expectedCUSDPlatformFee = (GOAL_AMOUNT * PLATFORM_FEE_PERCENT) / PERCENT_DIVIDER;
        
        assertEq(
            cUSDToken.balanceOf(users.protocolAdminAddress) - protocolBalanceCUSDBefore,
            expectedCUSDProtocolFee,
            "Incorrect cUSD protocol fee"
        );
        assertEq(
            cUSDToken.balanceOf(users.platform1AdminAddress) - platformBalanceCUSDBefore,
            expectedCUSDPlatformFee,
            "Incorrect cUSD platform fee"
        );
    }

    function test_withdrawWithMultipleTokens() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );
        
        // Pledge with multiple tokens
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PLEDGE_AMOUNT);
        uint256 usdtAmount = getTokenAmount(address(usdtToken), PLEDGE_AMOUNT);
        
        vm.startPrank(users.backer1Address);
        usdcToken.approve(address(allOrNothing), usdcAmount);
        vm.warp(LAUNCH_TIME);
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(usdcToken),
            usdcAmount
        );
        vm.stopPrank();
        
        vm.startPrank(users.backer2Address);
        usdtToken.approve(address(allOrNothing), usdtAmount);
        allOrNothing.pledgeWithoutAReward(
            users.backer2Address,
            address(usdtToken),
            usdtAmount
        );
        vm.stopPrank();
        
        // Need cUSD pledge to meet goal
        vm.startPrank(users.backer1Address);
        cUSDToken.approve(address(allOrNothing), GOAL_AMOUNT);
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(cUSDToken),
            GOAL_AMOUNT
        );
        vm.stopPrank();
        
        // Disburse fees and withdraw
        vm.warp(DEADLINE + 1 days);
        allOrNothing.disburseFees();
        
        uint256 creatorUSDCBefore = usdcToken.balanceOf(users.creator1Address);
        uint256 creatorUSDTBefore = usdtToken.balanceOf(users.creator1Address);
        uint256 creatorCUSDBefore = cUSDToken.balanceOf(users.creator1Address);
        
        allOrNothing.withdraw();
        
        // Verify all tokens were withdrawn
        assertTrue(usdcToken.balanceOf(users.creator1Address) > creatorUSDCBefore, "Creator should receive USDC");
        assertTrue(usdtToken.balanceOf(users.creator1Address) > creatorUSDTBefore, "Creator should receive USDT");
        assertTrue(cUSDToken.balanceOf(users.creator1Address) > creatorCUSDBefore, "Creator should receive cUSD");
        
        // Verify treasury is empty
        assertEq(usdcToken.balanceOf(address(allOrNothing)), 0, "USDC should be fully withdrawn");
        assertEq(usdtToken.balanceOf(address(allOrNothing)), 0, "USDT should be fully withdrawn");
        assertEq(cUSDToken.balanceOf(address(allOrNothing)), 0, "cUSD should be fully withdrawn");
    }

    function test_refundWithCorrectToken() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );
        
        // Backer1 pledges with USDC
        uint256 usdcAmount = getTokenAmount(address(usdcToken), PLEDGE_AMOUNT);
        vm.startPrank(users.backer1Address);
        usdcToken.approve(address(allOrNothing), usdcAmount);
        vm.warp(LAUNCH_TIME);
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(usdcToken),
            usdcAmount
        );
        uint256 usdcTokenId = 1; // First pledge
        vm.stopPrank();
        
        // Backer2 pledges with cUSD
        vm.startPrank(users.backer2Address);
        cUSDToken.approve(address(allOrNothing), PLEDGE_AMOUNT);
        allOrNothing.pledgeWithoutAReward(
            users.backer2Address,
            address(cUSDToken),
            PLEDGE_AMOUNT
        );
        uint256 cUSDTokenId = 2; // Second pledge
        vm.stopPrank();
        
        uint256 backer1USDCBefore = usdcToken.balanceOf(users.backer1Address);
        uint256 backer2CUSDBefore = cUSDToken.balanceOf(users.backer2Address);
        
        // Claim refunds
        vm.warp(LAUNCH_TIME + 1 days);
        
        // Approve treasury to burn NFTs
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(allOrNothing), usdcTokenId);
        
        vm.prank(users.backer1Address);
        allOrNothing.claimRefund(usdcTokenId);
        
        vm.prank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(allOrNothing), cUSDTokenId);
        
        vm.prank(users.backer2Address);
        allOrNothing.claimRefund(cUSDTokenId);
        
        // Verify refunds in correct tokens
        assertEq(
            usdcToken.balanceOf(users.backer1Address) - backer1USDCBefore,
            usdcAmount,
            "Should refund in USDC"
        );
        assertEq(
            cUSDToken.balanceOf(users.backer2Address) - backer2CUSDBefore,
            PLEDGE_AMOUNT,
            "Should refund in cUSD"
        );
        
        // Verify no cross-token refunds
        assertEq(cUSDToken.balanceOf(users.backer1Address), TOKEN_MINT_AMOUNT, "Should not receive cUSD");
        assertEq(usdcToken.balanceOf(users.backer2Address), TOKEN_MINT_AMOUNT / 1e12, "Should not receive USDC");
    }

    function test_revertWhenPledgingWithUnacceptedToken() external {
        // Create a token not in the accepted list
        TestToken unacceptedToken = new TestToken("Unaccepted", "UNA", 18);
        unacceptedToken.mint(users.backer1Address, PLEDGE_AMOUNT);
        
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );
        
        vm.startPrank(users.backer1Address);
        unacceptedToken.approve(address(allOrNothing), PLEDGE_AMOUNT);
        vm.warp(LAUNCH_TIME);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                AllOrNothing.AllOrNothingTokenNotAccepted.selector,
                address(unacceptedToken)
            )
        );
        allOrNothing.pledgeWithoutAReward(
            users.backer1Address,
            address(unacceptedToken),
            PLEDGE_AMOUNT
        );
        vm.stopPrank();
    }
}
