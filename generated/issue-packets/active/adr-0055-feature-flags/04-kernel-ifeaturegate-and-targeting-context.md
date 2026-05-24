---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0055", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0055"]
wave: 2
initiative: adr-0055-feature-flags
node: honeydrunk-kernel
---

# Add IFeatureGate, ITargetingContext, and InMemoryFeatureGate to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0055 feature-flag contract surface to `HoneyDrunk.Kernel.Abstractions` (and its testing companion): `IFeatureGate` (the only sanctioned surface for flag evaluation, per the new ADR-0055 invariant), `ITargetingContext` (carries `TenantId` / `PrincipalId` / `Tier` / `Tags` for targeting), supporting types as needed, and `InMemoryFeatureGate` test fixture in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15. Pure contracts and an in-memory fixture — zero HoneyDrunk runtime dependencies on `Microsoft.FeatureManagement`. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution in this initiative.

## Context
ADR-0055 D4 places `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `IGridContext`, `TenantId`, the lifecycle hooks, and (post ADR-0042) `IIdempotencyStore`. ADR-0055 D4 also names `InMemoryFeatureGate` in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15 — every Node's unit tests must be able to flip flags without depending on App Configuration.

This packet adds **contracts only**, plus the in-memory test fixture. The concrete `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation and the `TenantTargetingFilter` ship from the new Node `HoneyDrunk.FeatureFlags` (packet 05). Splitting contract-from-runtime keeps `HoneyDrunk.Kernel.Abstractions` honest under invariant 1 (Abstractions have zero runtime dependencies on other HoneyDrunk packages, and only `Microsoft.Extensions.*` abstractions from outside).

**`Microsoft.FeatureManagement` is NOT referenced from Kernel.Abstractions.** Per the first new ADR-0055 invariant ("feature flags are evaluated through `IFeatureGate`, never via direct SDK calls to `Microsoft.FeatureManagement` or the App Configuration client"), and per invariant 1, `HoneyDrunk.Kernel.Abstractions` defines `IFeatureGate` without any reference to the `Microsoft.FeatureManagement` package. The relationship is reversed: `HoneyDrunk.FeatureFlags` (packet 05) references `Microsoft.FeatureManagement.AzureAppConfiguration` internally and implements `IFeatureGate` on top of `IFeatureManager`; consumers depend on `IFeatureGate` only.

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (additive feature; no break). **Confirm the current version at execution time:** if ADR-0042's `0.8.0` has shipped first (the `adr-0042-idempotency` initiative is in flight at the time of scoping), this packet's bump is `0.8.0` → `0.9.0` (or the next minor); if ADR-0042 has not shipped, this packet bumps `0.7.0` → `0.8.0`. The bump rule is "next available minor"; per-package CHANGELOG entries go on `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel.Abstractions.Testing` (real functional change). The `HoneyDrunk.Kernel` runtime gets no per-package entry from this packet (alignment bump only — invariant 12/27).

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `IFeatureGate` — the evaluation interface.
  - `ITargetingContext` — explicit targeting context for off-request evaluations.
  - Optionally: `FeatureVariant<T>` or similar (a tiny record wrapping a named-variant result, if the API surface benefits — see Proposed Implementation step 3 for the decision rule).
- `HoneyDrunk.Kernel.Abstractions.Testing` — new test fixture:
  - `InMemoryFeatureGate` — implements `IFeatureGate` with in-memory state; supports `SetFlag(name, enabled)` and `SetVariant(name, value)` setup methods.
- Every non-test `.csproj` in the solution version-bumped to the next minor (invariant 27).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- `HoneyDrunk.Kernel.Abstractions.Testing` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` gets a new entry for the bumped version.

## Proposed Implementation
1. **`ITargetingContext`** — interface exposing the targeting fields ADR-0055 D4 names. Match the ADR's exact API:
   ```csharp
   public interface ITargetingContext
   {
       string? TenantId { get; }
       string? PrincipalId { get; }
       string? Tier { get; }
       IReadOnlyDictionary<string, string> Tags { get; }
   }
   ```
   Provide a default record implementation (e.g., `TargetingContext` — record, no `I`) that consumers can construct directly for off-request paths. The record validates that `Tags` is non-null (empty `IReadOnlyDictionary` if no tags).
2. **`IFeatureGate`** — interface exposing the three evaluation methods ADR-0055 D4 names:
   ```csharp
   public interface IFeatureGate
   {
       ValueTask<bool> IsEnabledAsync(string flagName);
       ValueTask<bool> IsEnabledAsync(string flagName, ITargetingContext context);
       ValueTask<T> GetVariantAsync<T>(string flagName, T defaultValue);
   }
   ```
   - `IsEnabledAsync(string)` is the on-request path — the default DI registration (packet 05) populates `ITargetingContext` from `RequestContext` (per ADR-0026) automatically.
   - `IsEnabledAsync(string, ITargetingContext)` is the off-request path — background workers, scheduled jobs that don't have a `RequestContext` but still need tenant-targeted flag evaluation.
   - `GetVariantAsync<T>(string, T)` is the variant-evaluation primitive — for flags that aren't binary but return one of several named variants. The `defaultValue` is returned if the flag isn't registered or the variant can't be resolved.
   XML-doc all three methods with the ADR's intent.
3. **Variant return type — decide at edit time.** ADR-0055 D4 says `GetVariantAsync<T>(name, default)` returns `T`. This works directly for simple value types and strings; for richer variant metadata (e.g., the operator wants the variant name *and* its value), the implementation may want a small `FeatureVariant<T>` record (`Name`, `Value`). The decision: ship the simple `T`-returning overload now (matches the ADR exactly); add `FeatureVariant<T>` later if a consumer needs it. Do not speculatively add the richer type.
4. **`InMemoryFeatureGate`** — in `HoneyDrunk.Kernel.Abstractions.Testing`. Implements `IFeatureGate` with three internal collections: `flags: Dictionary<string, bool>`, `variants: Dictionary<string, object>`, and an optional per-flag-targeting predicate dictionary for tenant/principal-based test scenarios. Public setup methods:
   ```csharp
   public InMemoryFeatureGate SetFlag(string name, bool enabled);
   public InMemoryFeatureGate SetVariant<T>(string name, T value);
   public InMemoryFeatureGate SetTargetedFlag(string name, Func<ITargetingContext, bool> predicate);
   ```
   - `IsEnabledAsync(name)` returns the value from `flags` if present, otherwise `false`.
   - `IsEnabledAsync(name, context)` evaluates the targeting predicate if present, otherwise falls back to the binary `flags` entry, otherwise `false`.
   - `GetVariantAsync<T>(name, default)` returns the value from `variants` cast to `T` if present and assignable, otherwise `default`.
   - The setup methods are chainable (return `this`) so test setup reads cleanly.
   - The fixture is **synchronously-completing** despite the `ValueTask` return — use `ValueTask.FromResult(...)` or just `return new ValueTask<bool>(...)`. No actual async work; the `ValueTask` is the interface obligation.
5. **All public types get XML documentation** (invariant 13). For `IFeatureGate`, the XML-doc explains the ADR-0055 invariant that this is the only sanctioned evaluation surface; for `InMemoryFeatureGate`, the XML-doc explains the test-fixture-only intent and references invariant 15.
6. **Version bump.** Bump every non-test `.csproj` in the solution to the same next-minor version in one commit. The expected target at scoping time is `0.8.0` (if ADR-0042's bump hasn't merged) or `0.9.0` (if it has). Confirm at edit time. Repo-level `CHANGELOG.md` adds a new dated version entry. `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` and `HoneyDrunk.Kernel.Abstractions.Testing/CHANGELOG.md` each get a per-package entry describing the new contracts. The `HoneyDrunk.Kernel` runtime CHANGELOG gets NO per-package entry (alignment bump only — invariant 12/27).
7. **README updates.** `HoneyDrunk.Kernel.Abstractions/README.md` — document `IFeatureGate` and `ITargetingContext` in the public-API section, with the ADR-0055 cross-reference and the "only sanctioned evaluation surface" note. `HoneyDrunk.Kernel.Abstractions.Testing/README.md` — document `InMemoryFeatureGate` with a usage example.
8. **Unit tests.** Add unit tests for `InMemoryFeatureGate` in the test project for `HoneyDrunk.Kernel.Abstractions.Testing` (or wherever the repo currently holds tests for the Testing fixture package): `SetFlag` round-trips; `SetVariant<T>` round-trips with the expected type; `SetTargetedFlag` predicate is called with the right `ITargetingContext`; `GetVariantAsync<T>(name, default)` returns the default for an unregistered flag. No `Thread.Sleep` (invariant 51); no external dependencies (invariant 15).

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files (`IFeatureGate.cs`, `ITargetingContext.cs`, `TargetingContext.cs`).
- `HoneyDrunk.Kernel.Abstractions.Testing/` — new test fixture (`InMemoryFeatureGate.cs`).
- Every non-test `.csproj` in the solution — version bump.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Kernel.Abstractions.Testing/CHANGELOG.md`, `README.md`.
- Repo-level `CHANGELOG.md`.
- Test project for `HoneyDrunk.Kernel.Abstractions.Testing` — new `InMemoryFeatureGate` unit tests.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions; the `IFeatureGate` / `ITargetingContext` contracts use only BCL types (`ValueTask`, `string`, `IReadOnlyDictionary`). **Explicitly: do NOT add `Microsoft.FeatureManagement` here.** That package belongs in `HoneyDrunk.FeatureFlags` per the abstraction/implementation split. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel.Abstractions.Testing`** — no new `PackageReference`. `InMemoryFeatureGate` is pure-BCL. `HoneyDrunk.Standards` is already referenced.
- **`HoneyDrunk.Kernel`** — no new `PackageReference` in this packet (runtime types do not change).
- The unit-test project follows the repo's existing test stack; no new packages introduced by this packet beyond what the test project already references.

## Boundary Check
- [x] `IFeatureGate`, `ITargetingContext` are Kernel contracts per ADR-0055 D4. Routing rule "context, GridContext, NodeContext, ... CorrelationId → HoneyDrunk.Kernel" and the ADR's explicit placement both map here.
- [x] `InMemoryFeatureGate` in `HoneyDrunk.Kernel.Abstractions.Testing` matches invariant 15's pattern (every Abstractions package may ship a companion Testing fixture package).
- [x] No reference to `Microsoft.FeatureManagement` — that lives in `HoneyDrunk.FeatureFlags` per the abstraction/implementation split.
- [x] No dependency on any other HoneyDrunk runtime package (invariants 1, 4).
- [x] Contracts + test fixture only; the App-Configuration-backed implementation (packet 05), the CI validation (packet 06), and the Notify pilot (packet 07) are separate packets.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IFeatureGate` with the three methods `IsEnabledAsync(string)`, `IsEnabledAsync(string, ITargetingContext)`, `GetVariantAsync<T>(string, T)` matching ADR-0055 D4 signatures
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `ITargetingContext` with `TenantId`, `PrincipalId`, `Tier`, `Tags` per ADR-0055 D4
- [ ] A default `TargetingContext` record (no `I`) implements `ITargetingContext`; consumers can construct it directly
- [ ] `HoneyDrunk.Kernel.Abstractions.Testing` exposes `InMemoryFeatureGate` with chainable setup methods `SetFlag(name, enabled)`, `SetVariant<T>(name, value)`, `SetTargetedFlag(name, predicate)`
- [ ] `InMemoryFeatureGate.IsEnabledAsync` returns `false` for unregistered flags (the safe-default, off-by-default semantics)
- [ ] `InMemoryFeatureGate.GetVariantAsync<T>(name, default)` returns the default for an unregistered flag and for a registered flag whose value cannot be cast to `T`
- [ ] All new public types have XML documentation (invariant 13); `IFeatureGate`'s XML-doc explicitly notes "only sanctioned evaluation surface — direct `Microsoft.FeatureManagement` consumption is forbidden per ADR-0055 invariant"
- [ ] `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel.Abstractions.Testing` have zero runtime `PackageReference` on any HoneyDrunk package and no reference to `Microsoft.FeatureManagement` (invariant 1)
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new dated version entry
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` and `HoneyDrunk.Kernel.Abstractions.Testing/CHANGELOG.md` each have new-version entries describing the feature-flag contracts
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry (no functional change — alignment bump only, per invariant 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` and `HoneyDrunk.Kernel.Abstractions.Testing/README.md` document the new public-API surface
- [ ] Unit tests for `InMemoryFeatureGate` cover the setup methods, the default-return behaviour, and the targeting predicate
- [ ] No `Thread.Sleep` in test code (invariant 51); no external dependencies in tests (invariant 15)
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new contracts are additive, paired with the version bump

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0055 D4 — `IFeatureGate` in Kernel.Abstractions; backing in HoneyDrunk.FeatureFlags.** The Kernel-abstraction / sibling-implementation split keeps the testing story clean: `InMemoryFeatureGate` lives in `HoneyDrunk.Kernel.Abstractions.Testing` per Invariant 15, so unit tests in any Node can flip flags without depending on App Configuration. Folding the implementation into Kernel would couple Kernel to App Configuration and force a Kernel version bump to swap providers.

**ADR-0055 D4 — `IFeatureGate` interface signatures (verbatim from the ADR):**
```csharp
public interface IFeatureGate
{
    ValueTask<bool> IsEnabledAsync(string flagName);
    ValueTask<bool> IsEnabledAsync(string flagName, ITargetingContext context);
    ValueTask<T> GetVariantAsync<T>(string flagName, T defaultValue);
}

public interface ITargetingContext
{
    string? TenantId { get; }
    string? PrincipalId { get; }
    string? Tier { get; }
    IReadOnlyDictionary<string, string> Tags { get; }
}
```

**ADR-0055 Consequences — new invariants.** Two new invariants land in packet 00: (1) feature flags are evaluated through `IFeatureGate`, never via direct SDK calls; (2) feature-flag names follow `{category}.{node}.{feature}` and are registered. This packet's `IFeatureGate` is the contract that makes invariant 1 enforceable; the XML-doc on the interface explicitly notes the rule so consumers see it at the call site.

**ADR-0055 Operational Consequences — additive minor bump.** `Kernel.Abstractions` gains new interfaces; per ADR-0035 this is an additive minor bump (additions on new interfaces, not on existing ones). No breaking change.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted. **Specifically: no `Microsoft.FeatureManagement` package reference here.** That package belongs in `HoneyDrunk.FeatureFlags` per the abstraction/implementation split. No runtime logic (no JSON loading, no DI) in Abstractions.
- **Invariant 4 — the dependency graph is a DAG; Kernel is at the root.** Do not reference any other HoneyDrunk runtime package.
- **Invariant 13 — all public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 15 — unit tests never depend on external services.** `InMemoryFeatureGate` is the fixture that enforces this for flag-consuming code.
- **Invariant 27 — all projects in a solution share one version and move together.** Every non-test `.csproj` goes to the same next-minor version in one commit. Partial bumps are forbidden.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel.Abstractions.Testing` get entries; `HoneyDrunk.Kernel` (alignment bump only) gets none.
- **Records drop the `I`; interfaces keep it.** `IFeatureGate` / `ITargetingContext` are interfaces (keep `I`); `TargetingContext` (record implementation) drops the `I`; `InMemoryFeatureGate` is a class (no `I`).
- **First new ADR-0055 invariant is enforceable starting now.** `IFeatureGate` is the only sanctioned evaluation surface. Document this on the interface's XML-doc.

## Labels
`feature`, `tier-2`, `core`, `adr-0055`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0055 feature-flag contract surface (`IFeatureGate`, `ITargetingContext`) and the `InMemoryFeatureGate` test fixture to `HoneyDrunk.Kernel.Abstractions` / `.Testing`, and bump the `HoneyDrunk.Kernel` solution by one minor version.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the contracts every other packet in this initiative compiles against, plus the test fixture every consuming Node's unit tests will use.
- Feature: ADR-0055 Feature Flag rollout, Wave 2 (the foundation).
- ADRs: ADR-0055 D4 (primary), ADR-0035 (additive minor-bump policy), ADR-0026 (RequestContext sources for ITargetingContext defaults — relevant to packet 05's DI default, noted here for context), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0055 Accepted and its two invariants live before the contracts are built against them.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). **No reference to `Microsoft.FeatureManagement`.**
- Bump every non-test `.csproj` to the same next-minor version in one commit (invariant 27). Confirm the target version at edit time (0.8.0 if ADR-0042's 0.8.0 hasn't shipped; 0.9.0 if it has).
- Records drop the `I`; interfaces keep it; `InMemoryFeatureGate` is a class.
- `IFeatureGate`'s XML-doc declares it the only sanctioned evaluation surface per ADR-0055 invariant.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/IFeatureGate.cs`, `ITargetingContext.cs`, `TargetingContext.cs` (new).
- `HoneyDrunk.Kernel.Abstractions.Testing/InMemoryFeatureGate.cs` (new).
- Every non-test `.csproj` for the version bump.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; `HoneyDrunk.Kernel.Abstractions.Testing/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.

**Contracts:**
- `IFeatureGate` (new interface) — `IsEnabledAsync(string)`, `IsEnabledAsync(string, ITargetingContext)`, `GetVariantAsync<T>(string, T)`.
- `ITargetingContext` (new interface) — `TenantId`, `PrincipalId`, `Tier`, `Tags`.
- `TargetingContext` (new record) — default implementation of `ITargetingContext`.
- `InMemoryFeatureGate` (new test class in Testing package) — `SetFlag`, `SetVariant`, `SetTargetedFlag` setup methods.
