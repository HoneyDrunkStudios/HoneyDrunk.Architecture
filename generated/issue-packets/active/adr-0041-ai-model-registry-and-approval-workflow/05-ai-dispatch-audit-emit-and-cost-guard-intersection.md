---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "adr-0041", "wave-4"]
dependencies: ["packet:04"]
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 4
initiative: adr-0041-ai-model-registry-and-approval-workflow
node: honeydrunk-ai
---

# Emit an Audit entry on every AI dispatch and wire the per-tenant cost-guard intersection

## Summary
Wire the Audit emit so every AI dispatch records `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)` durably, on both successful dispatch and ceiling rejection. Add the per-tenant cost-guard intersection (D6): a `ICostGuard`-shaped pre-router check that runs before the router's per-call ceiling, with both checks emitting Audit entries on rejection.

## Context
ADR-0041's third new invariant: "every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`. Routing decisions are forensically attributable." D5 adds that policy overrides are recorded in the Audit emit so cost outliers are attributable. D6 decides the per-call ceiling (router-enforced, packet 04) and the per-tenant period ceiling (`ICostGuard`-enforced, upstream of the router) are both required — both emit Audit entries on rejection. D10 adds that the canary-driven `ApprovalState` flips are also recorded in Audit.

Packet 04 rewired `DefaultModelRouter` to the registry, added the per-call ceiling, and left a clean seam for the Audit emit on rejection. This packet completes the forensic-attribution invariant by wiring the Audit emit on every dispatch (success and rejection) and the per-tenant cost-guard layer.

ADR-0018 introduced `ICostGuard` as the per-tenant cost ceiling. `HoneyDrunk.Operator` is the Node that exposes `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter` — but `HoneyDrunk.Operator` has **no `src/` at all** (it is cataloged but not scaffolded). This packet must NOT take a hard runtime dependency on the unbuilt Operator Node — the local `ITenantCostGuard` seam stays for the Operator `ICostGuard` intersection. By contrast, `HoneyDrunk.Audit` IS scaffolded (buildable `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`), so the dispatch Audit emit takes `HoneyDrunk.Audit.Abstractions` (`IAuditLog`) as a **hard dependency** — see Constraints.

This packet lands on `HoneyDrunk.AI` after packet 04 — it **appends to the in-progress `[0.2.0]` CHANGELOG entry** and does NOT bump the version again (invariant 27).

## Scope
- `src/HoneyDrunk.AI/Routing/` — wire the Audit emit on dispatch (success + rejection) into the seam packet 04 left.
- `src/HoneyDrunk.AI/Cost/` — the per-tenant cost-guard intersection layer.
- `src/HoneyDrunk.AI/Telemetry/InferenceTelemetry.cs` — confirm the Audit emit is distinct from telemetry (see Constraints — audit is NOT telemetry, invariant 47).
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — register the cost-guard layer and the audit-sink binding.
- `tests/HoneyDrunk.AI.Tests/` — audit-emit and cost-guard tests.
- CHANGELOG append (no version bump).

## Proposed Implementation

### Audit emit on dispatch
- Every call through `DefaultModelRouter` (and the cost-guard layer below) emits exactly one Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`:
  - `TenantId` — from `IGridContext` (Kernel — already a runtime dependency of `HoneyDrunk.AI`). Internal Grid callers default to `TenantId.Internal` per invariant 6 / invariant 39.
  - `ModelId` — the routed model (or, on a pre-router rejection, the requested/intended model if known, else null).
  - `PolicyOverride?` — non-null when a pinned/override policy was used (packet 04 records this in the routing decision).
  - `CostUsd` — the actual or estimated call cost.
  - `Outcome` — `Dispatched` | `RejectedPerCallCeiling` | `RejectedTenantCeiling` | `Failed` (provider error), etc.
- **The audit channel is durable and separate from observability telemetry (invariant 47).** The Audit entry goes through `IAuditLog` (the `HoneyDrunk.Audit` substrate), NOT through `InferenceTelemetry` / Pulse. `InferenceTelemetry` keeps its existing role (operational telemetry — "is the system healthy in aggregate"); the Audit entry answers "who dispatched what model, at what cost, was it allowed." Do not merge them.
- **`HoneyDrunk.Audit.Abstractions` is a HARD dependency.** `HoneyDrunk.Audit` is a scaffolded Node with buildable `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data` projects. Take a runtime dependency on `HoneyDrunk.Audit.Abstractions` (`IAuditLog`, `AuditEntry`) from `HoneyDrunk.AI` — `.Abstractions` only, never `HoneyDrunk.Audit.Data` (invariant 48) — and emit a real `AuditEntry`. Verify the package is on the feed at execution time; if it is not yet published, treat that as a **blocker to resolve** (publish it), not a reason to ship a permanent local audit seam. Packet 03 binds the canary-flip emit to `IAuditLog` the same way — this packet adds the dispatch emit against the same `IAuditLog`. There is no long-lived local audit-sink interface.
- The **`ApprovalState`-flip Audit emit** is wired by packet 03 directly against `IAuditLog`. If for any reason packet 03 shipped before `HoneyDrunk.Audit.Abstractions` was on the feed and left a temporary local sink, this packet rebinds it to `IAuditLog`. Otherwise this packet only adds the dispatch emit.

### Per-tenant cost-guard intersection (D6)
- Add a pre-router cost-guard layer in `HoneyDrunk.AI` that runs **before** `DefaultModelRouter` (D6: "the cost-guard layer checks the per-tenant ceiling before the router"). It checks the requesting tenant's accumulated period spend against a per-tenant ceiling; on breach it rejects with a clear exception and emits an Audit entry with `Outcome=RejectedTenantCeiling`.
- ADR-0018's `ICostGuard` is the canonical per-tenant cost ceiling and lives in `HoneyDrunk.Operator`. **`HoneyDrunk.Operator` has no `src/` at all — it is cataloged but not scaffolded. Do NOT take a runtime dependency on it.** Strategy: define the per-tenant guard against a local `ITenantCostGuard` interface in `HoneyDrunk.AI.Abstractions`. Ship a default implementation in `HoneyDrunk.AI` backed by the existing `ICostLedger` (`Cost/DefaultCostLedger.cs` is already in the repo — the ledger tracks per-tenant accumulated cost; the guard reads it and compares to a configured ceiling). The local-seam fallback is correct and intended **only for the Operator `ICostGuard` intersection** — when `HoneyDrunk.Operator` is scaffolded and publishes `HoneyDrunk.Operator.Abstractions`, a follow-up reconciles `ITenantCostGuard` with `ICostGuard`. (The Audit emit, by contrast, is NOT a seam — it is a hard `IAuditLog` dependency, see above.)
- The per-tenant ceiling value is operator-configurable, sourced from Azure App Configuration via Vault's `IConfigProvider` (invariant 45 — token cost rates and policies are App-Configuration-sourced, never compiled constants). Do not hardcode the ceiling.
- Tenant mechanics stay at the intake edge (invariant 39 — "tenant rate-limit checks ... must live in intake middleware/orchestration edges"). The per-tenant cost guard is exactly such an intake-edge check — it sits at the front of the AI dispatch path, before the tenant-agnostic core routing. Internal Grid callers (`TenantId.Internal`) pass through without a tenant-specific branch in the core router.

### Version
- Packet 02 bumped the solution to `0.2.0`; this packet **appends to the in-progress `[0.2.0]` entry** — no new version section (invariant 27).
- Update `HoneyDrunk.AI/README.md` if the public surface (the cost-guard registration, the audit-sink binding) changes the documented API.

## Affected Files
- `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs` — `IAuditLog` emit wired into packet 04's seam
- `src/HoneyDrunk.AI/Cost/` — per-tenant cost-guard layer + `ITenantCostGuard` default
- `src/HoneyDrunk.AI.Abstractions/ITenantCostGuard.cs` — new (the local per-tenant guard interface; `HoneyDrunk.Operator` is unscaffolded so this seam is the intended path)
- `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj` — `HoneyDrunk.Audit.Abstractions` `PackageReference` (hard dependency)
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`
- `src/HoneyDrunk.AI/CHANGELOG.md` (append to `[0.2.0]`), repo-level `CHANGELOG.md` (append)
- `src/HoneyDrunk.AI/README.md` (if the public surface description changes), `src/HoneyDrunk.AI.Abstractions/README.md` (if `ITenantCostGuard` is added)
- `tests/HoneyDrunk.AI.Tests/` — audit-emit and cost-guard tests

## NuGet Dependencies
- The Audit emit consumes `HoneyDrunk.Audit.Abstractions` (hard dependency): add `PackageReference` to `HoneyDrunk.Audit.Abstractions` in `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj` — `.Abstractions` only, never `HoneyDrunk.Audit.Data`. `HoneyDrunk.Audit` is a scaffolded Node; verify the package is on the feed at execution time. If it is not yet published, that is a blocker to resolve (publish it), not a reason to use a local seam.
- The per-tenant guard uses the local `ITenantCostGuard` interface in `HoneyDrunk.AI.Abstractions` — `HoneyDrunk.Operator` has no `src/`, so there is no `HoneyDrunk.Operator.Abstractions` package to consume. No `PackageReference` for the Operator side; reconciling with `ICostGuard` is a follow-up once Operator is scaffolded.
- No new project is created. If against expectation one is, it references `HoneyDrunk.Standards` (`PrivateAssets: all`).
- The App Configuration / `IConfigProvider` access for the ceiling value uses Vault's `IConfigProvider`, already a transitive dependency via `HoneyDrunk.Vault` (which `HoneyDrunk.AI` already consumes per `catalogs/nodes.json`). No new package reference for that.

## Boundary Check
- [x] All code in `HoneyDrunk.AI`. AI-sector dispatch/cost work maps to the AI Node.
- [x] Audit dependency is on `HoneyDrunk.Audit.Abstractions` only — never `HoneyDrunk.Audit.Data` (invariant 48). It is a hard dependency (Audit is scaffolded).
- [x] No runtime dependency on the unscaffolded `HoneyDrunk.Operator` Node — the per-tenant guard uses the local `ITenantCostGuard` interface (Operator has no `src/`, no publishable `.Abstractions`).
- [x] Audit records do NOT flow to Pulse/telemetry — the audit channel is separate and durable (invariant 47).
- [x] Tenant mechanics sit at the intake edge; the core router stays tenant-agnostic for internal callers (invariant 39).

## Acceptance Criteria
- [ ] Every AI dispatch through `DefaultModelRouter` emits exactly one Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`
- [ ] A per-call ceiling rejection (the seam packet 04 left) emits an Audit entry with an outcome distinguishing it from a successful dispatch
- [ ] A per-tenant cost-guard layer runs before the router; a per-tenant ceiling breach rejects the call and emits an Audit entry with a tenant-ceiling outcome
- [ ] The per-tenant ceiling value is sourced from App Configuration via `IConfigProvider` — not a compiled constant (invariant 45)
- [ ] Audit entries go through `IAuditLog` (`HoneyDrunk.Audit.Abstractions`) — NOT through `InferenceTelemetry` or any Pulse path; the audit channel is separate and durable (invariant 47)
- [ ] The dispatch Audit emit depends on `HoneyDrunk.Audit.Abstractions` (hard dependency, `.Abstractions` only); if the package is not on the feed at execution, that is a blocker to resolve, not a reason for a local seam
- [ ] No runtime dependency on `HoneyDrunk.Operator` — the per-tenant guard uses the local `ITenantCostGuard` interface (Operator is unscaffolded)
- [ ] Internal Grid callers (`TenantId.Internal`) pass through the core router without a tenant-specific branch (invariant 39)
- [ ] Policy overrides (from packet 04's pinned policy) appear as a non-null `PolicyOverride` in the audit entry
- [ ] Unit tests cover: audit emit on success, audit emit on per-call rejection, audit emit on per-tenant rejection, the override appearing in the audit entry, the App-Configuration-sourced ceiling; no `Thread.Sleep` (invariant 51)
- [ ] No version bump — repo-level and `HoneyDrunk.AI` per-package CHANGELOGs append to the in-progress `[0.2.0]` entry
- [ ] `HoneyDrunk.AI/README.md` (and `HoneyDrunk.AI.Abstractions/README.md` if `ITenantCostGuard` is added) updated for any public-surface change
- [ ] Solution builds; `pr.yml` tier-1 gate passes; `api-compatibility.yml` contract-shape canary passes (any Abstractions addition is additive, covered by packet 02's bump)

## Human Prerequisites
- [ ] **App Configuration key for the per-tenant cost ceiling** — the per-tenant ceiling value must exist as an App Configuration setting (per ADR-0005's three-tier config split) before the cost guard enforces a real limit. The agent writes the code to read the key; seeding the App Configuration value is a portal action. If the key is absent the guard should fall back to a safe default (effectively no-limit or a conservative built-in default with a logged warning) so this is not in the agent's critical path — but the operator should seed the real value for the guard to be meaningful.
- [ ] **Publish `HoneyDrunk.Audit.Abstractions` to the package feed if not already there** — `HoneyDrunk.Audit` is scaffolded with buildable `Abstractions` + `Data` projects; this packet takes `HoneyDrunk.Audit.Abstractions` as a hard dependency. If the package is not yet on the feed at execution time, publishing it is a prerequisite to resolve (the same blocker packet 03 surfaces) — it is not optional and there is no local-seam fallback for the dispatch Audit emit.

## Referenced ADR Decisions
**ADR-0041 D5 — Policy overrides recorded for attribution.** Overrides are recorded in the Audit emit for the call (per ADR-0030) so cost outliers are attributable.

**ADR-0041 D6 — Cost guard intersection.** `CostProfile.MaxBudgetPerCallUsd` is the per-call ceiling enforced by the router; ADR-0018's `ICostGuard` is the per-tenant period ceiling enforced upstream. Both are required: per-call catches a runaway prompt on a single call; per-tenant catches a runaway loop over a day. The router checks the per-call ceiling before dispatching; the cost-guard layer checks the per-tenant ceiling before the router. Both checks emit Audit entries on rejection.

**ADR-0041 D10 / third invariant — Audit on every dispatch and every flip.** Every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`. The canary-driven `ApprovalState` flips are also recorded in Audit.

**Invariant 47 (audit).** Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Auditable events routed only to sampled or retention-bounded observability (Pulse / Loki) are a boundary violation. Audit records are not telemetry and never flow to Pulse.

**Invariant 48 (audit).** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`; `HoneyDrunk.Audit.Data` is never referenced in production composition.

**Invariant 45 (AI).** Token cost rates, routing policies, and capability declarations are sourced from Azure App Configuration via Vault's `IConfigProvider`. Hardcoded rates, policies, or ceilings in application code are forbidden.

**Invariant 39 (multi-tenant boundary).** Tenant resolution, tenant rate-limit checks, billing-event emission, and tenant-scoped secret lookup must live in intake middleware/orchestration edges. Core dispatch paths for internal Grid callers remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches.

## Constraints
- **Audit is NOT telemetry (invariant 47).** The dispatch Audit entry goes through `IAuditLog` (`HoneyDrunk.Audit.Abstractions`) — never through `InferenceTelemetry` or Pulse. The two channels are never merged.
- **`HoneyDrunk.Audit.Abstractions` is a hard dependency.** `HoneyDrunk.Audit` is scaffolded (buildable `Abstractions` + `Data`). Take the `HoneyDrunk.Audit.Abstractions` `PackageReference`; absence on the feed is a blocker to resolve, not a local-seam excuse. There is no permanent local audit sink.
- **`HoneyDrunk.Operator` is unscaffolded — keep the local `ITenantCostGuard` seam.** Operator has no `src/` and no publishable `.Abstractions`; the per-tenant guard uses the local `ITenantCostGuard` interface. Reconciling with ADR-0018's `ICostGuard` is a follow-up once Operator is scaffolded.
- **Audit dependency is `.Abstractions` only (invariant 48).** Never reference `HoneyDrunk.Audit.Data`.
- **The per-tenant ceiling is App-Configuration-sourced (invariant 45).** Not a compiled constant.
- **Tenant mechanics at the intake edge (invariant 39).** The per-tenant cost guard is an intake-edge check; the core router stays tenant-agnostic for internal callers.
- **No version bump (invariant 27).** Packet 02 is the bumping packet; this packet appends to `[0.2.0]`.
- **Reuse packet 04's rejection seam.** Packet 04 left a clean seam for the per-call-ceiling-rejection Audit emit — wire into it; do not re-architect the router.

## Labels
`feature`, `tier-2`, `ai`, `adr-0041`, `wave-4`

## Agent Handoff

**Objective:** Emit an Audit entry on every AI dispatch and add the per-tenant cost-guard intersection.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Make every routing decision forensically attributable and enforce the two-layer cost ceiling (per-call + per-tenant).
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 4 — the final implementation packet.
- ADRs: ADR-0041 D5/D6/D10 (primary), ADR-0018 (`ICostGuard` per-tenant model), ADR-0030 (Audit substrate), ADR-0005 (App Configuration).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — hard. The router rewire and the per-call-ceiling rejection seam must exist.

**Constraints:**
- Audit is not telemetry — emit via `IAuditLog` (`HoneyDrunk.Audit.Abstractions`), never Pulse.
- `HoneyDrunk.Audit.Abstractions` is a hard dependency (Audit is scaffolded) — `.Abstractions` only; absence on the feed is a blocker, not a local-seam excuse.
- `HoneyDrunk.Operator` is unscaffolded — the per-tenant guard uses the local `ITenantCostGuard` seam; reconciling with `ICostGuard` is a follow-up.
- Per-tenant ceiling is App-Configuration-sourced, not a constant.
- Tenant mechanics at the intake edge; core router tenant-agnostic for internal callers.
- No version bump — append to `[0.2.0]`.

**Key Files:**
- `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs`
- `src/HoneyDrunk.AI/Cost/` — per-tenant guard
- `src/HoneyDrunk.AI/Telemetry/InferenceTelemetry.cs` — keep audit separate
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`

**Contracts:**
- Consumes `IModelRegistry`, `CostProfile`, `ApprovalState` (packet 02) and the router/policy seams (packet 04).
- Consumes `IAuditLog`/`AuditEntry` from `HoneyDrunk.Audit.Abstractions` — hard dependency, `.Abstractions` only.
- Adds `ITenantCostGuard` to `HoneyDrunk.AI.Abstractions` (additive) — `HoneyDrunk.Operator` is unscaffolded so the local interface is the intended path.
