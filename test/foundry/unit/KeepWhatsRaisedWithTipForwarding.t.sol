// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../integration/KeepWhatsRaisedWithTipForwarding/KeepWhatsRaisedWithTipForwarding.t.sol";
import "forge-std/Test.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {KeepWhatsRaisedWithTipForwarding} from "src/treasuries/KeepWhatsRaisedWithTipForwarding.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PermitData} from "src/interfaces/IPermit2.sol";

contract KeepWhatsRaisedWithTipForwarding_UnitTest is Test, KWRTipForwarding_Integration_Shared_Test {
    // Test constants
    uint256 internal constant TEST_PLEDGE_AMOUNT = 1000e18;
    uint256 internal constant TEST_TIP_AMOUNT = 50e18;
    bytes32 internal constant TEST_REWARD_NAME = keccak256("testReward");
    bytes32 internal constant TEST_PLEDGE_ID = keccak256("testPledgeId");

    function setUp() public virtual override {
        super.setUp();
        deal(address(testToken), users.backer1Address, 100_000e18);
        deal(address(testToken), users.backer2Address, 100_000e18);
        deal(address(testToken), users.platform2AdminAddress, 100_000e18);

        // Label addresses
        vm.label(users.protocolAdminAddress, "ProtocolAdmin");
        vm.label(users.platform2AdminAddress, "PlatformAdmin");
        vm.label(users.contractOwner, "CampaignOwner");
        vm.label(users.backer1Address, "Backer1");
        vm.label(users.backer2Address, "Backer2");
        vm.label(address(keepWhatsRaised), "KeepWhatsRaisedWithTipForwarding");
        vm.label(address(globalParams), "GlobalParams");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setupReward() internal {
        bytes32[] memory rewardNames = new bytes32[](1);
        rewardNames[0] = TEST_REWARD_NAME;

        Reward[] memory rewards = new Reward[](1);
        rewards[0] = _createTestReward(TEST_PLEDGE_AMOUNT, true, false);

        vm.prank(users.creator1Address);
        keepWhatsRaised.addRewards(rewardNames, rewards);
    }

    function _createTestReward(uint256 value, bool isRewardTier, bool canBeAddOn) internal pure returns (Reward memory) {
        bytes32[] memory itemIds = new bytes32[](1);
        uint256[] memory itemValues = new uint256[](1);
        uint256[] memory itemQuantities = new uint256[](1);

        itemIds[0] = keccak256("testItem");
        itemValues[0] = value;
        itemQuantities[0] = 1;

        return Reward({
            rewardValue: value,
            isRewardTier: isRewardTier,
            canBeAddOn: canBeAddOn,
            itemId: itemIds,
            itemValue: itemValues,
            itemQuantity: itemQuantities
        });
    }

    /*//////////////////////////////////////////////////////////////
                    setFeeAndPledge — ADMIN PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin path, non-reward pledge: tip is deducted from pledgeAmount.
    ///         Admin sends only (pledgeAmount - tip) to treasury.
    function testSetFeeAndPledge_WithoutReward_TipDeducted() public {
        vm.warp(LAUNCH_TIME);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBalanceBefore = testToken.balanceOf(treasuryAddress);

        uint256 effectivePledge = TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT; // 950e18

        // Set gateway fee and pledge (admin path, no reward)
        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT, // pledgeAmount includes tip for non-reward
            TEST_TIP_AMOUNT,
            0, // no gateway fee
            emptyReward,
            false // isPledgeForAReward = false
        );
        vm.stopPrank();

        // Admin balance decreased by effectivePledge (tip stays with admin)
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore - effectivePledge,
            "Admin balance should decrease by effectivePledge only"
        );
        // Treasury received effectivePledge
        assertEq(
            testToken.balanceOf(treasuryAddress),
            treasuryBalanceBefore + effectivePledge,
            "Treasury balance should increase by effectivePledge"
        );
    }

    /// @notice Admin path, reward pledge: tip is separate and stays with admin.
    ///         Admin sends only rewardValue (1000e18), not rewardValue + tip.
    function testSetFeeAndPledge_WithReward_TipStaysWithAdmin() public {
        _setupReward();
        vm.warp(LAUNCH_TIME);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            0, // ignored for reward pledges
            TEST_TIP_AMOUNT,
            0,
            rewardSelection,
            true
        );
        vm.stopPrank();

        // Admin balance decreased by exactly rewardValue (1000e18), not rewardValue + tip
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore - TEST_PLEDGE_AMOUNT,
            "Admin balance should decrease by rewardValue only, not rewardValue + tip"
        );
    }

    /// @notice Admin path, zero tip: behaves like base contract.
    function testSetFeeAndPledge_ZeroTip() public {
        vm.warp(LAUNCH_TIME);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            0, // zero tip
            0,
            emptyReward,
            false
        );
        vm.stopPrank();

        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore - TEST_PLEDGE_AMOUNT,
            "Admin balance should decrease by full pledgeAmount with zero tip"
        );
    }

    /// @notice After a non-reward pledge with tip, raisedAmount = effectivePledge.
    function testSetFeeAndPledge_TipStateUpdated() public {
        vm.warp(LAUNCH_TIME);

        uint256 effectivePledge = TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT;

        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            emptyReward,
            false
        );
        vm.stopPrank();

        assertEq(
            keepWhatsRaised.getRaisedAmount(),
            effectivePledge,
            "raisedAmount should equal effectivePledge (pledgeAmount - tip)"
        );
    }

    /// @notice Revert when tip exceeds pledgeAmount for non-reward admin path.
    function testSetFeeAndPledge_RevertsWhenTipExceedsPledge() public {
        vm.warp(LAUNCH_TIME);

        uint256 excessiveTip = TEST_PLEDGE_AMOUNT + 1;

        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + excessiveTip);

        vm.expectRevert(
            abi.encodeWithSelector(
                KeepWhatsRaisedWithTipForwarding.TipExceedsPledgeAmount.selector,
                excessiveTip,
                TEST_PLEDGE_AMOUNT
            )
        );
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            excessiveTip,
            0,
            emptyReward,
            false
        );
        vm.stopPrank();
    }

    /// @notice Admin path: tip == pledgeAmount => effective pledge = 0, admin sends 0 tokens.
    function testSetFeeAndPledge_TipEqualsPledge() public {
        vm.warp(LAUNCH_TIME);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT * 2);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_PLEDGE_AMOUNT, // tip == pledgeAmount
            0,
            emptyReward,
            false
        );
        vm.stopPrank();

        // Admin sends 0 tokens (effective pledge is 0)
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore,
            "Admin balance should be unchanged when tip equals pledgeAmount"
        );
        assertEq(
            keepWhatsRaised.getRaisedAmount(),
            0,
            "raisedAmount should be 0 when tip equals pledgeAmount"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    PERMIT2 PATH — TIP FORWARDED
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit2 path: pledge with reward + tip => tip forwarded to admin.
    function testPledgeForAReward_TipForwardedToAdmin() public {
        _setupReward();

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBalanceBefore = testToken.balanceOf(treasuryAddress);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_TIP_AMOUNT,
            rewardSelection,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_TIP_AMOUNT,
            rewardSelection,
            permitData
        );
        vm.stopPrank();

        // Admin received the tip
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore + TEST_TIP_AMOUNT,
            "PlatformAdmin should receive the forwarded tip"
        );
        // Treasury holds only the pledge amount (tip was forwarded out)
        assertEq(
            testToken.balanceOf(treasuryAddress),
            treasuryBalanceBefore + TEST_PLEDGE_AMOUNT,
            "Treasury should hold only the pledge amount, not the tip"
        );
    }

    /// @notice Permit2 path: pledge without reward + tip => tip forwarded to admin.
    function testPledgeWithoutAReward_TipForwardedToAdmin() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        uint256 treasuryBalanceBefore = testToken.balanceOf(treasuryAddress);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            permitData
        );
        vm.stopPrank();

        // Admin received the tip
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore + TEST_TIP_AMOUNT,
            "PlatformAdmin should receive the forwarded tip"
        );
        // Treasury holds only the pledge amount
        assertEq(
            testToken.balanceOf(treasuryAddress),
            treasuryBalanceBefore + TEST_PLEDGE_AMOUNT,
            "Treasury should hold only the pledge amount, not the tip"
        );
    }

    /// @notice Permit2 path: zero tip => no forwarding, admin balance unchanged.
    function testPledgeForAReward_ZeroTip_NoForwarding() public {
        _setupReward();

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            0, // zero tip
            rewardSelection,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            0,
            rewardSelection,
            permitData
        );
        vm.stopPrank();

        // Admin balance unchanged (no tip forwarded)
        assertEq(
            testToken.balanceOf(users.platform2AdminAddress),
            adminBalanceBefore,
            "Admin balance should be unchanged with zero tip"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Two pledges (admin non-reward + Permit2 reward): raisedAmount excludes tips.
    function testRaisedAmountExcludesTips_BothPaths() public {
        _setupReward();

        // --- Pledge 1: Admin path, non-reward, pledge=500e18, tip=50e18 ---
        bytes32 pledgeId1 = keccak256("adminPledge1");
        uint256 pledge1Amount = 500e18;
        uint256 tip1 = 50e18;
        uint256 effectivePledge1 = pledge1Amount - tip1; // 450e18

        vm.warp(LAUNCH_TIME);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, pledge1Amount + tip1);
        keepWhatsRaised.setFeeAndPledge(
            pledgeId1, users.backer1Address, address(testToken), pledge1Amount, tip1, 0, emptyReward, false
        );
        vm.stopPrank();

        // --- Pledge 2: Permit2 path, reward, tip=30e18 ---
        bytes32 pledgeId2 = keccak256("permit2Pledge1");
        uint256 tip2 = 30e18;
        uint256 effectivePledge2 = TEST_PLEDGE_AMOUNT; // 1000e18 (reward value)

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), pledgeId2, 0);

        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + tip2);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address, address(testToken), pledgeId2, tip2, rewardSelection, 0, block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            pledgeId2, users.backer1Address, address(testToken), tip2, rewardSelection, permitData
        );
        vm.stopPrank();

        // raisedAmount = 450 + 1000 = 1450e18
        assertEq(
            keepWhatsRaised.getRaisedAmount(),
            effectivePledge1 + effectivePledge2,
            "raisedAmount should equal sum of effective pledges (tips excluded)"
        );
    }

    /// @notice Permit2 pledge with tip, then refund: refund <= pledge amount, no tip in refund.
    function testRefundExcludesForwardedTip() public {
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            permitData
        );
        uint256 tokenId = 1;
        vm.stopPrank();

        uint256 backerBalanceBefore = testToken.balanceOf(users.backer1Address);

        // Warp to refund window (after deadline, within refund delay)
        vm.warp(DEADLINE + 1);

        // Approve treasury to burn NFT and claim refund
        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);

        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);

        uint256 refundReceived = testToken.balanceOf(users.backer1Address) - backerBalanceBefore;

        // Refund should be <= pledge amount (fees deducted from pledge, tip not included)
        assertTrue(
            refundReceived <= TEST_PLEDGE_AMOUNT,
            "Refund should not exceed pledge amount (no tip in refund)"
        );
        assertTrue(refundReceived > 0, "Refund should be non-zero");
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin path: tip tokens never enter treasury.
    function testNoTipTokensInTreasury_AdminPath() public {
        vm.warp(LAUNCH_TIME);

        uint256 effectivePledge = TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT;

        bytes32[] memory emptyReward = new bytes32[](0);

        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            emptyReward,
            false
        );
        vm.stopPrank();

        assertEq(
            testToken.balanceOf(treasuryAddress),
            effectivePledge,
            "Treasury balance should be exactly effectivePledge, no tip tokens"
        );
    }

    /// @notice Multiple pledges across both paths: accounting stays correct.
    function testMultiplePledges_AccountingCorrect() public {
        _setupReward();

        // --- Pledge 1: Admin path, non-reward, tip=50e18 ---
        bytes32 pledgeId1 = keccak256("multi1");
        uint256 effectivePledge1 = TEST_PLEDGE_AMOUNT - TEST_TIP_AMOUNT; // 950e18

        vm.warp(LAUNCH_TIME);

        bytes32[] memory emptyReward = new bytes32[](0);
        vm.startPrank(users.platform2AdminAddress);
        testToken.approve(treasuryAddress, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);
        keepWhatsRaised.setFeeAndPledge(
            pledgeId1, users.backer1Address, address(testToken), TEST_PLEDGE_AMOUNT, TEST_TIP_AMOUNT, 0, emptyReward, false
        );
        vm.stopPrank();

        // --- Pledge 2: Permit2 path, reward, tip=50e18 ---
        bytes32 pledgeId2 = keccak256("multi2");
        uint256 effectivePledge2 = TEST_PLEDGE_AMOUNT; // 1000e18 (reward value)

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), pledgeId2, 0);

        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        bytes32[] memory rewardSelection = new bytes32[](1);
        rewardSelection[0] = TEST_REWARD_NAME;

        PermitData memory permitData1 = _buildSignedKeepWhatsRaisedRewardPermitData(
            users.backer1Address, address(testToken), pledgeId2, TEST_TIP_AMOUNT, rewardSelection, 0, block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeForAReward(
            pledgeId2, users.backer1Address, address(testToken), TEST_TIP_AMOUNT, rewardSelection, permitData1
        );
        vm.stopPrank();

        // --- Pledge 3: Permit2 path, no reward, zero tip ---
        bytes32 pledgeId3 = keccak256("multi3");
        uint256 pledge3Amount = 500e18;
        uint256 effectivePledge3 = pledge3Amount; // no tip

        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), pledgeId3, 0);

        vm.startPrank(users.backer2Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, pledge3Amount);

        PermitData memory permitData2 = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer2Address, address(testToken), pledgeId3, pledge3Amount, 0, 0, block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeWithoutAReward(
            pledgeId3, users.backer2Address, address(testToken), pledge3Amount, 0, permitData2
        );
        vm.stopPrank();

        uint256 expectedTotalRaised = effectivePledge1 + effectivePledge2 + effectivePledge3;

        assertEq(
            keepWhatsRaised.getRaisedAmount(),
            expectedTotalRaised,
            "Total raisedAmount should be sum of effective pledges"
        );

        // Treasury balance = effectivePledge1 (admin path) + effectivePledge2 (Permit2, tip forwarded out)
        //                    + effectivePledge3 (Permit2, zero tip)
        assertEq(
            testToken.balanceOf(treasuryAddress),
            expectedTotalRaised,
            "Treasury balance should match total raised (all tips excluded)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    EXISTING BEHAVIOR PRESERVED
    //////////////////////////////////////////////////////////////*/

    /// @notice Disburse fees works with the tip-forwarding variant.
    function testDisburseFees_WorksWithForwardingVariant() public {
        // Setup: pledge via Permit2 path
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, 0);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            permitData
        );
        vm.stopPrank();

        // Approve withdrawal and withdraw to generate fees
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.approveWithdrawal();

        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0);

        uint256 protocolBalanceBefore = testToken.balanceOf(users.protocolAdminAddress);
        uint256 platformBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);

        // Disburse fees
        keepWhatsRaised.disburseFees();

        // Verify fees were distributed
        assertTrue(
            testToken.balanceOf(users.protocolAdminAddress) > protocolBalanceBefore,
            "Protocol should receive fees after disburse"
        );
        assertTrue(
            testToken.balanceOf(users.platform2AdminAddress) > platformBalanceBefore,
            "Platform should receive fees after disburse"
        );
    }

    /// @notice Cancel + refund works with the tip-forwarding variant.
    function testCancelAndRefund_WorksWithForwardingVariant() public {
        // Pledge via Permit2
        setPaymentGatewayFee(users.platform2AdminAddress, address(keepWhatsRaised), TEST_PLEDGE_ID, PAYMENT_GATEWAY_FEE);

        vm.warp(LAUNCH_TIME);
        vm.startPrank(users.backer1Address);
        testToken.approve(CANONICAL_PERMIT2_ADDRESS, TEST_PLEDGE_AMOUNT + TEST_TIP_AMOUNT);

        PermitData memory permitData = _buildSignedKeepWhatsRaisedNoRewardPermitData(
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_ID,
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            0,
            block.timestamp + 1 hours
        );
        keepWhatsRaised.pledgeWithoutAReward(
            TEST_PLEDGE_ID,
            users.backer1Address,
            address(testToken),
            TEST_PLEDGE_AMOUNT,
            TEST_TIP_AMOUNT,
            permitData
        );
        uint256 tokenId = 1;
        vm.stopPrank();

        // Cancel treasury
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.cancelTreasury(keccak256("cancelled"));

        uint256 backerBalanceBefore = testToken.balanceOf(users.backer1Address);

        // Claim refund
        vm.warp(block.timestamp + 1);

        vm.prank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);

        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);

        uint256 refundReceived = testToken.balanceOf(users.backer1Address) - backerBalanceBefore;

        // Refund succeeds and is <= pledge amount (no tip in refund)
        assertTrue(refundReceived > 0, "Refund should succeed and be non-zero");
        assertTrue(
            refundReceived <= TEST_PLEDGE_AMOUNT,
            "Refund should not exceed original pledge amount"
        );
    }
}
