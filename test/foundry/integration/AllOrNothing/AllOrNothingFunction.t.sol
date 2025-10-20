// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AllOrNothing.t.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {Defaults} from "../../utils/Defaults.sol";
import {Constants} from "../../utils/Constants.sol";
import {Users} from "../../utils/Types.sol";
import {IReward} from "src/interfaces/IReward.sol";

/**
 * @title AllOrNothing Function Integration Test Contract
 * @notice Comprehensive integration tests for AllOrNothing treasury contract functionality
 * @dev Inherits from AllOrNothing_Integration_Shared_Test to access common setup and utilities.
 *      Tests cover the full lifecycle of campaign operations including reward setup, pledging,
 *      refund claims, fee disbursement, and fund withdrawal scenarios.
 */
contract AllOrNothingFunction_Integration_Shared_Test is
    AllOrNothing_Integration_Shared_Test
{
    /**
     * @notice Tests the addRewards functionality
     * @dev Verifies that rewards can be properly added to the treasury contract and that
     *      all reward properties are stored correctly including values, tiers, items, and quantities.
     *      Tests multiple rewards with different configurations to ensure proper storage and retrieval.
     */
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

    /**
     * @notice Tests the removeReward functionality
     * @dev Verifies that rewards can be properly removed from the treasury contract and that
     *      the reward is no longer accessible after removal. Ensures the RewardRemoved event
     *      is emitted correctly and attempts to access removed rewards result in reverts.
     */
    function test_removeReward() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Verify reward exists before removal
        Reward memory existingReward = allOrNothing.getReward(REWARD_NAMES[0]);
        assertEq(existingReward.rewardValue, REWARDS[0].rewardValue);

        // Remove the reward using helper function
        Vm.Log[] memory logs = removeReward(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES[0]
        );

        // For indexed parameters, we need to check topics
        (bytes32[] memory topics, ) = decodeTopicsAndData(
            logs,
            "RewardRemoved(bytes32)",
            address(allOrNothing)
        );
        assertEq(topics[1], REWARD_NAMES[0], "Removed reward name should match");

        // Verify reward no longer exists (should revert)
        vm.expectRevert();
        allOrNothing.getReward(REWARD_NAMES[0]);
    }

    /**
     * @notice Tests the getReward functionality
     * @dev Verifies that reward details can be properly retrieved from the treasury contract.
     *      Tests retrieval of all reward properties including values, tier flags, item arrays,
     *      and validates that non-existent rewards cause appropriate reverts.
     */
    function test_getReward() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Test getting each reward
        for (uint i = 0; i < REWARD_NAMES.length; i++) {
            Reward memory retrievedReward = allOrNothing.getReward(REWARD_NAMES[i]);
            
            assertEq(retrievedReward.rewardValue, REWARDS[i].rewardValue, "Reward value mismatch");
            assertEq(retrievedReward.isRewardTier, REWARDS[i].isRewardTier, "Reward tier flag mismatch");
            assertEq(retrievedReward.itemId.length, REWARDS[i].itemId.length, "Item ID array length mismatch");
            assertEq(retrievedReward.itemValue.length, REWARDS[i].itemValue.length, "Item value array length mismatch");
            assertEq(retrievedReward.itemQuantity.length, REWARDS[i].itemQuantity.length, "Item quantity array length mismatch");
            
            // Check array contents
            for (uint j = 0; j < retrievedReward.itemId.length; j++) {
                assertEq(retrievedReward.itemId[j], REWARDS[i].itemId[j], "Item ID mismatch");
                assertEq(retrievedReward.itemValue[j], REWARDS[i].itemValue[j], "Item value mismatch");
                assertEq(retrievedReward.itemQuantity[j], REWARDS[i].itemQuantity[j], "Item quantity mismatch");
            }
        }

        // Test getting non-existent reward (should revert)
        vm.expectRevert();
        allOrNothing.getReward(keccak256("NonExistentReward"));
    }

    /**
     * @notice Tests the getRaisedAmount functionality
     * @dev Verifies that the total raised amount is correctly tracked and returned.
     *      Tests progression from zero to multiple pledges to ensure accurate accumulation.
     *      Note that raised amount only tracks pledge amounts, not shipping fees.
     */
    function test_getRaisedAmount() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Initially should be zero
        uint256 initialRaised = allOrNothing.getRaisedAmount();
        assertEq(initialRaised, 0, "Initial raised amount should be zero");

        // Make a pledge and check raised amount
        pledgeForAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            REWARD_NAME_1_HASH
        );

        uint256 raisedAfterFirstPledge = allOrNothing.getRaisedAmount();
        assertEq(raisedAfterFirstPledge, PLEDGE_AMOUNT, "Raised amount should equal first pledge amount");

        // Make another pledge and check raised amount
        pledgeWithoutAReward(
            users.backer2Address,
            LAUNCH_TIME,
            address(allOrNothing),
            GOAL_AMOUNT
        );

        uint256 finalRaised = allOrNothing.getRaisedAmount();
        assertEq(finalRaised, PLEDGE_AMOUNT + GOAL_AMOUNT, "Raised amount should equal sum of all pledges");
    }

    /**
     * @notice Tests the pauseTreasury functionality
     * @dev Verifies that the treasury can be paused by platform admin and that the paused
     *      state is correctly set. Validates that the Paused event is emitted from the
     *      correct contract when the pause operation is executed.
     */
    function test_pauseTreasury() external {
        bytes32 pauseReason = keccak256("Test pause");
        
        assertFalse(allOrNothing.paused(), "Treasury should not be paused initially");

        Vm.Log[] memory logs = pauseTreasury(
            users.platform1AdminAddress,
            address(allOrNothing),
            pauseReason
        );

        assertTrue(allOrNothing.paused(), "Treasury should be paused");

        // Use LogDecoder to find and verify the Paused event
        Vm.Log memory pausedLog = findLogByTopic(
            logs,
            keccak256("Paused(address,bytes32)")
        );
        
        assertEq(pausedLog.emitter, address(allOrNothing), "Event should be emitted by allOrNothing contract");
    }

    /**
     * @notice Tests the unpauseTreasury functionality
     * @dev Verifies that the treasury can be unpaused by platform admin after being paused.
     *      Ensures proper state transition from paused to unpaused and validates that the
     *      Unpaused event is correctly emitted from the treasury contract.
     */
    function test_unpauseTreasury() external {
        bytes32 pauseReason = keccak256("Test pause");
        bytes32 unpauseReason = keccak256("Test unpause");
        
        pauseTreasury(users.platform1AdminAddress, address(allOrNothing), pauseReason);
        assertTrue(allOrNothing.paused(), "Treasury should be paused");

        Vm.Log[] memory logs = unpauseTreasury(
            users.platform1AdminAddress,
            address(allOrNothing),
            unpauseReason
        );

        assertFalse(allOrNothing.paused(), "Treasury should not be paused");

        // Use LogDecoder to find and verify the Unpaused event
        Vm.Log memory unpausedLog = findLogByTopic(
            logs,
            keccak256("Unpaused(address,bytes32)")
        );
        
        assertEq(unpausedLog.emitter, address(allOrNothing), "Event should be emitted by allOrNothing contract");
    }

    /**
     * @notice Tests the cancelTreasury functionality by platform admin
     * @dev Verifies that the treasury can be cancelled by platform admin and that the cancelled
     *      state is permanently set. Validates that the Cancelled event is emitted correctly
     *      and that cancellation is an irreversible operation.
     */
    function test_cancelTreasury() external {
        bytes32 cancelReason = keccak256("Test cancellation");
        
        assertFalse(allOrNothing.cancelled(), "Treasury should not be cancelled initially");

        Vm.Log[] memory logs = cancelTreasury(
            users.platform1AdminAddress,
            address(allOrNothing),
            cancelReason
        );

        assertTrue(allOrNothing.cancelled(), "Treasury should be cancelled");

        // Use LogDecoder to find and verify the Cancelled event
        Vm.Log memory cancelledLog = findLogByTopic(
            logs,
            keccak256("Cancelled(address,bytes32)")
        );
        
        assertEq(cancelledLog.emitter, address(allOrNothing), "Event should be emitted by allOrNothing contract");
    }

    /**
     * @notice Tests cancelTreasury functionality by campaign owner
     * @dev Verifies that the campaign owner can also cancel the treasury, demonstrating
     *      the dual authorization model where both platform admin and campaign owner
     *      have cancellation privileges. Validates proper event emission and state change.
     */
    function test_cancelTreasuryByCampaignOwner() external {
        bytes32 cancelReason = keccak256("Owner cancellation");
        
        assertFalse(allOrNothing.cancelled(), "Treasury should not be cancelled initially");
        
        // Cancel the treasury as campaign owner using helper function
        Vm.Log[] memory logs = cancelTreasury(
            users.creator1Address,
            address(allOrNothing),
            cancelReason
        );

        // Verify treasury is cancelled
        assertTrue(allOrNothing.cancelled(), "Treasury should be cancelled by owner");

        // Use LogDecoder to find and verify the Cancelled event
        Vm.Log memory cancelledLog = findLogByTopic(
            logs,
            keccak256("Cancelled(address,bytes32)")
        );
        
        assertEq(cancelledLog.emitter, address(allOrNothing), "Event should be emitted by allOrNothing contract");
    }

    /**
     * @notice Tests the name functionality
     * @dev Verifies that the contract name is correctly returned and matches the value
     *      that was set during contract initialization. Tests the ERC721 metadata extension.
     */
    function test_name() external {
        string memory contractName = allOrNothing.name();
        assertEq(contractName, NAME, "Contract name should match initialized name");
    }

    /**
     * @notice Tests the symbol functionality
     * @dev Verifies that the contract symbol is correctly returned and matches the value
     *      that was set during contract initialization. Tests the ERC721 metadata extension.
     */
    function test_symbol() external {
        string memory contractSymbol = allOrNothing.symbol();
        assertEq(contractSymbol, SYMBOL, "Contract symbol should match initialized symbol");
    }

    /**
     * @notice Tests the getPlatformHash functionality
     * @dev Verifies that the platform hash is correctly returned and matches the value
     *      that was set during contract initialization. This hash identifies which platform
     *      the treasury belongs to.
     */
    function test_getPlatformHash() external {
        bytes32 platformHash = allOrNothing.getPlatformHash();
        assertEq(platformHash, PLATFORM_1_HASH, "Platform hash should match initialized value");
    }

    /**
     * @notice Tests the getPlatformFeePercent functionality
     * @dev Verifies that the platform fee percentage is correctly returned and matches
     *      the value that was set during contract initialization. This percentage determines
     *      the platform's share of successful campaign funds.
     */
    function test_getPlatformFeePercent() external {
        uint256 platformFeePercent = allOrNothing.getPlatformFeePercent();
        assertEq(platformFeePercent, PLATFORM_FEE_PERCENT, "Platform fee percent should match initialized value");
    }

    /**
     * @notice Tests the pledgeForAReward functionality
     * @dev Verifies that users can pledge for specific rewards, including proper token transfers,
     *      NFT minting, and balance updates. Confirms that the backer receives an NFT representing
     *      their pledge and that funds (pledge amount + shipping fee) are correctly transferred
     *      to the treasury. Tests the complete reward-based pledging workflow.
     */
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
                LAUNCH_TIME,
                address(allOrNothing),
                PLEDGE_AMOUNT,
                SHIPPING_FEE,
                REWARD_NAME_1_HASH
            );

        uint256 treasuryBalance = testToken.balanceOf(address(allOrNothing));
        uint256 backerNftBalance = allOrNothing.balanceOf(users.backer1Address);
        address nftOwnerAddress = allOrNothing.ownerOf(tokenId);

        // Verify Receipt event was emitted with correct data
        Vm.Log memory receiptLog = findLogByTopic(
            logs,
            keccak256("Receipt(address,bytes32,uint256,uint256,uint256,bytes32[])")
        );
        assertEq(receiptLog.emitter, address(allOrNothing), "Receipt event should be emitted by allOrNothing contract");

        // Verify state changes
        assertEq(users.backer1Address, nftOwnerAddress, "Backer should own the NFT");
        assertEq(PLEDGE_AMOUNT + SHIPPING_FEE, treasuryBalance, "Treasury should contain pledge amount + shipping fee");
        assertEq(1, backerNftBalance, "Backer should have exactly 1 NFT");
        assertEq(rewards[0], REWARD_NAME_1_HASH, "Reward name should match");
    }

    /**
     * @notice Tests the pledgeWithoutAReward functionality
     * @dev Verifies that users can make pledges without selecting rewards, including proper
     *      token transfers, NFT minting, and balance updates. Confirms that the backer receives
     *      an NFT representing their pledge and that only the pledge amount is transferred
     *      (no shipping fees since no rewards are selected). Tests the basic pledging workflow.
     */
    function test_pledgeWithoutAReward() external {
        // Get initial balances
        uint256 initialBackerBalance = testToken.balanceOf(users.backer1Address);
        uint256 initialTreasuryBalance = testToken.balanceOf(address(allOrNothing));
        uint256 initialBackerNftBalance = allOrNothing.balanceOf(users.backer1Address);

        // Make a pledge without reward
        (, uint256 tokenId) = pledgeWithoutAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT
        );

        // Get final balances
        uint256 finalBackerBalance = testToken.balanceOf(users.backer1Address);
        uint256 finalTreasuryBalance = testToken.balanceOf(address(allOrNothing));
        uint256 finalBackerNftBalance = allOrNothing.balanceOf(users.backer1Address);
        address nftOwnerAddress = allOrNothing.ownerOf(tokenId);

        // Verify token transfers
        assertEq(
            initialBackerBalance - finalBackerBalance,
            PLEDGE_AMOUNT,
            "Incorrect amount deducted from backer"
        );
        assertEq(
            finalTreasuryBalance - initialTreasuryBalance,
            PLEDGE_AMOUNT,
            "Incorrect amount transferred to treasury"
        );
        
        // Verify NFT minting
        assertEq(
            finalBackerNftBalance - initialBackerNftBalance,
            1,
            "Backer should receive exactly one NFT"
        );
        assertEq(
            nftOwnerAddress,
            users.backer1Address,
            "Backer should own the minted NFT"
        );

        // Verify treasury balance matches expected amount (no shipping fees)
        assertEq(
            finalTreasuryBalance,
            PLEDGE_AMOUNT,
            "Treasury should only contain the pledge amount"
        );
    }

    /**
     * @notice Tests the claimRefund functionality for both reward and non-reward pledges
     * @dev Verifies that backers can claim refunds when campaigns fail to meet their goals.
     *      Tests both reward pledges (with shipping fees) and non-reward pledges, ensuring 
     *      proper refund amounts and that the correct addresses receive refunds for both types.
     *      Validates that refunds include shipping fees for reward pledges and that NFTs are
     *      burned upon successful refund claims.
     */
    function test_claimRefund() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        // Create a pledge with reward
        (, uint256 rewardTokenId, ) = pledgeForAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            REWARD_NAME_1_HASH
        );

        // Create a pledge without reward
        (, uint256 nonRewardTokenId) = pledgeWithoutAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT
        );

        // Test refund for pledge without reward
        (
            ,
            uint256 refundedNonRewardTokenId,
            uint256 nonRewardRefundAmount,
            address nonRewardClaimer
        ) = claimRefund(
                users.backer1Address,
                LAUNCH_TIME + 1,
                address(allOrNothing),
                nonRewardTokenId
            );

        // Verify non-reward refund
        assertEq(refundedNonRewardTokenId, nonRewardTokenId, "Incorrect non-reward token ID refunded");
        assertEq(nonRewardRefundAmount, PLEDGE_AMOUNT, "Incorrect non-reward refund amount");
        assertEq(nonRewardClaimer, users.backer1Address, "Incorrect non-reward claimer address");

        // Test refund for pledge with reward
        (
            ,
            uint256 refundedRewardTokenId,
            uint256 rewardRefundAmount,
            address rewardClaimer
        ) = claimRefund(
                users.backer1Address,
                LAUNCH_TIME + 1,
                address(allOrNothing),
                rewardTokenId
            );

        // Verify reward refund (should include pledge amount + shipping fee)
        assertEq(refundedRewardTokenId, rewardTokenId, "Incorrect reward token ID refunded");
        assertEq(rewardRefundAmount, PLEDGE_AMOUNT + SHIPPING_FEE, "Incorrect reward refund amount");
        assertEq(rewardClaimer, users.backer1Address, "Incorrect reward claimer address");
    }

    /**
     * @notice Tests the disburseFees functionality
     * @dev Verifies that protocol and platform fees are correctly calculated and distributed
     *      when a campaign succeeds. Tests the fee calculation logic and ensures proper
     *      allocation between protocol and platform shares. Only executes after campaign
     *      deadline and when success conditions are met.
     */
    function test_disburseFees() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        pledgeForAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            LAUNCH_TIME,
            address(allOrNothing),
            GOAL_AMOUNT
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;

        (
            Vm.Log[] memory logs,
            uint256 protocolShare,
            uint256 platformShare
        ) = disburseFees(address(allOrNothing), DEADLINE + 1);

        uint256 expectedProtocolShare = (totalPledged * PROTOCOL_FEE_PERCENT) /
            PERCENT_DIVIDER;
        uint256 expectedPlatformShare = (totalPledged * PLATFORM_FEE_PERCENT) /
            PERCENT_DIVIDER;

        // Verify FeesDisbursed event was emitted
        Vm.Log memory feesLog = findLogByTopic(
            logs,
            keccak256("FeesDisbursed(uint256,uint256)")
        );
        assertEq(feesLog.emitter, address(allOrNothing), "FeesDisbursed event should be emitted by allOrNothing contract");

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

    /**
     * @notice Tests the withdraw functionality
     * @dev Verifies that campaign creators can withdraw remaining funds after successful
     *      campaigns and fee disbursement. Tests proper calculation of withdrawal amounts
     *      after deducting protocol and platform fees, and confirms funds go to the correct
     *      recipient (campaign owner). Includes shipping fees in the final withdrawal amount.
     */
    function test_withdraw() external {
        addRewards(
            users.creator1Address,
            address(allOrNothing),
            REWARD_NAMES,
            REWARDS
        );

        pledgeForAReward(
            users.backer1Address,
            LAUNCH_TIME,
            address(allOrNothing),
            PLEDGE_AMOUNT,
            SHIPPING_FEE,
            REWARD_NAME_1_HASH
        );
        pledgeWithoutAReward(
            users.backer2Address,
            LAUNCH_TIME,
            address(allOrNothing),
            GOAL_AMOUNT
        );

        uint256 totalPledged = GOAL_AMOUNT + PLEDGE_AMOUNT;
        disburseFees(address(allOrNothing), DEADLINE + 1);

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

        // Verify WithdrawalSuccessful event was emitted
        Vm.Log memory withdrawalLog = findLogByTopic(
            logs,
            keccak256("WithdrawalSuccessful(address,uint256)")
        );
        assertEq(withdrawalLog.emitter, address(allOrNothing), "WithdrawalSuccessful event should be emitted by allOrNothing contract");

        assertEq(
            to,
            users.creator1Address,
            "Incorrect address receiving the funds"
        );
        assertEq(amount, expectedAmount, "Incorrect withdrawal amount");
    }
}