# Security Audits

This folder contains the independent security audit reports for the Oak Network smart contracts. Earlier reports were issued under the protocol's former name, **Creative Crowdfunding Protocol (CC Protocol)**.

| Date | Auditor | Scope | Report |
| --- | --- | --- | --- |
| Jun 17, 2026 | OpenZeppelin | Full protocol at commit [`479241c`](https://github.com/oak-network/contracts/commit/479241c) | [PDF](./OpenZeppelin%20-%20%2301%20-%20Smart%20Contracts%20Audit-report.pdf) |
| Dec 10, 2025 | Immunefi (Neplox) | `PaymentTreasury` | [PDF](./ImmuneFi-Audit-Report-OakNetwork-PaymentTreasury.pdf) |
| Aug 5, 2025 | Immunefi (Neplox) | Creative Crowdfunding Protocol v1.0 | [PDF](./Immunefi-Audit-Report-CreativeCrowdfunding_v1.0.pdf) |
| May 20, 2025 | PeckShield | Creative Crowdfunding Protocol v1.0 | [PDF](./PeckShield-Audit-Report-CreativeCrowdfunding_v1.0.pdf) |

---

## OpenZeppelin — Oak Network Smart Contracts Audit (June 17, 2026)

### At a Glance

| | |
| --- | --- |
| **Auditor** | OpenZeppelin Security |
| **Audit window** | January 5, 2026 – February 4, 2026 |
| **Published** | June 17, 2026 |
| **Audited commit** | [`479241c`](https://github.com/oak-network/contracts/commit/479241c) |
| **Scope** | All core contracts under `src/`: `CampaignInfo`, `CampaignInfoFactory`, `GlobalParams`, `TreasuryFactory`, constants, interfaces, storage libraries, the four treasuries (`AllOrNothing`, `KeepWhatsRaised`, `PaymentTreasury`, `TimeConstrainedPaymentTreasury`), and shared utils (`AdminAccessChecker`, `BasePaymentTreasury`, `BaseTreasury`, `CampaignAccessChecker`, `Counters`, `FiatEnabled`, `ItemRegistry`, `PausableCancellable`, `PledgeNFT`, `TimestampChecker`) |

### Results

64 issues were reported; 49 were resolved and 6 partially resolved during the fix-review phase. **All Critical and Medium severity issues are resolved.**

| Severity | Reported | Resolved | Partially resolved | Acknowledged |
| --- | --- | --- | --- | --- |
| Critical | 1 | 1 | – | – |
| High | 0 | – | – | – |
| Medium | 8 | 8 | – | – |
| Low | 35 | 24 | 4 | 7 |
| Notes & Additional Information | 20 | 16 | 2 | 2 |

### Key Security Changes from the Fix Review

- **Permit2 signature-bound transfers (C-01, fixed in [`cfa314e`](https://github.com/oak-network/contracts/commit/cfa314e))** — `processCryptoPayment` and the pledge paths could previously be front-run to spend any outstanding ERC-20 approval granted to a treasury, with attacker-controlled amounts and line items. All user-facing token transfer functions now use Permit2 `permitWitnessTransferFrom`: the token owner signs an EIP-712 witness committing to all critical parameters (amounts, line items, reward selections), so a third party can neither spend approved funds nor alter transaction parameters. `KeepWhatsRaised` pledge IDs are now globally unique, and the admin-only `setFeeAndPledge` path keeps direct ERC-20 transfers from the caller's own balance.
- **Refund liveness after cancellation (M-01 [`e5745cd`](https://github.com/oak-network/contracts/commit/e5745cd), M-04 [`2ce3f1e`](https://github.com/oak-network/contracts/commit/2ce3f1e), M-08 [`270f7e7`](https://github.com/oak-network/contracts/commit/270f7e7))** — cancelling a treasury no longer blocks user refunds while leaving admin claim routes open, refund scheduling now uses the earliest effective cancellation time of the campaign and the treasury (see also follow-up `8280e7e` on `main`), and fee disbursement is no longer permanently disabled by cancellation in `KeepWhatsRaised`.
- **Fee-handling hardening (M-02 [`b6dd085`](https://github.com/oak-network/contracts/commit/b6dd085))** — flat and percentage fees are no longer mixed in one unvalidated mapping; key uniqueness and percentage bounds are enforced.
- **Reentrancy protection (M-03 [`0cc355c`](https://github.com/oak-network/contracts/commit/0cc355c))** — `disburseFees` is now guarded against reentrant token callbacks.
- **Lifecycle enforcement (M-05, M-06, L-01, L-05, L-06, L-17)** — `KeepWhatsRaised` overrides of `disburseFees`/`withdraw` re-apply the campaign pause/cancel modifiers, withdrawal and refund windows can no longer overlap, `configureTreasury` is one-shot, `setFeeAndPledge` is time-gated, and treasuries can no longer be attached to expired or cancelled campaigns.
- **Access control and platform isolation (M-07 [`de16755`](https://github.com/oak-network/contracts/commit/de16755), L-02, L-19, L-31 [`a0b63c7`](https://github.com/oak-network/contracts/commit/a0b63c7), L-32)** — platform admins can only remove their own platform's data keys, `CampaignInfo.burn` is restricted to treasuries, delisting a platform clears its adapter, the trusted forwarder of deployed treasuries can be rotated, and contract wiring is validated via ERC-165 introspection.
- **Deployment safety (L-28 [`0974aa8`](https://github.com/oak-network/contracts/commit/0974aa8), L-13 [`960c5c3`](https://github.com/oak-network/contracts/commit/960c5c3))** — treasury implementation contracts lock their initializers in the constructor, and ERC-7201 storage namespaces were re-hashed from the legacy "ccprotocol" name to the current protocol name.
- **Error-code cleanup (N-19 [`acd726c`](https://github.com/oak-network/contracts/commit/acd726c), revised in `1617830` and `8c07af9`)** — string reverts were replaced with enum-coded custom errors to reduce bytecode size and make failures unambiguous.

### Findings

Commit hashes below are the remediation commits referenced in the report's per-finding *Update* notes; all of them are part of this repository's history.

#### Critical Severity

| ID | Finding | Status |
| --- | --- | --- |
| C-01 | Approvals Can Be Abused to Spend Others' Funds | Resolved (`cfa314e`) |

#### Medium Severity

| ID | Finding | Status |
| --- | --- | --- |
| M-01 | Cancellation in `PaymentTreasury` Allows Post-Cancel Admin Sweeping While Disabling Refunds | Resolved (`e5745cd`) |
| M-02 | Fee Types Mixing in Storage With Lack of Validation | Resolved (`b6dd085`) |
| M-03 | `disburseFees` Is Vulnerable to Reentrancy | Resolved (`0cc355c`) |
| M-04 | Campaign Cancellation Does Not Start Refund Schedule | Resolved (`2ce3f1e`) |
| M-05 | `disburseFees` and `withdraw` Function Override Removes Constraints | Resolved (`c68b28c`) |
| M-06 | Incorrect Modifier | Resolved (`c0b778b`, documentation updated) |
| M-07 | `removePlatformData` Does Not Check That `platformDataKey` Corresponds to `platformHash` | Resolved (`de16755`) |
| M-08 | Assets Might Get Permanently Blocked After `cancelTreasury` in `KeepWhatsRaised` | Resolved (`270f7e7`) |

#### Low Severity

| ID | Finding | Status |
| --- | --- | --- |
| L-01 | Treasury Can Get Attached to Expired Campaign | Resolved (`d0c7a18`, `770564e`) |
| L-02 | Burn Function Publicly Callable | Resolved (`7f6ed46`) |
| L-03 | Inconsistent Colombian Tax Accounting | Resolved (`04aa2ba`) |
| L-04 | `BaseTreasury.disburseFees` Can Be Called Multiple Times | Resolved (`398679f`) |
| L-05 | Withdraw Can Happen Before Refund Window Ends | Resolved (`4e7e6ca`) |
| L-06 | `setFeeAndPledge` Has No Time Restrictions | Resolved (`bd5dd74`) |
| L-07 | Deselecting Platforms Skips `platformData` Setting | Acknowledged — platform data keys are shared across platforms by design |
| L-08 | Unescaped `s_imageURI` Can Produce Invalid `tokenURI` JSON Metadata | Resolved (`ceb7c78`) |
| L-09 | Rewards Can Be Duplicated | Resolved (`8a4f8d3`); the report notes the duplicate-length check removal was reintroduced in `cfa314e` |
| L-10 | Rewards Can Be Removed | Resolved (`8f2034f`) |
| L-11 | Rewards for Pledge May Conflict | Partially resolved (`fff7fdd`) — `canBeAddOn` flag added; semantic overlap between tiers remains possible |
| L-12 | `setFeeAndPledge` Combines Different Flows | Acknowledged — gateway fee varies per integration and must be an input |
| L-13 | Old Project Name Used for Storage Slots | Resolved (`960c5c3`) |
| L-14 | Lack of Checks When Setting `campaignData` | Acknowledged — all deployments are assumed to go through the factory, which validates |
| L-15 | Unreachable Branch | Resolved (`171f4f6`) |
| L-16 | Missing Check in `_updateFiatTransaction` | Acknowledged, fix planned — `FiatEnabled` is currently unused |
| L-17 | `configureTreasury` Can Be Called Multiple Times | Resolved (`4dc46a9`) |
| L-18 | Deprecated Platform Data Due to `removePlatformData` Cannot Be Performed After Platform Is Delisted | Acknowledged — keys are intentionally shareable across platforms |
| L-19 | `delistPlatform` Does Not Clear `platformAdapter` Mapping Entry | Resolved (`d73e80d`) |
| L-20 | Storage Update Without Emitting Event | Resolved (`c966bfa`) |
| L-21 | Possible to Add Same Token to `acceptedTokens` List Twice | Resolved (`1c1d53d`) |
| L-22 | Fee Values Are Uncapped | Partially resolved (`a12b883`) — `updateProtocolFeePercent` still does not validate the combined fee sum |
| L-23 | Not Checking `s_fundClaimed` | Resolved (`ec617a1`) |
| L-24 | `_msgSender` Overloading in Internal ID System Could Cause Accounting Errors | Resolved (`e8cc973`) |
| L-25 | Unbounded Arrays As Inputs | Partially resolved (`ba0b13b`) — caps added in `BasePaymentTreasury` only |
| L-26 | Shipping Fee Not Verified | Acknowledged — zero shipping fee is valid by design; enforcement is off-chain |
| L-27 | Platform Data Passed Might Not Equal Amount of Platforms Passed | Acknowledged — platform selection and data keys are independent dimensions by design |
| L-28 | Missing Initializer Lock in Treasury Implementations | Resolved (`0974aa8`) |
| L-29 | Lack of Documentation About the `backer` | Resolved (`75faa27`) |
| L-30 | Platform Data Keys Are Not Bound to the Updated Platform During Selection Updates | Partially resolved (`35df4e2`) — the same effect remains possible during `createCampaign` |
| L-31 | Platform Adapter Rotation Does Not Revoke the Trusted Forwarder in Deployed Treasuries | Resolved (`a0b63c7`) |
| L-32 | Missing Validation | Resolved (`6c06c87`) |
| L-33 | Inconsistent Use of `paymentId` | Resolved (`9fcc553`) |
| L-34 | Mismatch in Fee Storage | Resolved (`f15865c`) |
| L-35 | Treasury Self-Pledge Misuses NFT Check | Resolved (`e7d38fe`, `73163a6`) |

#### Notes & Additional Information

| ID | Finding | Status |
| --- | --- | --- |
| N-01 | Redundant Conditionals | Resolved (`11f6498`) |
| N-02 | Reverts With Multiple Conditions | Resolved (`4f3ebda`) |
| N-03 | Unnecessary Temporary Variables | Resolved (`751d6d4`) |
| N-04 | Unnecessary Assignment in `AllOrNothing._pledge` | Resolved (`9181723`) |
| N-05 | `external` Function With `internal` Naming Convention | Resolved (`ff0a799`) |
| N-06 | Multiple Event Emissions for Same Assignment | Resolved (`7cbe940`) |
| N-07 | `addItem` and `addItemsBatch` Functions Can Modify Existing Items | Resolved (`9d290ec`) |
| N-08 | Non-Reward Pledges Are Not De-Normalized | Partially resolved (`770564e`) — non-reward flow still expects already-denormalized values |
| N-09 | Unnecessary Override | Resolved (`13905c8`) |
| N-10 | Renaming Opportunities | Partially resolved (`c8d5244`) — `claimRefund` functions not renamed |
| N-11 | Unnecessary Assignment Wastes Gas | Resolved (`fbd5186`) |
| N-12 | Unclear Docstrings | Resolved (`e86feb5`) |
| N-13 | Not Using Require With Custom Errors | Acknowledged — staying on the explicit `if`/`revert` pattern for now |
| N-14 | Unchecked Scoping Not Needed for `for` Loop Iterators | Resolved (`f8cb375`) |
| N-15 | Structs Declared in Middle of Contracts | Resolved (`f3eb641`) |
| N-16 | Implicit Returns and Unnamed Return Values | Resolved (`b9c5b44`) |
| N-17 | Missing Documentation | Resolved (`f63b4ab`) |
| N-18 | Unused Code | Acknowledged — `whenCancelled` retained for API completeness |
| N-19 | Repeated Use of Errors | Resolved (`acd726c`; implementation revised in `1617830` and `8c07af9`) |
| N-20 | Typographical Error | Resolved (`54ada6b`) |

---

## Immunefi (Neplox) — Oak Network `PaymentTreasury` Audit (December 10, 2025)

Audit of the `PaymentTreasury` flow performed by Neplox security researchers via Immunefi. The report documents 13 findings (1 Critical, 3 High, 2 Medium, 4 Low, 3 Insights); see the [PDF](./ImmuneFi-Audit-Report-OakNetwork-PaymentTreasury.pdf) for details and resolutions.

## Immunefi (Neplox) — Creative Crowdfunding Protocol v1.0 Audit (August 5, 2025)

Audit of the protocol under its former name, performed by Neplox security researchers via Immunefi. See the [PDF](./Immunefi-Audit-Report-CreativeCrowdfunding_v1.0.pdf).

## PeckShield — Creative Crowdfunding Protocol Audit (May 20, 2025)

Audit report #2025-082 by PeckShield covering the protocol under its former name. See the [PDF](./PeckShield-Audit-Report-CreativeCrowdfunding_v1.0.pdf).
