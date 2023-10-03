// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AllOrNothing_Integration_Shared_Test} from "./AllOrNothing.t.sol";
import "forge-std/Console.sol";
import "forge-std/Vm.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

/// @notice Integration Test contract for AllOrNothing contract.
contract AllOrNothingFunction_Integration_Shared_Test is AllOrNothing_Integration_Shared_Test {

    /// @dev Test addReward function.
    function test_addReward() external {

        addReward();
        
        AllOrNothing.Reward memory resultReward = allOrNothing.getReward(REWARD_NAME_1_BYTES);

        assertEq(REWARD1.rewardValue, resultReward.rewardValue);
        assertEq(REWARD1.isRewardTier, resultReward.isRewardTier);
        assertEq(REWARD1.itemId[0], resultReward.itemId[0]);
        assertEq(REWARD1.itemValue, resultReward.itemValue);
        assertEq(REWARD1.itemQuantity, resultReward.itemQuantity);
    }

    /// @dev Test pledgeOnPreLaunch function.
    function test_pledgeOnPreLaunch() external {

        addReward();
        pledgeOnPreLaunch();

        uint256 backerBalance = testUSD.balanceOf(users.backer1Address);
        uint256 treasuryBalance = testUSD.balanceOf(address(allOrNothing));
        uint256 backerNftBalance = allOrNothing.balanceOf(users.backer1Address);
        address nftOwnerAddress = allOrNothing.ownerOf(1);

        assertEq(users.backer1Address, nftOwnerAddress);
        assertEq(PRE_LAUNCH_PLEDGE_AMOUNT, TOKEN_MINT_AMOUNT-backerBalance);
        assertEq(PRE_LAUNCH_PLEDGE_AMOUNT, treasuryBalance);
        assertEq(1, backerNftBalance);
    }

    /// @dev Test pledgeForAReward function.
    function test_pledgeForAReward() external {

        addReward();
        pledgeOnPreLaunch();
        pledgeForAReward();

        uint256 backerBalance = testUSD.balanceOf(users.backer1Address);
        uint256 treasuryBalance = testUSD.balanceOf(address(allOrNothing));
        uint256 backerNftBalance = allOrNothing.balanceOf(users.backer1Address);

        address nftOwnerAddress = allOrNothing.ownerOf(2);

        assertEq(users.backer1Address, nftOwnerAddress);
        assertEq(PLEDGE_AMOUNT, TOKEN_MINT_AMOUNT - backerBalance - PRE_LAUNCH_PLEDGE_AMOUNT);
        assertEq(PLEDGE_AMOUNT, treasuryBalance - PRE_LAUNCH_PLEDGE_AMOUNT);
        assertEq(2, backerNftBalance);

    }

    /// @dev Test pledgeWithoutAReward function.
    function test_pledgeWithoutAReward() external {

        addReward();
        pledgeOnPreLaunch();
        pledgeForAReward();
        Vm.Log[] memory entries = pledgeWithoutAReward();

        address resultBacker = address(uint160(uint(entries[3].topics[1])));

        uint256 pledgeAmount;
        uint256 tokenId;
        bool isPreLaunchPledge;
        bytes32[] memory rewards;

        (pledgeAmount, tokenId, isPreLaunchPledge, rewards) = abi.decode(entries[3].data, (uint256,uint256,bool,bytes32[]));

        assertEq(users.backer1Address, resultBacker);
        assertEq(PLEDGE_AMOUNT, pledgeAmount);
        assertEq(false, isPreLaunchPledge);
    }

    /// @dev Test claimRefund function.
    function test_claimRefund() external {

        addReward();
        pledgeOnPreLaunch();
        pledgeForAReward();
        pledgeWithoutAReward();
        Vm.Log[] memory entries = claimRefund();

        uint256 refundAmount;
        uint256 tokenId;
        address claimer;

        (tokenId, refundAmount, claimer) = abi.decode(entries[4].data, (uint256,uint256,address));

        assertEq(pledgeForARewardTokenId, tokenId);
        assertEq(PLEDGE_AMOUNT, refundAmount);
        assertEq(users.backer1Address, claimer);
    }

    /// @dev Test disburseFees function.
    function test_disburseFees() external {

        addReward();
        pledgeOnPreLaunch();
        pledgeForAReward();
        pledgeWithoutAReward();
        claimRefund();
        Vm.Log[] memory entries = disburseFees();

        uint256 protocolShare;
        uint256 platformShare;

        (protocolShare, platformShare) = abi.decode(entries[2].data, (uint256,uint256));

        assertEq(2_002e17, protocolShare);
        assertEq(1_001e17, platformShare);
    }

    /// @dev Test withdraw function.
    function test_withdraw() external {

        addReward();
        pledgeOnPreLaunch();
        pledgeForAReward();
        pledgeWithoutAReward();
        claimRefund();
        disburseFees();
        Vm.Log[] memory entries = withdraw();

        address to = address(uint160(uint(entries[1].topics[1])));
        uint256 amount;

        (amount) = abi.decode(entries[1].data, (uint256));

        assertEq(users.creator1Address, to);
        assertEq(7_007e17, amount);
    }
}