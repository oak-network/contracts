# Oak SDK Preflight Framework: V1 Specification

## 1. Purpose

A preflight layer that runs before transaction submission to catch predictable reverts, surface actionable warnings for suspicious inputs, and optionally simulate the call on-chain.

## 2. Design Principles

- Block only on high-confidence failures traceable to Solidity preconditions or readable on-chain state.
- Prefer readable on-chain state when needed; fall back gracefully when unavailable.
- Apply only semantics-preserving normalization.
- Use stable issue codes for machine handling and long-term compatibility.

## 3. Public API

### 3.1 Per-method APIs

```typescript
method.preflight(input, options?)  // => Promise<PreflightResult<T>>
method.safe(input, options?)       // => Promise<TxResult>
```

`safe()` flow is fixed in v1: preflight -> simulation -> send (only if simulation passes).
`safe()` requires a signer for write execution; if signer is missing, fail fast with `MissingSignerError` before preflight, simulation, and send.

### 3.2 Options

```typescript
export type PreflightMode = 'strict' | 'warn' | 'normalize';
export type StatefulPolicy = 'enabled' | 'local-only';

export interface PreflightOptions {
  mode?: PreflightMode;            // default: 'warn'
  stateful?: StatefulPolicy;       // default: 'enabled'
  collect?: boolean;               // default: true
  blockTag?: bigint | 'latest';    // default: 'latest'
  effectiveSender?: Address;       // optional ERC-2771 sender override
}
```

### 3.3 Result Types

```typescript
export interface PreflightIssue {
  code: string;                    // OAK-PF-<SCOPE>-<RULE>
  severity: 'error' | 'warn';
  message: string;
  fieldPath?: string;
  suggestion?: string;
  normalized?: boolean;
}

export type PreflightResult<T> =
  | { ok: true; normalized: T; warnings: PreflightIssue[] }
  | { ok: false; issues: PreflightIssue[]; normalized?: T };
```

Internal orchestration metadata (stage, determinism, blocking flags) is not exposed in the public response.

## 4. Blocking Rules

- **strict:** any unresolved issue blocks.
- **warn:** only unresolved `error` blocks.
- **normalize:** apply normalizers first; then same blocking behavior as `warn`.
- `normalized: true` issues never block.

## 5. Pipeline

### 5.1 Execution order

1. Structural validation.
2. Semantic validation.
3. Stateful validation (unless `stateful='local-only'`).
4. Normalization (`mode='normalize'` only).
5. Revalidation of mutated fields.
6. Return preflight result.
7. `safe()` only: simulation then send.

### 5.2 Stateful degradation behavior

If state reads fail in `enabled` mode:
- Emit one warning `OAK-PF-COMMON-STATE_UNAVAILABLE`.
- Skip remaining stateful checks.
- Keep local results.
- Use local-clock timestamp heuristics for time-related warnings (same behavior as `local-only` mode).

If `stateful='local-only'`:
- Skip stateful checks silently.

### 5.3 collect

- `collect=true`: aggregate all issues.
- `collect=false`: short-circuit on first blocking issue for active mode.

## 6. Guardrails for Rule Authors

- A blocking rule must map to either: (a) a direct Solidity revert precondition on input, or (b) a readable on-chain state condition at the selected `blockTag`.
- No rule may use fields absent from method ABI.
- No private-state synthetic checks; defer to simulation.
- Local-clock-only timing checks are warning-only.

## 7. Normalization Policy

Allowed:

- EIP-55 address checksumming.
- Empty-array canonicalization for `CampaignInfo.updateSelectedPlatform(selection=false)` because arrays are ignored on deselect.

Disallowed:

- Deduplication.
- String-to-bytes32 hashing.
- Sorting/reordering.
- Numeric coercion.

## 8. State Reader

Requirements:

- One snapshot per run (`blockTag`) across all calls.
- Multicall batching where possible.
- Per-run memoization.
- Sender resolution for `preflight()` auth checks: `sender = options.effectiveSender ?? signer`. Auth checks compare on-chain role to sender. If sender is missing, emit `OAK-PF-COMMON-SENDER_UNAVAILABLE` warning and skip auth checks.

## 9. Issue Code Scheme

Format: `OAK-PF-<SCOPE>-<RULE>`

Scopes: `COMMON`, `CAMPAIGN`, `FACTORY`, `PAYMENT`, `AON`, `KWR`.

Code IDs are immutable once released.

## 10. V1 Method Coverage and Priority

### 10.1 Priority A: Setup Guardrails

These methods ship first.

**GlobalParams.addToRegistry**

- Blocking: `key != bytes32(0)`; sender authorized (`onlyOwner`).

**GlobalParams.enlistPlatform**

- Blocking: `platformHash != bytes32(0)`; `platformAdminAddress != address(0)`; sender authorized; platform not already listed.

**GlobalParams.addPlatformData**

- Blocking: `platformDataKey != bytes32(0)`; platform listed; sender is platform admin; key not already set.

**GlobalParams.addTokenToCurrency**

- Blocking: `currency != bytes32(0)`; `token != address(0)`; sender authorized.
- Warning: token already present for currency (non-blocking hygiene warning).

**GlobalParams.setPlatformLineItemType**

- Blocking: `typeId != bytes32(0)`; platform listed; sender is platform admin; boolean matrix constraints exactly as Solidity: if `countsTowardGoal`, require `!applyProtocolFee && canRefund && !instantTransfer`; if `!countsTowardGoal && instantTransfer`, require `!canRefund`.

**TreasuryFactory.registerTreasuryImplementation**

- Blocking: `implementation != address(0)`; sender is platform admin.
- Warning: overwrite existing `(platformHash, implementationId)` mapping.

**TreasuryFactory.approveTreasuryImplementation**

- Blocking: sender is protocol admin.
- Simulation-backed: implementation existence at `(platformHash, implementationId)` -- private mapping, no public getter.

**CampaignInfoFactory.createCampaign**

- Blocking: `creator != address(0)`; `platformDataKey.length == platformDataValue.length`; each `platformDataValue[i] != bytes32(0)`; `launchTime >= block.timestamp + campaignLaunchBuffer`; `deadline >= launchTime + minimumCampaignDuration`; each selected platform is listed; each platform data key is valid; identifier not already used; currency has at least one token.
- Warning: duplicate selected platform hash; duplicate platform data key; `identifierHash == bytes32(0)`; `goalAmount == 0`; empty `nftName` or `nftSymbol`; local-clock launch time likely past (when chain timestamp is unavailable).

**TreasuryFactory.deploy**

- Blocking: sender is platform admin; campaign has selected platform (`checkIfPlatformSelected`); `infoAddress != address(0)` for current supported treasury implementations.
- Simulation-backed: implementation approval and initialization paths that depend on private/internal state.

### 10.2 Priority B: Core Transaction Paths

**BasePaymentTreasury.createPayment**

- Blocking: non-zero `paymentId`, `buyerId`, `itemId`; non-zero `paymentToken`; `amount > 0`; each line item has non-zero `typeId` and `amount > 0`; token accepted; payment ID not already used; `expiration > block.timestamp`; if max expiration configured: `expiration <= block.timestamp + max`; each line item type exists; campaign not paused/cancelled; sender is platform admin.
- Warning: expiration likely past (when chain timestamp is unavailable).

**BasePaymentTreasury.createPaymentBatch**

- Blocking: all eight arrays same length; batch non-empty; no duplicate `paymentIds`; per-index checks equivalent to `createPayment`.
- Warning: batch size risk threshold (gas).

**BasePaymentTreasury.processCryptoPayment**

- Blocking: non-zero ids, addresses, amount, line-item fields; token accepted; payment does not already exist; line-item types exist; campaign not paused/cancelled.
- Warning: ERC20 allowance insufficient; ERC20 balance insufficient.

**AllOrNothing.addRewards**

- Blocking: reward name non-zero; reward value > 0; reward arrays length parity; inner item arrays parity; no duplicate names in input; reward does not already exist on-chain; authorized sender; campaign/treasury not paused/cancelled.

**AllOrNothing.pledgeForAReward**

- Blocking: non-zero `backer`, `pledgeToken`; reward array non-empty; each reward entry non-zero; token accepted; campaign window active; reward exists; first reward is tier; campaign/treasury not paused/cancelled.

**AllOrNothing.pledgeWithoutAReward**

- Blocking: non-zero `backer`, `pledgeToken`; token accepted; campaign window active; campaign/treasury not paused/cancelled.
- Warning: pledge amount is zero (allowed but usually unintended).

**KeepWhatsRaised.configureTreasury**

- Blocking: `deadline > launchTime`; gross fee key/value array parity; sender is platform admin; campaign/treasury not paused/cancelled; `launchTime >= block.timestamp`.
- Warning: goal amount zero (advisory).

**KeepWhatsRaised.addRewards, pledgeForAReward, pledgeWithoutAReward**

- Apply analogous checks to AllOrNothing, plus: blocking check for processed pledge ID where readable via public mapping/getter.

### 10.3 Deferred in V1 (Simulation-led)

- Checks depending on private mappings/structs without public getters.
- Complex accounting-heavy confirm/withdraw/disburse eligibility paths.
- Config-lock and refund-window logic in KWR where private fields are required.

## 11. Assumptions

- SDK has reliable contract registry (address + ABI by chain/environment).
- `safe()` is the recommended write path for production.
- `safe()` requires signer availability and fails fast before execution if signer is missing.
- State read failures do not block in default mode; simulation remains the final guard.
- Any future API expansion keeps backward compatibility for `PreflightIssue` and code IDs.
