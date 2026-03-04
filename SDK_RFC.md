# 1. Executive Summary

Oak Network exposes a growing set of on-chain protocol contracts that developers must interact with directly to build decentralized applications, integrations, automation, and analytics.

Today, interacting with these contracts requires:

* Manual ABI handling
* Ad-hoc contract instantiation
* Inconsistent error handling
* Repeated boilerplate for validation, simulation, and event parsing

This RFC proposes **`@oak-network/contracts`**, a protocol-first smart contract client library whose sole responsibility is to provide safe, typed, and developer-friendly access to Oak protocol contracts.

The library focuses on:

* Type-safe contract access
* Preflight validation and developer warnings
* Graceful error translation before sending transactions on-chain
* Typed event querying and decoding
* Optional metrics and aggregation tooling
* Optional auth/wallet adapters (e.g. Privy), without binding developers to them

The result is a pure protocol SDK that works in frontends, backends, scripts, and indexers — without any dependency on Oak backend services.

---

# 2. Goals & Non-Goals

### Goals

* Make Oak protocol contracts easy, safe, and predictable to call
* Eliminate common on-chain revert causes before execution
* Provide typed read, write, and event interfaces
* Surface actionable developer warnings instead of opaque reverts
* Support multiple chains and environments explicitly
* Enable analytics and metrics without forcing a hosted indexer
* Allow optional tooling (Privy, metrics providers) without coupling

### Non-Goals

* No backend HTTP or API integration
* No mandatory wallet or auth provider
* No UI components or wallet UX
* No off-chain business logic orchestration
* No forced indexing infrastructure

---

# 3. Package Scope & Structure

**Package Name**
`@oak-network/contracts`

**Subpath Exports (Logical Modules)**

* `@oak-network/contracts` – core protocol client
* `@oak-network/contracts/preflight` – validation & warnings
* `@oak-network/contracts/events` – event querying & decoding
* `@oak-network/contracts/metrics` – aggregation helpers
* `@oak-network/contracts/privy` – optional Privy adapter

> **Hard rule:** Core must never import optional modules or heavy dependencies.

---

# 4. Core Design Principles

### 4.1 Protocol-First Design

The library mirrors the on-chain protocol surface, not application workflows.

* Methods map 1:1 to Solidity functions
* No opinionated flows
* Developers compose logic externally

### 4.2 Strong Typing Is Mandatory

All public APIs must be:

* Fully typed
* ABI-aligned
* Event-safe
* Compile-time verified

No `any` types are allowed at the public boundary.

### 4.3 Zero Backend Dependency

The library must work in a fully decentralized environment.

* No API keys
* No Oak service URLs
* No backend assumptions

---

# 5. Contract Typing Strategy

### 5.1 TypeChain as Source of Truth

All contract bindings are generated from Solidity artifacts using TypeChain.

* No handwritten wrappers
* ABI drift caught at compile time
* Events and return values strictly typed

### 5.2 Runtime Support

Bindings must support:

* Viem
* Ethers v6

Adapters may exist, but the ABI typing pipeline is canonical.

---

# 6. Contract Registry & Address Resolution

### 6.1 Central Contract Registry

The library maintains a registry mapping:

* Contract name
* ABI/type reference
* Supported chains
* Environment-specific deployment addresses

Example mapping:
`Vault → { sandbox → base → 0x..., production → base → 0x... }`

### 6.2 Explicit Environment & Chain

Instantiation requires:

* **environment:** `sandbox` | `production`
* **chain:** e.g. `ethereum` | `polygon` | `base`

No defaults. No guessing.

### 6.3 Fail-Fast Safety

If a contract is:

* Not deployed
* Unsupported on the chain
* Mismatched with environment

Instantiation fails immediately with a descriptive error.

---

# 7. Client Construction Model

### 7.1 Explicit Wiring

The library does not manage wallets or RPC selection. Consumers must provide:

* `publicClient` (read)
* Optional `signer` (write)

```typescript
const oak = createOakContractsClient({
  environment: 'sandbox',
  chain: 'base',
  publicClient,
  signer,
});

```

### 7.2 Read vs Write Separation

* Read methods require only a public client
* Write methods require a signer
* Missing signer → fail fast before any RPC call

---

# 8. Preflight Validation & Developer Warnings

### 8.1 Motivation

Many smart contract reverts are caused by predictable input mistakes:

* Array length mismatch
* Incorrect ordering
* Invalid casing
* Duplicate values
* Sums not matching invariants (e.g. BPS)
* Malformed addresses

These should be detected before simulation or transaction submission.

### 8.2 Preflight Layer (Concept)

The Preflight Layer performs:

* Local validation
* Semantic checks
* Optional normalization
* Developer-facing warnings

It runs before simulation and before sending transactions.

### 8.3 Preflight Modes

```typescript
preflight: {
  mode: 'warn' | 'strict' | 'normalize',
  collect: true
}

```

| Mode | Behavior |
| --- | --- |
| **strict** | Any issue blocks execution |
| **warn** | Warnings surfaced, execution allowed |
| **normalize** | Safe canonical fixes applied + warnings |

**Default:** `warn`

### 8.4 Preflight Output

```typescript
type PreflightIssue = {
  code: string;
  severity: 'error' | 'warn';
  message: string;
  fieldPath?: string;
  suggestion?: string;
  normalized?: boolean;
};

type PreflightResult<T> =
  | { ok: true; normalized: T; warnings: PreflightIssue[] }
  | { ok: false; issues: PreflightIssue[] };

```

Each write method exposes:

* `method.preflight(input)`
* `method.safe(input)`

### 8.5 What Preflight Validates

**A. Structural Validation (Zero RPC)**

* Address format & checksum
* Numeric bounds
* Empty arrays
* Enum correctness

**B. Semantic Validation**

* Array length equality
* Ordering constraints
* Duplicate detection
* Sum invariants (e.g. BPS = 10000)
* Required role presence

**C. Canonical Normalization (Optional)**

* Address checksum normalization
* Stable sorting (when protocol expects it)
* Duplicate removal (warn + normalize)

Normalization is contract-method specific and opt-in.

### 8.6 Developer Warnings (DX)

Warnings are explicit and actionable (e.g., `ARRAY_ORDER_MISMATCH`, `BPS_SUM_INVALID`, `DUPLICATE_RECIPIENT`, `STRING_CASE_MISMATCH`).

Warnings explain:

* Why it matters
* What may revert
* How to fix

---

# 9. Error Translation & Simulation

### 9.1 Separation of Concerns

* **Preflight:** Local, deterministic
* **Simulation:** RPC dry-run (`callStatic` / `simulateContract`)
* **Execution:** Actual transaction

### 9.2 Error Taxonomy

Errors are translated into typed Oak errors:

* `InputValidationError`
* `EnvironmentMismatchError`
* `ContractNotDeployedError`
* `MissingSignerError`
* `SimulationRevertedError`
* `TransactionRevertedError`
* `RpcError`

No raw RPC errors leak to the developer.

---

# 10. Optional Privy Auth Adapter

### 10.1 Purpose

Some integrators want:

* Embedded wallets
* Session-based signing
* Social login
Others do not.

### 10.2 Design

Privy support is provided as an optional adapter: `@oak-network/contracts/privy`

```typescript
const { signer, publicClient } = await createPrivySignerAdapter({ 
  privyClient, 
  chain 
});

const oak = createOakContractsClient({ 
  signer, 
  publicClient, 
  ... 
});

```

### 10.3 Boundary Rules

* Core never imports Privy
* Privy module depends on Privy SDK
* No opinionated auth flows

---

# 11. Events Tooling

### 11.1 Typed Event Queries

Under `@oak-network/contracts/events`:

* Typed filters
* Decoded logs
* Pagination helpers
* Block-range utilities

```typescript
oak.events.Vault.Deposit.query({ fromBlock, toBlock, filter });

```

### 11.2 Normalized Event Format

Events expose:

* Name
* Args (typed)
* Tx hash
* Block number
* Optional timestamp (opt-in)

Indexer-friendly by design.

---

# 12. Metrics & Aggregations Tooling

### 12.1 Objectives

Provide common protocol metrics without forcing a hosted indexer.

### 12.2 Two-Tier Model

**Tier A: RPC-Based (Bounded)**

* Contract reads
* Limited event scans
* Safe for dashboards & scripts
* *Examples:* TVL (if exposed), deposits in last N blocks, unique contributors (bounded).

**Tier B: Indexer-Backed (Pluggable)**
Expose an interface:

```typescript
interface OakMetricsProvider {
  getVaultTVL(vaultId): Promise<bigint>;
  getVolume(range): Promise<bigint>;
}

```

Indexers can implement this without modifying core.

---

# 13. Testing Strategy

* Preflight rule unit tests
* Error translation tests
* Event decoding snapshots
* Metrics provider contract tests
* Forked-chain validation where needed
* **100% coverage required for library logic.**

---

# 14. Versioning

**Semantic Versioning:**

* **MAJOR:** ABI or API breaking changes
* **MINOR:** New contracts, methods, tooling
* **PATCH:** Fixes, validation improvements

---

# 15. Definition of Done

A feature is complete only if:

* Preflight validation exists (if write method)
* Errors are translated
* Events are typed
* Optional tooling remains isolated
* Documentation examples updated

---

# 16. Implementation Roadmap (Proposed)

**Phase 1**

* Core registry & client
* TypeChain bindings
* Preflight framework
* Error taxonomy

**Phase 2**

* Event querying utilities
* Simulation wrappers
* Metrics (RPC-based)

**Phase 3**

* Privy adapter
* Indexer interfaces
* DX polish & docs