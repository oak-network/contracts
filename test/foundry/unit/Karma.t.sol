// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {KARMA} from "src/tokens/Karma.sol";

/// @notice Mock treasury that returns a configurable raised amount for claimTokens tests.
contract MockKarmaTreasury {
    uint256 public raisedAmount;

    function setRaisedAmount(uint256 _amount) external {
        raisedAmount = _amount;
    }

    function getRaisedAmount() external view returns (uint256) {
        return raisedAmount;
    }
}

contract Karma_UnitTest is Test {
    KARMA internal karma;

    address internal admin;
    address internal minter;
    address internal pauser;
    address internal holder;
    address internal other;

    uint256 internal constant MINT_AMOUNT = 1_000e18;

    // PAUSER_ROLE is private in KARMA; use same value for grant/check in tests
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        pauser = makeAddr("pauser");
        holder = makeAddr("holder");
        other = makeAddr("other");

        vm.prank(admin);
        karma = new KARMA(admin);

        // Grant roles for tests that need them (admin has all by default)
        vm.startPrank(admin);
        karma.grantRole(karma.MINTER_ROLE(), minter);
        karma.grantRole(PAUSER_ROLE, pauser);
        vm.stopPrank();
    }

    // ─── Constructor & metadata ─────────────────────────────────────────────

    function test_Constructor_SetsAdminAndRoles() public {
        assertTrue(karma.hasRole(karma.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(karma.hasRole(karma.MINTER_ROLE(), admin));
        assertTrue(karma.hasRole(PAUSER_ROLE, admin));
        assertEq(karma.name(), "KARMA");
        assertEq(karma.symbol(), "KARMA");
        assertEq(karma.decimals(), 18);
    }

    function test_Constructor_TotalSupplyZero() public {
        assertEq(karma.totalSupply(), 0);
    }

    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(KARMA.KarmaInvalidAdmin.selector);
        new KARMA(address(0));
    }

    // ─── Mint ───────────────────────────────────────────────────────────────

    function test_Mint_ByMinter_IncreasesBalance() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        assertEq(karma.balanceOf(holder), MINT_AMOUNT);
        assertEq(karma.totalSupply(), MINT_AMOUNT);
    }

    function test_Mint_ByAdmin_Succeeds() public {
        vm.prank(admin);
        karma.mint(holder, MINT_AMOUNT);
        assertEq(karma.balanceOf(holder), MINT_AMOUNT);
    }

    function test_Mint_ByNonMinter_Reverts() public {
        vm.prank(holder);
        vm.expectRevert();
        karma.mint(holder, MINT_AMOUNT);
    }

    function test_Mint_ToZeroAddress_Reverts() public {
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaInvalidMintInput.selector);
        karma.mint(address(0), MINT_AMOUNT);
    }

    function test_Mint_ZeroAmount_Reverts() public {
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaInvalidMintInput.selector);
        karma.mint(holder, 0);
    }

    function test_Mint_CanMintMultipleTimes() public {
        vm.startPrank(minter);
        karma.mint(holder, 100e18);
        karma.mint(holder, 200e18);
        karma.mint(other, 50e18);
        vm.stopPrank();
        assertEq(karma.balanceOf(holder), 300e18);
        assertEq(karma.balanceOf(other), 50e18);
        assertEq(karma.totalSupply(), 350e18);
    }

    // ─── Soulbound: no transfers ────────────────────────────────────────────

    function test_Transfer_RevertsWithSoulboundError() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(holder);
        vm.expectRevert(KARMA.KarmaSoulboundTransferNotAllowed.selector);
        karma.transfer(other, 100e18);
    }

    function test_TransferFrom_RevertsWithSoulboundError() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(holder);
        karma.approve(other, MINT_AMOUNT);
        vm.prank(other);
        vm.expectRevert(KARMA.KarmaSoulboundTransferNotAllowed.selector);
        karma.transferFrom(holder, other, 100e18);
    }

    // ─── Burn ───────────────────────────────────────────────────────────────

    function test_Burn_ByHolder_DecreasesBalance() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(holder);
        karma.burn(500e18);
        assertEq(karma.balanceOf(holder), 500e18);
        assertEq(karma.totalSupply(), 500e18);
    }

    function test_Burn_AllBalance() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(holder);
        karma.burn(MINT_AMOUNT);
        assertEq(karma.balanceOf(holder), 0);
        assertEq(karma.totalSupply(), 0);
    }

    function test_Burn_ExceedsBalance_Reverts() public {
        vm.prank(minter);
        karma.mint(holder, 100e18);
        vm.prank(holder);
        vm.expectRevert();
        karma.burn(200e18);
    }

    function test_Burn_From_ByHolder_DecreasesBalance() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(holder);
        karma.approve(holder, 300e18); // approve self for burnFrom
        vm.prank(holder);
        karma.burnFrom(holder, 300e18);
        assertEq(karma.balanceOf(holder), 700e18);
    }

    function test_BurnFrom_WithoutAllowance_Reverts() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(other);
        vm.expectRevert();
        karma.burnFrom(holder, 100e18);
    }

    // ─── Pause / Unpause ─────────────────────────────────────────────────────

    function test_Pause_ByPauser_Succeeds() public {
        vm.prank(pauser);
        karma.pause();
        assertTrue(karma.paused());
    }

    function test_Pause_ByAdmin_Succeeds() public {
        vm.prank(admin);
        karma.pause();
        assertTrue(karma.paused());
    }

    function test_Pause_ByNonPauser_Reverts() public {
        vm.prank(holder);
        vm.expectRevert();
        karma.pause();
    }

    function test_Unpause_ByPauser_Succeeds() public {
        vm.prank(pauser);
        karma.pause();
        vm.prank(pauser);
        karma.unpause();
        assertFalse(karma.paused());
    }

    function test_WhenPaused_Mint_Reverts() public {
        vm.prank(pauser);
        karma.pause();
        vm.prank(minter);
        vm.expectRevert();
        karma.mint(holder, MINT_AMOUNT);
    }

    function test_WhenPaused_Burn_Reverts() public {
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        vm.prank(pauser);
        karma.pause();
        vm.prank(holder);
        vm.expectRevert();
        karma.burn(100e18);
    }

    function test_Unpause_AllowsMintAndBurnAgain() public {
        vm.prank(pauser);
        karma.pause();
        vm.prank(pauser);
        karma.unpause();
        vm.prank(minter);
        karma.mint(holder, MINT_AMOUNT);
        assertEq(karma.balanceOf(holder), MINT_AMOUNT);
        vm.prank(holder);
        karma.burn(100e18);
        assertEq(karma.balanceOf(holder), MINT_AMOUNT - 100e18);
    }

    // ─── AccessControl ─────────────────────────────────────────────────────

    function test_Admin_CanGrantMinterRole() public {
        address newMinter = makeAddr("newMinter");
        bytes32 minterRole = karma.MINTER_ROLE();
        assertFalse(karma.hasRole(minterRole, newMinter));
        vm.prank(admin);
        karma.grantRole(minterRole, newMinter);
        assertTrue(karma.hasRole(minterRole, newMinter));
        vm.prank(newMinter);
        karma.mint(holder, 1e18);
        assertEq(karma.balanceOf(holder), 1e18);
    }

    function test_Admin_CanRevokeMinterRole() public {
        bytes32 minterRole = karma.MINTER_ROLE();
        vm.prank(admin);
        karma.revokeRole(minterRole, minter);
        vm.prank(minter);
        vm.expectRevert();
        karma.mint(holder, MINT_AMOUNT);
    }

    function test_NonAdmin_CannotGrantRole() public {
        bytes32 minterRole = karma.MINTER_ROLE();
        vm.prank(holder);
        vm.expectRevert();
        karma.grantRole(minterRole, holder);
    }

    function test_Admin_CanGrantPauserRole() public {
        address newPauser = makeAddr("newPauser");
        assertFalse(karma.hasRole(PAUSER_ROLE, newPauser));
        vm.prank(admin);
        karma.grantRole(PAUSER_ROLE, newPauser);
        assertTrue(karma.hasRole(PAUSER_ROLE, newPauser));
        vm.prank(newPauser);
        karma.pause();
        assertTrue(karma.paused());
    }

    function test_Admin_CanRevokePauserRole() public {
        vm.prank(admin);
        karma.revokeRole(PAUSER_ROLE, pauser);
        vm.prank(pauser);
        vm.expectRevert();
        karma.pause();
    }

    // ─── Role constants ─────────────────────────────────────────────────────

    function test_MINTER_ROLE_MatchesExpectedHash() public {
        assertEq(karma.MINTER_ROLE(), keccak256("MINTER_ROLE"));
    }

    function test_PAUSER_ROLE_MatchesExpectedHash() public {
        assertEq(PAUSER_ROLE, keccak256("PAUSER_ROLE"));
    }

    function test_Unpause_ByNonPauser_Reverts() public {
        vm.prank(pauser);
        karma.pause();
        vm.prank(holder);
        vm.expectRevert();
        karma.unpause();
    }

    // ─── claimTokens & treasury ─────────────────────────────────────────────

    function test_ClaimTokens_WithoutTreasurySet_Reverts() public {
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaTreasuryNotSet.selector);
        karma.claimTokens(holder);
    }

    function test_ClaimTokens_ToZeroAddress_Reverts() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(100e18);
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaInvalidMintInput.selector);
        karma.claimTokens(address(0));
    }

    function test_ClaimTokens_NothingToClaim_Reverts() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(0);
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaNothingToClaim.selector);
        karma.claimTokens(holder);
    }

    function test_ClaimTokens_MintsDelta_FirstClaim() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(300e18); // 100 + 200 as in example
        vm.prank(minter);
        karma.claimTokens(holder);
        assertEq(karma.balanceOf(holder), 300e18);
        assertEq(karma.totalMintedAgainstRaised(), 300e18);
    }

    function test_ClaimTokens_MintsOnlyDelta_SecondClaim() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(300e18);
        vm.prank(minter);
        karma.claimTokens(holder);
        assertEq(karma.balanceOf(holder), 300e18);
        // Simulate more payments: raised goes to 500 (300 + 100 + 100)
        mockTreasury.setRaisedAmount(500e18);
        vm.prank(minter);
        karma.claimTokens(holder);
        assertEq(karma.balanceOf(holder), 500e18); // 300 + 200 delta
        assertEq(karma.totalMintedAgainstRaised(), 500e18);
    }

    function test_ClaimTokens_MultipleCalls_Incremental() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(100e18);
        vm.prank(minter);
        karma.claimTokens(holder);
        assertEq(karma.balanceOf(holder), 100e18);
        mockTreasury.setRaisedAmount(300e18);
        vm.prank(minter);
        karma.claimTokens(holder);
        assertEq(karma.balanceOf(holder), 300e18);
        mockTreasury.setRaisedAmount(300e18);
        vm.prank(minter);
        vm.expectRevert(KARMA.KarmaNothingToClaim.selector);
        karma.claimTokens(holder);
    }

    function test_ClaimTokens_WhenPaused_Reverts() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(100e18);
        vm.prank(pauser);
        karma.pause();
        vm.prank(minter);
        vm.expectRevert();
        karma.claimTokens(holder);
    }

    function test_ClaimTokens_ByNonMinter_Reverts() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(100e18);
        vm.prank(holder);
        vm.expectRevert();
        karma.claimTokens(holder);
    }

    function test_SetTreasury_ByAdmin_Succeeds() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        assertEq(karma.treasury(), address(0));
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit KARMA.TreasurySet(address(0), address(mockTreasury));
        karma.setTreasury(address(mockTreasury));
        assertEq(karma.treasury(), address(mockTreasury));
    }

    function test_SetTreasury_EmitsTreasurySet() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        MockKarmaTreasury mockTreasury2 = new MockKarmaTreasury();
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit KARMA.TreasurySet(address(mockTreasury), address(mockTreasury2));
        karma.setTreasury(address(mockTreasury2));
    }

    function test_ClaimTokens_EmitsTokensClaimed() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(admin);
        karma.setTreasury(address(mockTreasury));
        mockTreasury.setRaisedAmount(300e18);
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit KARMA.TokensClaimed(holder, 300e18);
        karma.claimTokens(holder);
    }

    function test_SetTreasury_ByNonAdmin_Reverts() public {
        MockKarmaTreasury mockTreasury = new MockKarmaTreasury();
        vm.prank(holder);
        vm.expectRevert();
        karma.setTreasury(address(mockTreasury));
    }

    function test_TotalMintedAgainstRaised_StartsZero() public {
        assertEq(karma.totalMintedAgainstRaised(), 0);
    }
}
