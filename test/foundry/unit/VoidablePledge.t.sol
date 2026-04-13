// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../integration/KeepWhatsRaised/KeepWhatsRaised.t.sol";
import "forge-std/Test.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {VoidablePledge} from "src/utils/VoidablePledge.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {IReward} from "src/interfaces/IReward.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VoidablePledge_Test
 * @notice Unit tests for the VoidablePledge module as integrated into KeepWhatsRaised.
 *
 * Fee math reference (18-decimal token / cUSD, PLEDGE_AMOUNT = 1000e18, GATEWAY_FEE = 40e18):
 *   Protocol fee     (20%)        = 200e18   → s_protocolFeePerToken
 *   Platform gross % (10%+6%=16%) = 160e18   ┐
 *   Gateway fee                   =  40e18   ┘ → s_platformFeePerToken = 200e18
 *   Total fee                                = 400e18
 *   Net available                            = 600e18
 *   _recordPledgeFees stores: protocolFee=200e18, platformFee=200e18
 *
 * Full void (before any disbursement / withdrawal): totalRecoverable = 1000e18
 */
contract VoidablePledge_Test is Test, KeepWhatsRaised_Integration_Shared_Test {

    // ── Constants ──────────────────────────────────────────────────────────

    uint256 internal constant VOID_PLEDGE_AMOUNT = 1000e18;
    uint256 internal constant VOID_TIP_AMOUNT    = 50e18;

    // Fee components (derived from Defaults: PROTOCOL=20%, PLATFORM=10%, VAKI=6%, GATEWAY=40e18)
    uint256 internal constant EXPECTED_PROTOCOL_FEE  = 200e18; // 20% of 1000
    uint256 internal constant EXPECTED_PLATFORM_FEE  = 200e18; // 16% + gateway = 160+40
    uint256 internal constant EXPECTED_TOTAL_FEE     = 400e18;
    uint256 internal constant EXPECTED_NET_AVAILABLE = 600e18;

    bytes32 internal constant PLEDGE_ID_A = keccak256("pledgeA");
    bytes32 internal constant PLEDGE_ID_B = keccak256("pledgeB");
    bytes32 internal constant PLEDGE_ID_C = keccak256("pledgeC");
    bytes32 internal constant VOID_REASON  = keccak256("FRAUD");

    // ── setUp ──────────────────────────────────────────────────────────────

    function setUp() public virtual override {
        super.setUp();
        // Ensure platform admin has ample cUSD for setFeeAndPledge
        deal(address(testToken), users.platform2AdminAddress, 10_000_000e18);
        deal(address(testToken), users.backer1Address, 10_000_000e18);
        deal(address(testToken), users.backer2Address, 10_000_000e18);
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    /// @dev Makes a single without-reward pledge via the admin setFeeAndPledge path.
    ///      Treasury must be within campaign window; caller is responsible for vm.warp.
    function _pledge(address backer, bytes32 pledgeId, uint256 amount, uint256 tip)
        internal
        returns (uint256 tokenId)
    {
        bytes32[] memory emptyReward = new bytes32[](0);
        (, tokenId,) = setFeeAndPledge(
            users.platform2AdminAddress,
            address(keepWhatsRaised),
            pledgeId,
            backer,
            amount,
            tip,
            PAYMENT_GATEWAY_FEE,
            emptyReward,
            false
        );
    }

    /// @dev Convenience: warp to LAUNCH_TIME and make a pledge with no tip.
    function _pledgeAtLaunch(address backer, bytes32 pledgeId) internal returns (uint256 tokenId) {
        vm.warp(LAUNCH_TIME);
        tokenId = _pledge(backer, pledgeId, PLEDGE_AMOUNT, 0);
    }

    /// @dev Calls voidPledge as platform admin.
    function _void(uint256 tokenId, bytes32 reason) internal {
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId, reason);
    }

    /// @dev Approves withdrawal and does a partial withdraw before deadline.
    ///      Returns the actual available balance decremented.
    function _doPartialWithdrawal(uint256 amount) internal {
        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_RevertsIfCalledByNonAdmin() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.expectRevert();
        vm.prank(users.backer1Address);
        keepWhatsRaised.voidPledge(tokenId, VOID_REASON);
    }

    function test_voidPledge_RevertsIfCalledByCampaignOwner() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.expectRevert();
        vm.prank(users.creator1Address);
        keepWhatsRaised.voidPledge(tokenId, VOID_REASON);
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_RevertsOnNonExistentToken() public {
        uint256 fakeTokenId = 9999;
        vm.expectRevert(abi.encodeWithSelector(VoidablePledge.VoidablePledgeNotFound.selector, fakeTokenId));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(fakeTokenId, VOID_REASON);
    }

    function test_voidPledge_RevertsOnAlreadyVoidedPledge() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        _void(tokenId, VOID_REASON);

        vm.expectRevert(abi.encodeWithSelector(VoidablePledge.VoidablePledgeAlreadyVoided.selector, tokenId));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId, VOID_REASON);
    }

    function test_voidPledge_RevertsOnAlreadyRefundedPledge() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Enter refund window (after deadline, before deadline + refundDelay)
        vm.warp(DEADLINE + 1);

        // backer approves the treasury to burn their NFT, then claims refund
        vm.startPrank(users.backer1Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenId);
        keepWhatsRaised.claimRefund(tokenId);
        vm.stopPrank();

        // Now pledge amount is 0 → voidPledge should revert with VoidablePledgeNotFound
        vm.expectRevert(abi.encodeWithSelector(VoidablePledge.VoidablePledgeNotFound.selector, tokenId));
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.voidPledge(tokenId, VOID_REASON);
    }

    /*//////////////////////////////////////////////////////////////
                    BASIC SUCCESS — STATE MUTATIONS
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_SetsVoidFlag() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        assertFalse(keepWhatsRaised.isPledgeVoided(tokenId), "should not be voided before void");
        _void(tokenId, VOID_REASON);
        assertTrue(keepWhatsRaised.isPledgeVoided(tokenId), "should be voided after void");
    }

    function test_voidPledge_DecrementsRaisedAmount() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT);
        _void(tokenId, VOID_REASON);
        assertEq(keepWhatsRaised.getRaisedAmount(), 0, "raised amount should be zero after void");
    }

    function test_voidPledge_DecrementsAvailableAmount() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), EXPECTED_NET_AVAILABLE);
        _void(tokenId, VOID_REASON);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0, "available should be zero after void");
    }

    function test_voidPledge_ReversesFeeAccruals() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Confirm fees exist before void (check via disburseFees output)
        (,, uint256 protocolBefore, uint256 platformBefore) = _captureFeeBuckets();
        assertEq(protocolBefore, EXPECTED_PROTOCOL_FEE,  "protocol fee before void");
        assertEq(platformBefore, EXPECTED_PLATFORM_FEE,  "platform fee before void");

        _void(tokenId, VOID_REASON);

        // After void both buckets must be zero
        (,, uint256 protocolAfter, uint256 platformAfter) = _captureFeeBuckets();
        assertEq(protocolAfter, 0, "protocol fee bucket should be empty after void");
        assertEq(platformAfter, 0, "platform fee bucket should be empty after void");
    }

    function test_voidPledge_TransfersFullRecoverableAmountToPlatformAdmin() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        uint256 adminBalanceBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminBalanceAfter = testToken.balanceOf(users.platform2AdminAddress);

        // Full pledge amount recovered since no fees have left yet
        assertEq(adminBalanceAfter - adminBalanceBefore, PLEDGE_AMOUNT, "admin should receive full pledge back");
    }

    function test_voidPledge_EmitsPledgeVoidedEvent() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.expectEmit(true, true, false, true, address(keepWhatsRaised));
        emit VoidablePledge.PledgeVoided(tokenId, address(testToken), PLEDGE_AMOUNT, VOID_REASON);

        _void(tokenId, VOID_REASON);
    }

    function test_voidPledge_AccumulatesVoidedAmountInView() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        assertEq(keepWhatsRaised.getVoidedAmount(), 0, "voided should be zero before void");
        _void(tokenId, VOID_REASON);
        assertEq(keepWhatsRaised.getVoidedAmount(), PLEDGE_AMOUNT, "voided should equal pledge amount");
    }

    function test_voidPledge_ContractBalanceIsZeroAfterFullRecovery() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        uint256 contractBefore = testToken.balanceOf(address(keepWhatsRaised));
        assertEq(contractBefore, PLEDGE_AMOUNT, "contract should hold pledge amount");

        _void(tokenId, VOID_REASON);

        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0, "contract balance should be zero after full recovery");
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM REFUND BLOCKED AFTER VOID
    //////////////////////////////////////////////////////////////*/

    function test_claimRefund_RevertsForVoidedPledge() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        _void(tokenId, VOID_REASON);

        // The whenPledgeNotVoided modifier triggers before any timing check
        vm.expectRevert(
            abi.encodeWithSelector(VoidablePledge.VoidablePledgeAlreadyVoided.selector, tokenId)
        );
        vm.prank(users.backer1Address);
        keepWhatsRaised.claimRefund(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
              FEE DISBURSEMENT INTERACTION
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_FullFeeRecovery_BeforeDisburseFees() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter = testToken.balanceOf(users.platform2AdminAddress);

        // All fees still in contract → fully reversed and returned with available
        assertEq(adminAfter - adminBefore, PLEDGE_AMOUNT, "full pledge recovered before disbursement");
    }

    function test_voidPledge_PartialRecovery_AfterDisburseFees() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Disburse fees — empties protocol and platform fee buckets
        keepWhatsRaised.disburseFees();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // Fees already gone; only net available is recoverable
        assertEq(adminAfter - adminBefore, EXPECTED_NET_AVAILABLE,
            "only net available recovered after disbursement");
        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0, "treasury drained");
    }

    function test_voidPledge_FeeBucketsRemainAtZeroAfterVoidPostDisburse() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        keepWhatsRaised.disburseFees();
        _void(tokenId, VOID_REASON);

        // Fee buckets were already empty and should stay empty
        (,, uint256 protocol, uint256 platform) = _captureFeeBuckets();
        assertEq(protocol, 0, "protocol bucket stays zero");
        assertEq(platform, 0, "platform bucket stays zero");
    }

    function test_voidPledge_ZeroRecovery_AfterDisburseFeesAndClaimFund() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Drain everything: fees then available
        keepWhatsRaised.disburseFees();
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();

        // voidPledge should succeed but transfer nothing
        vm.expectEmit(true, true, false, true, address(keepWhatsRaised));
        emit VoidablePledge.PledgeVoided(tokenId, address(testToken), 0, VOID_REASON);

        _void(tokenId, VOID_REASON);

        assertEq(testToken.balanceOf(address(keepWhatsRaised)), 0, "nothing left to recover");
    }

    /*//////////////////////////////////////////////////////////////
              PARTIAL WITHDRAWAL INTERACTION (UNDERFLOW GUARD)
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_CapsAvailableReversal_AfterPartialWithdrawal() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Partial withdrawal of 200e18 before deadline.
        // Fee: cumulative flat = 200e18 (amount < minimumWithdrawalForFeeExemption).
        // Available decremented by 200 + 200 = 400 → remaining available = 200e18.
        // Platform fee bucket grows: 200(pledge) + 200(withdrawal) = 400e18.
        uint256 withdrawAmount = 200e18;
        _doPartialWithdrawal(withdrawAmount);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // availableReversed = min(600, 200)          = 200
        // protocolFeeReversed = min(200, 200)         = 200
        // platformFeeReversed = min(200, 400)         = 200  (pledge fees only, not withdrawal fee)
        // totalRecoverable                            = 600e18
        assertEq(adminAfter - adminBefore, 600e18, "recovers available + pledge fee portions");
        // Available is now 0
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0, "available zero after void");
    }

    function test_voidPledge_DoesNotUnderflowAvailableWhenCreatorWithdrewAll() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Approve + final withdrawal (after deadline)
        approveWithdrawal(users.platform2AdminAddress, address(keepWhatsRaised));
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.withdraw(address(testToken), 0); // 0 triggers final withdrawal

        // Available is now 0, only fee buckets remain
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);

        // voidPledge must not revert on uint underflow
        _void(tokenId, VOID_REASON);

        assertTrue(keepWhatsRaised.isPledgeVoided(tokenId));
    }

    /*//////////////////////////////////////////////////////////////
              CLAIM FUND INTERACTION
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_RecoversFeesBut_NotAvailable_AfterClaimFund() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // claimFund drains s_availablePerToken but fee buckets remain
        vm.warp(DEADLINE + WITHDRAWAL_DELAY + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimFund();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // availableReversed = min(600, 0) = 0; fee buckets still intact
        uint256 expectedRecoverable = EXPECTED_PROTOCOL_FEE + EXPECTED_PLATFORM_FEE; // 400e18
        assertEq(adminAfter - adminBefore, expectedRecoverable,
            "fee buckets recovered after claimFund; available already swept");
    }

    /*//////////////////////////////////////////////////////////////
              CANCELLED TREASURY
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_WorksOnCancelledTreasury() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        cancelTreasury(users.platform2AdminAddress, address(keepWhatsRaised), keccak256("FRAUD_CAMPAIGN"));

        // voidPledge has no whenNotCancelled guard — should still work
        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        assertEq(adminAfter - adminBefore, PLEDGE_AMOUNT, "full pledge recovered on cancelled treasury");
        assertTrue(keepWhatsRaised.isPledgeVoided(tokenId));
    }

    function test_voidPledge_WorksAfterDeadlineWithNoCancellation() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(DEADLINE + 1);

        _void(tokenId, VOID_REASON);
        assertTrue(keepWhatsRaised.isPledgeVoided(tokenId));
        assertEq(keepWhatsRaised.getRaisedAmount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
              TIP HANDLING
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_ReversesTip_WhenTipNotYetClaimed() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _pledge(users.backer1Address, PLEDGE_ID_A, PLEDGE_AMOUNT, TIP_AMOUNT);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // Tip is in s_tipPerToken → reversed on void
        // totalRecoverable = available(600) + protocolFee(200) + platformFee(200) + tip(50) = 1050
        assertEq(adminAfter - adminBefore, PLEDGE_AMOUNT + TIP_AMOUNT,
            "full pledge + tip recovered when tip unclaimed");
    }

    function test_voidPledge_SkipsTipReversal_AfterClaimTipCalled() public {
        vm.warp(LAUNCH_TIME);
        uint256 tokenId = _pledge(users.backer1Address, PLEDGE_ID_A, PLEDGE_AMOUNT, TIP_AMOUNT);

        // claimTip is available after deadline
        vm.warp(DEADLINE + 1);
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.claimTip();

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // s_tipClaimed = true → tipReversed = 0; only pledge amount recovered (no tip)
        assertEq(adminAfter - adminBefore, PLEDGE_AMOUNT,
            "tip not re-sent when already claimed via claimTip");
    }

    function test_voidPledge_SkipsTipReversal_WhenForwardTipsImmediatelyEnabled() public {
        // Deploy a fresh treasury configured with forwardTipsImmediately = true
        _resetTreasury();
        KeepWhatsRaised.Config memory fwdConfig = KeepWhatsRaised.Config({
            minimumWithdrawalForFeeExemption: MINIMUM_WITHDRAWAL_FOR_FEE_EXEMPTION,
            withdrawalDelay: WITHDRAWAL_DELAY,
            refundDelay: REFUND_DELAY,
            configLockPeriod: CONFIG_LOCK_PERIOD,
            isColombianCreator: false,
            forwardTipsImmediately: true
        });
        vm.prank(users.platform2AdminAddress);
        keepWhatsRaised.configureTreasury(fwdConfig, CAMPAIGN_DATA, FEE_KEYS, createFeeValues());

        vm.warp(LAUNCH_TIME);
        // When forwardTipsImmediately=true and source=platformAdmin, only pledgeAmount is
        // transferred to treasury (tip stays in admin wallet — tipFundedByAdmin=true).
        uint256 tokenId = _pledge(users.backer1Address, PLEDGE_ID_A, PLEDGE_AMOUNT, TIP_AMOUNT);

        uint256 adminBefore = testToken.balanceOf(users.platform2AdminAddress);
        _void(tokenId, VOID_REASON);
        uint256 adminAfter  = testToken.balanceOf(users.platform2AdminAddress);

        // Tip was never in the contract → not recovered (admin already had it)
        assertEq(adminAfter - adminBefore, PLEDGE_AMOUNT,
            "only pledge amount recovered; tip was forwarded at pledge time and stays with admin");
    }

    /*//////////////////////////////////////////////////////////////
              ACCOUNTING ACCURACY — getRefundedAmount / getVoidedAmount
    //////////////////////////////////////////////////////////////*/

    function test_getRefundedAmount_ExcludesVoidedAmount() public {
        uint256 tokenIdVoid   = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        // Second pledge that will be refunded
        vm.warp(LAUNCH_TIME);
        uint256 tokenIdRefund = _pledge(users.backer2Address, PLEDGE_ID_B, PLEDGE_AMOUNT, 0);

        // Void the first pledge
        _void(tokenIdVoid, VOID_REASON);

        // Refund the second pledge (in refund window)
        vm.warp(DEADLINE + 1);
        vm.startPrank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenIdRefund);
        keepWhatsRaised.claimRefund(tokenIdRefund);
        vm.stopPrank();

        // getRefundedAmount should only count the actual refund, not the void
        assertEq(keepWhatsRaised.getRefundedAmount(), PLEDGE_AMOUNT,
            "refunded amount should not include voided pledge");
        // getVoidedAmount should reflect the voided pledge
        assertEq(keepWhatsRaised.getVoidedAmount(), PLEDGE_AMOUNT,
            "voided amount should equal the voided pledge");
    }

    function test_getVoidedAmount_SumsMultipleVoidedPledges() public {
        uint256 tokenId1 = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(LAUNCH_TIME);
        uint256 tokenId2 = _pledge(users.backer2Address, PLEDGE_ID_B, PLEDGE_AMOUNT, 0);

        _void(tokenId1, VOID_REASON);
        _void(tokenId2, VOID_REASON);

        assertEq(keepWhatsRaised.getVoidedAmount(), PLEDGE_AMOUNT * 2,
            "voided amount accumulates across multiple voids");
    }

    function test_getRaisedAmount_IsZeroAfterAllPledgesVoided() public {
        uint256 tokenId1 = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(LAUNCH_TIME);
        uint256 tokenId2 = _pledge(users.backer2Address, PLEDGE_ID_B, PLEDGE_AMOUNT, 0);

        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT * 2);

        _void(tokenId1, VOID_REASON);
        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT);

        _void(tokenId2, VOID_REASON);
        assertEq(keepWhatsRaised.getRaisedAmount(), 0);
    }

    function test_getLifetimeRaisedAmount_NotAffectedByVoid() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        uint256 lifetimeBefore = keepWhatsRaised.getLifetimeRaisedAmount();
        assertEq(lifetimeBefore, PLEDGE_AMOUNT);

        _void(tokenId, VOID_REASON);

        // Lifetime raised amount intentionally never decreases (invariant preserved)
        assertEq(keepWhatsRaised.getLifetimeRaisedAmount(), PLEDGE_AMOUNT,
            "lifetime raised amount is unaffected by void (permanent history)");
    }

    /*//////////////////////////////////////////////////////////////
              MULTIPLE PLEDGES — ISOLATION
    //////////////////////////////////////////////////////////////*/

    function test_voidPledge_DoesNotAffectSiblingPledges() public {
        uint256 tokenIdA = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(LAUNCH_TIME);
        uint256 tokenIdB = _pledge(users.backer2Address, PLEDGE_ID_B, PLEDGE_AMOUNT, 0);

        // Both pledges exist: raised = 2000e18, available = 1200e18
        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT * 2);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), EXPECTED_NET_AVAILABLE * 2);

        _void(tokenIdA, VOID_REASON);

        // Only pledge A voided; pledge B intact
        assertEq(keepWhatsRaised.getRaisedAmount(), PLEDGE_AMOUNT,
            "only pledge A removed from raised amount");
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), EXPECTED_NET_AVAILABLE,
            "only pledge A removed from available");
        assertFalse(keepWhatsRaised.isPledgeVoided(tokenIdB), "pledge B should not be voided");
    }

    function test_voidPledge_ThenSiblingPledgeCanStillBeRefunded() public {
        uint256 tokenIdA = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(LAUNCH_TIME);
        uint256 tokenIdB = _pledge(users.backer2Address, PLEDGE_ID_B, PLEDGE_AMOUNT, 0);

        _void(tokenIdA, VOID_REASON);

        // Refund window opens after deadline
        vm.warp(DEADLINE + 1);

        vm.startPrank(users.backer2Address);
        CampaignInfo(campaignAddress).approve(address(keepWhatsRaised), tokenIdB);
        keepWhatsRaised.claimRefund(tokenIdB);
        vm.stopPrank();

        // Both gone; raised = 0, available = 0
        assertEq(keepWhatsRaised.getRaisedAmount(), 0);
        assertEq(keepWhatsRaised.getAvailableRaisedAmount(), 0);
    }

    function test_voidPledge_FeeBucketsIsolatedPerPledge() public {
        uint256 tokenIdA = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        vm.warp(LAUNCH_TIME);
        _pledge(users.backer2Address, PLEDGE_ID_B, VOID_PLEDGE_AMOUNT, 0);

        // Void only pledge A
        _void(tokenIdA, VOID_REASON);

        // After the void, call disburseFees once. It should pay out only pledge B's
        // fee share (200 protocol + 200 platform), because pledge A's share was reversed.
        // _captureFeeBuckets() calls disburseFees() internally and measures the payout.
        (,, uint256 protocolDisbursed, uint256 platformDisbursed) = _captureFeeBuckets();
        assertEq(protocolDisbursed, EXPECTED_PROTOCOL_FEE,
            "only pledge B protocol fee disbursed after voiding pledge A");
        assertEq(platformDisbursed, EXPECTED_PLATFORM_FEE,
            "only pledge B platform fee disbursed after voiding pledge A");
    }

    /*//////////////////////////////////////////////////////////////
              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function test_isPledgeVoided_ReturnsFalseForActiveTokenId() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);
        assertFalse(keepWhatsRaised.isPledgeVoided(tokenId));
    }

    function test_getVoidedAmountPerToken_TracksByTokenAddress() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);

        assertEq(keepWhatsRaised.getVoidedAmountPerToken(address(testToken)), 0);
        _void(tokenId, VOID_REASON);
        assertEq(keepWhatsRaised.getVoidedAmountPerToken(address(testToken)), PLEDGE_AMOUNT);
    }

    function test_getVoidedAmountPerToken_ReturnsZeroForUnrelatedToken() public {
        uint256 tokenId = _pledgeAtLaunch(users.backer1Address, PLEDGE_ID_A);
        _void(tokenId, VOID_REASON);

        // usdcToken was not used in any pledge
        assertEq(keepWhatsRaised.getVoidedAmountPerToken(address(usdcToken)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL HELPER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Reads current fee bucket balances by snapshotting balances before/after disburseFees.
     *
     *      Returns (protocolAdmin, platformAdmin, protocolBucketBalance, platformBucketBalance).
     *      NOTE: This CONSUMES the fee buckets — call only when you are done with fee state.
     */
    function _captureFeeBuckets()
        internal
        returns (address protocolAdmin, address platformAdmin, uint256 protocol, uint256 platform)
    {
        protocolAdmin = CampaignInfo(campaignAddress).getProtocolAdminAddress();
        platformAdmin = users.platform2AdminAddress;

        uint256 protocolBefore = testToken.balanceOf(protocolAdmin);
        uint256 platformBefore = testToken.balanceOf(platformAdmin);

        keepWhatsRaised.disburseFees();

        protocol = testToken.balanceOf(protocolAdmin) - protocolBefore;
        platform = testToken.balanceOf(platformAdmin) - platformBefore;
    }
}
