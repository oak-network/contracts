# P4: Tip Forwarding Module — Design & Implementation Plan

**Status:** Draft (pending SC team review)
**Branch:** `feat/p4-tip-forwarding-module`
**Proposal:** [HackMD — P2 Tip Forwarding in setFeeAndPledge](https://hackmd.io/@vaki/SypnuDM_Wg#4-P2-Tip-Forwarding-in-setFeeAndPledge)
**Date:** 2026-04-09

---

## 1. Problem Statement

The `tip` parameter in `setFeeAndPledge()` always passes as `0` on-chain, creating a mismatch with fiat gateway records. While backers pay tips in fiat, no on-chain visibility exists. The existing `claimTip()` flow requires a separate admin transaction after the campaign deadline, adding operational overhead.

## 2. Decision: Module via Hook Pattern

After analysis from 10 independent perspectives (security, gas, proxy compatibility, Permit2, accounting, factory architecture, testing, off-chain alternatives, integration, and audit), the recommendation is:

**Implement tip forwarding as an optional child contract (`KeepWhatsRaisedWithTipForwarding`) using an internal virtual hook extracted from `_pledge()`.**

### Why not the alternatives?

| Approach | Verdict | Reason |
|---|---|---|
| **Hook pattern (child contract)** | **Selected** | Minimal change to KWR, zero factory changes, backward compatible |
| Config flag in KWR | Rejected | Adds gas overhead to every pledge, complicates audited code, irreversible for existing clones |
| External wrapper contract | Rejected | Only works for admin path, breaks Permit2 path, loses NFT tip metadata |
| Strategy/plugin contract | Rejected | Over-engineered — external call overhead, trust surface, no benefit over hook |
| Zero changes ("Option 0") | Viable alternative | Just pass real tip to existing `setFeeAndPledge`. Works if immediate forwarding isn't required. **Flag this to SC team as a simpler option.** |

### Key architectural insight

Treasuries are **ERC-1167 minimal proxy clones** (not UUPS). They are non-upgradeable. The `TreasuryFactory.implementationMap` already supports multiple implementations per platform via numeric `implementationId`. **Zero factory code changes are needed** — just deploy the new child as a new implementation and register it.

---

## 3. Design

### 3.1 Changes to `KeepWhatsRaised.sol` (minimal)

**a) Extract tip handling into a virtual hook:**

In `_pledge()` (currently private), after ALL state writes and the `Receipt` event, add:

```solidity
// At end of _pledge(), AFTER line 1397 (Receipt event):
_handleTip(pledgeToken, tokenId, tip);
```

Remove the current tip storage lines (1388, 1390) and move them into the default `_handleTip`:

```solidity
/// @dev Hook for tip handling. Called at the end of _pledge() after all
///      state updates and events. Override to change tip routing.
///      MUST only be called from _pledge() or equivalent guarded context.
function _handleTip(
    address pledgeToken,
    uint256 tokenId,
    uint256 tip
) internal virtual {
    s_tokenToTippedAmount[tokenId] = tip;
    s_tipPerToken[pledgeToken] += tip;
}
```

**b) Change visibility of tip storage (private -> internal):**

```solidity
mapping(uint256 => uint256) internal s_tokenToTippedAmount;  // was private
mapping(address => uint256) internal s_tipPerToken;           // was private
```

This allows the child contract to access these if needed (e.g., for hybrid logic in the future).

**c) Make `claimTip()` virtual:**

```solidity
function claimTip() external virtual onlyPlatformAdmin(PLATFORM_HASH) ...
```

**d) CEI compliance:** The hook MUST be the last thing in `_pledge()`, after all state writes and the `Receipt` emit. This is critical for security — see Section 5.

### 3.2 New contract: `KeepWhatsRaisedWithTipForwarding.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeepWhatsRaised} from "./KeepWhatsRaised.sol";

contract KeepWhatsRaisedWithTipForwarding is KeepWhatsRaised {
    using SafeERC20 for IERC20;

    event TipForwarded(
        address indexed token,
        uint256 amount,
        address indexed recipient,
        uint256 indexed tokenId
    );

    event TipForwardingFailed(
        address indexed token,
        uint256 amount,
        address indexed intendedRecipient,
        uint256 indexed tokenId
    );

    /// @dev Override: forward tips atomically to platform admin instead of accumulating.
    ///      Falls back to base behavior (accumulate) if the transfer fails,
    ///      preventing a blocklisted platformAdmin from DoS-ing all pledges.
    function _handleTip(
        address pledgeToken,
        uint256 tokenId,
        uint256 tip
    ) internal override {
        if (tip == 0) return;

        address platformAdmin = INFO.getPlatformAdminAddress(PLATFORM_HASH);

        // Try to forward. If it fails (e.g., platformAdmin blocklisted),
        // fall back to storing in treasury for later claimTip().
        try IERC20(pledgeToken).transfer(platformAdmin, tip) returns (bool success) {
            if (success) {
                emit TipForwarded(pledgeToken, tip, platformAdmin, tokenId);
                return;
            }
        } catch {}

        // Fallback: store in treasury (base behavior)
        emit TipForwardingFailed(pledgeToken, tip, platformAdmin, tokenId);
        super._handleTip(pledgeToken, tokenId, tip);
    }

    /// @dev Tips are forwarded at pledge time. claimTip() only needed
    ///      if any tips fell back to storage due to failed forwarding.
    ///      Inherits base claimTip() which handles stored tips correctly.
}
```

**Design decisions in this contract:**

1. **Try/catch on safeTransfer** — If `platformAdmin` is blocklisted by the token (e.g., USDC), the pledge still succeeds. Tips fall back to the accumulate-and-claim pattern. This prevents DoS.

2. **No override of `claimTip()`** — Because of the fallback, some tips may still accumulate in storage. The base `claimTip()` handles these correctly. If all tips forwarded successfully, `claimTip()` is a no-op (loops over zero values).

3. **NFT metadata preserved** — `mintNFTForPledge(..., tip)` is called before `_handleTip`, so the NFT always records the correct tip amount regardless of forwarding.

4. **`Receipt` event preserved** — Emitted before `_handleTip`, tip field is always accurate.

### 3.3 No changes needed

| Component | Why no changes |
|---|---|
| `TreasuryFactory.sol` | `implementationMap` already supports multiple implementations via `implementationId` |
| `CampaignInfoFactory.sol` | Independent of treasury type |
| `BaseTreasury.sol` | No tip logic |
| `PledgeNFT.sol` | Tip recorded in NFT metadata before hook fires |
| `ICampaignTreasury.sol` | Shared interface, tips are KWR-specific |
| `GlobalParams.sol` | No tip logic |
| Permit2 witness types | Signatures bind `tip` amount, not destination. Post-transfer routing is irrelevant |

### 3.4 New files

| File | Purpose |
|---|---|
| `src/treasuries/KeepWhatsRaisedWithTipForwarding.sol` | Child contract with tip forwarding override |
| `script/DeployKeepWhatsRaisedWithTipForwardingImplementation.s.sol` | Deployment script |
| `test/foundry/unit/KeepWhatsRaisedWithTipForwarding.t.sol` | Unit tests |

---

## 4. Permit2 Compatibility

**Zero impact on signatures.** The Permit2 witness binds:
- `TokenPermissions{token, totalAmount}` — backer signs over `pledgeAmount + tip`
- `spender` — the treasury clone address
- Witness struct — `{pledgeId, backer, rewardsHash/pledgeAmount, tip}`

The hook changes what happens AFTER tokens land in the treasury. The signature validation is identical. No witness type changes needed.

Immediate forwarding is actually **marginally safer** than deferred `claimTip()` — it limits the window for admin address manipulation between tip accumulation and claim.

---

## 5. Security Findings & Mitigations

From security analysis and audit-level review. All findings addressed in the design.

### HIGH severity

| # | Finding | Mitigation |
|---|---|---|
| H-1 | **CEI violation**: external call before state finalization | `_handleTip()` placed AFTER all state writes and `Receipt` emit — last statement in `_pledge()` |
| H-2 | **DoS via blocklisting**: reverting platformAdmin blocks all tipped pledges | Try/catch with fallback to base behavior (accumulate in storage) |
| H-3 | **Phantom `claimTip()` state**: callable but no-op in forwarding variant | Not overridden — base `claimTip()` correctly handles any fallback-stored tips. Pure no-op if all tips forwarded. |

### MEDIUM severity

| # | Finding | Mitigation |
|---|---|---|
| M-1 | Private storage blocks clean override | Change `s_tokenToTippedAmount`, `s_tipPerToken` to `internal` |
| M-2 | `_pledge()` is private, limiting extensibility | Acceptable — hook pattern is narrow by design. `_pledge()` stays private. |
| M-3 | Fee-on-transfer token mismatch | Accepted as known limitation. Celo token list is curated. Document in NatDoc. |

### LOW severity

| # | Finding | Mitigation |
|---|---|---|
| L-1 | Event ordering (`TipForwarded` before `Receipt`) | Fixed — hook fires AFTER `Receipt` emit |
| L-2 | No standalone access control docs on `_handleTip` | Add NatDoc warning |
| L-3 | Forwarded tips are non-refundable | By design — tips were never refundable in the base implementation either |

### Pre-existing issues discovered

| Finding | Recommendation |
|---|---|
| `claimRefund()` and `disburseFees()` lack `nonReentrant` | Add `nonReentrant` modifier (separate PR) |
| `s_tokenToTippedAmount` is dead storage (write-only, never read on-chain) | Keep for now — useful for off-chain queries via storage proofs |
| `tip > 0` with `pledgeAmount = 0` creates phantom NFTs | Add validation `if (pledgeAmount == 0 && tip == 0) revert` (separate PR) |

---

## 6. Accounting Verification

### Invariant (per token)

```
Current:    balance >= available + protocolFee + platformFee + tipPerToken
Forwarding: balance >= available + protocolFee + platformFee
            (tipPerToken == 0 when all tips forwarded successfully)
```

The invariant holds because tip drops from both sides simultaneously: tokens leave the treasury and `s_tipPerToken` is never incremented.

### Fund flow verification

| Flow | Touches tips? | Safe with forwarding? |
|---|---|---|
| `_pledge()` | Yes — transfers `pledgeAmount + tip` in | Yes — tip forwarded out atomically |
| `withdraw()` | No — uses `s_availablePerToken` | Yes |
| `claimRefund()` | No — uses `s_tokenToPledgedAmount` | Yes — tips were never refundable |
| `disburseFees()` | No — uses fee accumulators | Yes |
| `claimTip()` | Yes — uses `s_tipPerToken` | Yes — correctly handles 0 values (no-op) |
| `claimFund()` | No — uses `s_availablePerToken` | Yes — cannot sweep tips |

---

## 7. Gas Analysis

| Metric | Current (accumulate + claimTip) | Forwarding (hook) |
|---|---|---|
| Per pledge (tip portion) | ~27,200 gas (2 SSTOREs) | ~29,000 gas (safeTransfer, warm) |
| Per pledge delta | — | ~+1,800 gas |
| claimTip() transaction | 21,000 base + ~36,000/token | Eliminated (0 gas) |
| Break-even (T=1 token) | — | ~29 pledges |
| Virtual dispatch overhead | — | 0 (compile-time resolution) |

**The main value is operational simplification, not gas savings.** Eliminating `claimTip()` as a separate admin transaction is the real win.

---

## 8. Factory & Deployment

**Zero factory changes.** The workflow:

1. Deploy `KeepWhatsRaisedWithTipForwarding` as a new implementation contract
2. `registerTreasuryImplementation(platformHash, NEW_ID, address(impl))`
3. `approveTreasuryImplementation(platformHash, NEW_ID)`
4. Campaigns choose `implementationId` at deploy time

Existing campaigns are unaffected (ERC-1167 clones are non-upgradeable).

---

## 9. Integration Impact

| System | Change needed |
|---|---|
| Subgraph/indexer | Handle `TipForwarded` + `TipForwardingFailed` events. Use `implementationId` from deploy event for treasury type detection. |
| Frontend | Detect treasury variant via `implementationId`. Hide "Claim Tip" button for forwarding treasuries. |
| `Receipt` event | Unchanged — `tip` field still accurate |
| NFT metadata | Unchanged — `PledgeData.tipAmount` still recorded |
| Backend/API | Map `implementationId` to treasury type enum |

---

## 10. Test Plan

### New test suite: `KeepWhatsRaisedWithTipForwarding`

**Core forwarding:**
- `testTipForwardedOnPledgeForAReward` — tip transferred to platformAdmin at pledge time
- `testTipForwardedOnPledgeWithoutAReward`
- `testTipForwardedOnSetFeeAndPledge`
- `testZeroTipNoTransfer` — no safeTransfer when tip=0
- `testTipForwardedViaPledgeForARewardPermit2` — Permit2 path
- `testTipForwardedViaPledgeWithoutARewardPermit2`

**Balance verification:**
- `testTreasuryBalanceExcludesTipAfterPledge`
- `testPlatformAdminReceivesTipImmediately`
- `testRaisedAmountExcludesTip`

**Fallback behavior (try/catch):**
- `testTipFallsBackToStorageOnBlocklistedAdmin` — safeTransfer fails, tip stored in treasury
- `testClaimTipWorksAfterFallback` — base claimTip() recovers fallback-stored tips
- `testTipForwardingFailedEventEmitted`

**Lifecycle:**
- `testRefundExcludesForwardedTip`
- `testWithdrawAfterTipsForwarded`
- `testDisburseFeesExcludesForwardedTips`
- `testClaimFundAfterTipsForwarded`
- `testCancelAfterTipsForwarded`
- `testClaimTipNoOpWhenAllTipsForwarded`

**Edge cases:**
- `testMultipleTokenTipsForwardedSeparately`
- `testTipForwardedToCurrentAdminAtPledgeTime` — admin change between pledges
- `testNFTMetadataRecordsTipEvenWhenForwarded`

**Invariant tests:**
- `invariant_treasuryBalanceMatchesAccounting`
- `invariant_tipPerTokenZeroWhenAllForwarded`
- `invariant_feePlusAvailableEqualsRaised`

**Differential tests:**
- Deploy both variants, run identical operations, assert `getRaisedAmount()`, `getAvailableRaisedAmount()`, refund amounts, and fee disbursements are identical. Only tip routing differs.

---

## 11. Implementation Steps

### Step 1: Modify `KeepWhatsRaised.sol`
- Change `s_tokenToTippedAmount` and `s_tipPerToken` from `private` to `internal`
- Extract tip handling from `_pledge()` into `_handleTip()` internal virtual
- Place `_handleTip()` call at the END of `_pledge()`, after all state writes and `Receipt` emit
- Make `claimTip()` virtual
- Add NatDoc to `_handleTip()`

### Step 2: Create `KeepWhatsRaisedWithTipForwarding.sol`
- Inherit `KeepWhatsRaised`
- Override `_handleTip()` with try/catch forwarding + fallback
- Add `TipForwarded` and `TipForwardingFailed` events

### Step 3: Add deployment script
- `DeployKeepWhatsRaisedWithTipForwardingImplementation.s.sol`

### Step 4: Write tests
- Unit tests for the forwarding variant
- Differential tests against base variant
- Invariant/fuzz tests

### Step 5: Verify existing tests pass
- All existing `KeepWhatsRaised` tests must pass unchanged (the base `_handleTip` preserves current behavior exactly)

---

## 12. Open Questions for SC Team

1. **Is immediate forwarding a hard requirement?** If not, "Option 0" (just pass real tip value to existing `setFeeAndPledge`, let `claimTip()` handle the rest) requires zero contract changes and is already fully supported.

2. **Should `claimTip()` revert in the forwarding variant?** Current design: it's a no-op (handles fallback-stored tips if any). Alternative: override to revert with `TipsAlreadyForwarded()`.

3. **Fee-on-transfer tokens**: Are any accepted tokens fee-on-transfer? If so, the forwarding variant needs a balance-delta check.

4. **`nonReentrant` on `claimRefund()` and `disburseFees()`**: These functions lack it. Should we add it in this PR or a separate one?

5. **Tip-only pledges (`pledgeAmount=0, tip>0`)**: Should these be explicitly forbidden? They create phantom NFTs in both variants.
