---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0063", "wave-1"]
dependencies: []
adrs: ["ADR-0063"]
wave: 1
initiative: adr-0063-clock-policy
node: honeydrunk-kernel
---

# Add AddSystemTimeProvider and AddFakeTimeProvider DI helpers to HoneyDrunk.Kernel

## Summary
Add two `IServiceCollection` extension methods to `HoneyDrunk.Kernel` per ADR-0063 D1 and D11: `AddSystemTimeProvider()` registers the BCL `TimeProvider.System` as the singleton `TimeProvider` for production hosts; `AddFakeTimeProvider(DateTimeOffset? initialInstant = null)` registers `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider` for test fixtures and exposes the concrete fake on the service collection so individual tests can retrieve and drive it. **Kernel does not wrap `TimeProvider` — no `IGridClock`, no proxy interface.** This is the version-bumping packet for the `HoneyDrunk.Kernel` solution: `0.7.0` → `0.8.0`.

## Context
ADR-0063 commits the BCL `TimeProvider` as the Grid-wide clock abstraction (D1) and places the DI registration helpers in `HoneyDrunk.Kernel` (D11). The rationale is stated explicitly in D11: "The platform-level abstraction is the contract; layering an additional interface on top is ceremony without value." Kernel's role is to make `TimeProvider.System` and `FakeTimeProvider` trivial to compose at the host level via DI — not to introduce a `HoneyDrunk.Kernel.IClock` or any wrapper.

`HoneyDrunk.Kernel/boundaries.md` is consistent with this: "BCL wrappers — No `IClock`, `IIdGenerator`, `ILogSink`. Use BCL directly." `TimeProvider` is a BCL type; Kernel ships the host-time composition helpers, not a wrapper.

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0`; new feature, additive helpers, no break).

> **Placement note — helpers ship in the `HoneyDrunk.Kernel` runtime package, not `HoneyDrunk.Kernel.Abstractions`.** The helpers take a `PackageReference` on `Microsoft.Extensions.TimeProvider.Testing` for `FakeTimeProvider`; `HoneyDrunk.Kernel.Abstractions` has zero runtime dependencies on third-party packages beyond `Microsoft.Extensions.*` abstractions (invariant 1). The helpers themselves are runtime code (DI composition), not contracts — they belong in the runtime package.
>
> **`Microsoft.Extensions.TimeProvider.Testing` is a runtime `PackageReference` on the Kernel runtime package, not test-project-only.** Reason: `AddFakeTimeProvider()` instantiates `FakeTimeProvider` at compose time, and that helper is part of Kernel's public runtime API. The package is MIT-licensed Microsoft and small; the dependency is acceptable (the ADR's Negative consequence explicitly accepts this cost). Hosts that call only `AddSystemTimeProvider()` still get the transitive package on their Kernel reference, which is intentional — having `FakeTimeProvider` available for any host (e.g. a host running in a synthetic-time mode for replay) is the point of putting both helpers next to each other.

## Scope
- `HoneyDrunk.Kernel` (runtime package) — new public extension methods:
  - `IServiceCollection AddSystemTimeProvider(this IServiceCollection services)` — registers `TimeProvider.System` as the singleton `TimeProvider`.
  - `IServiceCollection AddFakeTimeProvider(this IServiceCollection services, DateTimeOffset? initialInstant = null)` — registers `FakeTimeProvider` as the singleton `TimeProvider` and *also* registers `FakeTimeProvider` itself as a resolvable singleton (so test fixtures can `serviceProvider.GetRequiredService<FakeTimeProvider>().Advance(...)`).
- `HoneyDrunk.Kernel` `.csproj` — add `PackageReference` on `Microsoft.Extensions.TimeProvider.Testing`.
- Unit tests in `HoneyDrunk.Kernel.Tests` covering both helpers.
- Both `.csproj` files in the solution version-bumped to `0.8.0` (invariant 27).
- `HoneyDrunk.Kernel` package `CHANGELOG.md` and `README.md` updated. `HoneyDrunk.Kernel.Abstractions` gets no per-package CHANGELOG entry (alignment bump only — no functional change in Abstractions).
- Repo-level `CHANGELOG.md` gets a new `[0.8.0]` entry.

## Proposed Implementation
1. **`AddSystemTimeProvider`** — a one-liner extension method that calls `services.TryAddSingleton<TimeProvider>(TimeProvider.System)`. Use `TryAddSingleton` (idempotent, doesn't overwrite a previously-registered `TimeProvider`) — so a test fixture that already wired `AddFakeTimeProvider` upstream is not silently overridden if the host's composition path also calls `AddSystemTimeProvider`. XML-doc the idempotency.
2. **`AddFakeTimeProvider`** — registers a `FakeTimeProvider` singleton both as `TimeProvider` (the abstract base) AND as the concrete `FakeTimeProvider` type, so callers can resolve either. The shape:
   ```
   public static IServiceCollection AddFakeTimeProvider(
       this IServiceCollection services,
       DateTimeOffset? initialInstant = null)
   {
       var fake = new FakeTimeProvider(initialInstant ?? DateTimeOffset.UtcNow);
       services.AddSingleton(fake);
       services.AddSingleton<TimeProvider>(fake);
       return services;
   }
   ```
   The `initialInstant` parameter defaults to `DateTimeOffset.UtcNow` — note this is one of the documented carve-outs for `DateTimeOffset.UtcNow` (process-startup bootstrap; DI not yet up at this exact composition moment). Document the carve-out in an XML-doc remark. If the analyzer rule (packet 03) flags this call, the helper opt-out attribute applies — the helper itself is the boundary.
   Use straight `AddSingleton` (not `TryAddSingleton`) — calling `AddFakeTimeProvider` is an explicit decision to use the fake; overwriting a prior registration is the intended behaviour in test composition.
3. **XML documentation** — both helpers carry full XML-doc explaining:
   - Why Kernel ships these as helpers, not as a `TimeProvider` wrapper (cite ADR-0063 D11).
   - The idempotency posture of each (`TryAddSingleton` vs `AddSingleton`).
   - That `AddFakeTimeProvider` registers `FakeTimeProvider` separately so tests can drive the clock via `IServiceProvider.GetRequiredService<FakeTimeProvider>().Advance(...)`.
4. **Unit tests** — `HoneyDrunk.Kernel.Tests` adds:
   - `AddSystemTimeProvider_RegistersTimeProviderSystem` — calling it and resolving `TimeProvider` returns `TimeProvider.System`.
   - `AddSystemTimeProvider_IsIdempotent` — calling twice does not throw; resolving still works.
   - `AddSystemTimeProvider_DoesNotOverrideExistingRegistration` — pre-register a `TimeProvider`, call `AddSystemTimeProvider`, resolve → still the pre-registered one.
   - `AddFakeTimeProvider_RegistersFakeAsTimeProvider` — resolves `TimeProvider` → instance is the same `FakeTimeProvider`.
   - `AddFakeTimeProvider_RegistersConcreteFakeType` — resolves `FakeTimeProvider` directly → same instance as the `TimeProvider` registration (assert reference equality).
   - `AddFakeTimeProvider_InitialInstant_IsRespected` — pass an `initialInstant`; resolve `TimeProvider`; `GetUtcNow()` returns that instant.
   - `AddFakeTimeProvider_Advance_AffectsResolvedTimeProvider` — `Advance(5 minutes)`; `GetUtcNow()` advances by 5 minutes.
   - No `Thread.Sleep` (invariant 51); no `await Task.Delay()`-as-wait (invariant 57 once packet 00 lands).
5. **Version bump** — both `.csproj` files in the solution to `0.8.0`. Append a repo-level `[0.8.0]` CHANGELOG entry: "Added `AddSystemTimeProvider` and `AddFakeTimeProvider` DI helpers in `HoneyDrunk.Kernel` per ADR-0063 D11." Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel`. `HoneyDrunk.Kernel.Abstractions` gets no per-package CHANGELOG entry (no functional change — alignment bump only per invariant 12/27).
6. **README update** — `HoneyDrunk.Kernel/README.md` documents the two helpers in the public-API section. Repo-level `README.md` gets a short "Date and Time" subsection if a Date/Time section is not already present.

## Affected Files
- `HoneyDrunk.Kernel/` — new `TimeProviderServiceCollectionExtensions.cs` (or split into `SystemTimeProviderExtensions.cs` and `FakeTimeProviderExtensions.cs` — match the repo's existing file-per-extension-area convention).
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump and new `PackageReference` on `Microsoft.Extensions.TimeProvider.Testing`.
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump (alignment).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `HoneyDrunk.Kernel/README.md`.
- Repo-level `CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Kernel.Tests/` — new test class(es) for both helpers.

## NuGet Dependencies
- **`HoneyDrunk.Kernel`** — new `PackageReference`:
  - `Microsoft.Extensions.TimeProvider.Testing` — latest stable major-version-matched to .NET 10 / `Microsoft.Extensions.*` 10.x (so `9.x` if 9 is current latest GA — the package follows the `Microsoft.Extensions.*` cadence; check the current major before pinning).
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. The DI helpers ship in the runtime package, not Abstractions (invariant 1 preserved).
- **`HoneyDrunk.Kernel.Tests`** — no new `PackageReference` strictly required (it transits the runtime's reference). If the test project wants to use `FakeTimeProvider` types directly outside of the helper-test code paths, add `Microsoft.Extensions.TimeProvider.Testing` as a direct reference too.

## Boundary Check
- [x] DI helpers belong in `HoneyDrunk.Kernel` per ADR-0063 D11. Routing rule "context, GridContext, NodeContext, ... lifecycle, DI helpers → HoneyDrunk.Kernel" maps exactly. Kernel's `boundaries.md` already names DI composition helpers as in-scope.
- [x] No new contract in `HoneyDrunk.Kernel.Abstractions` — these are runtime composition helpers, not contracts.
- [x] No HoneyDrunk-owned `IGridClock` or proxy interface — Kernel does not wrap `TimeProvider` (invariant added in packet 00; ADR-0063 D11). Routing rule "BCL wrappers — Use BCL directly" applies.
- [x] No reference to any other HoneyDrunk runtime package (invariant 4, DAG preserved).

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel` exposes `IServiceCollection AddSystemTimeProvider(this IServiceCollection services)` that registers `TimeProvider.System` as the singleton `TimeProvider` using `TryAddSingleton`
- [ ] `HoneyDrunk.Kernel` exposes `IServiceCollection AddFakeTimeProvider(this IServiceCollection services, DateTimeOffset? initialInstant = null)` that registers `FakeTimeProvider` as both `TimeProvider` and the concrete `FakeTimeProvider` type via `AddSingleton`
- [ ] `AddSystemTimeProvider` is idempotent and does NOT override an already-registered `TimeProvider`
- [ ] `AddFakeTimeProvider` overwrites a prior registration when called (explicit composition wins; unit-tested)
- [ ] Resolving `TimeProvider` after `AddFakeTimeProvider` returns the same instance as resolving `FakeTimeProvider` (reference-equal)
- [ ] `Advance(TimeSpan)` on the resolved `FakeTimeProvider` updates the `GetUtcNow()` of the resolved `TimeProvider`
- [ ] Both helpers carry full XML documentation including the rationale ("ADR-0063 D11 — Kernel does not wrap `TimeProvider`; ships DI helpers instead")
- [ ] `HoneyDrunk.Kernel` `.csproj` has a `PackageReference` on `Microsoft.Extensions.TimeProvider.Testing` (current stable major matched to `Microsoft.Extensions.*` 10.x cadence)
- [ ] `HoneyDrunk.Kernel.Abstractions` has NO `PackageReference` change (invariant 1 — zero runtime HoneyDrunk-owned-contract change; the testing package does not land in Abstractions)
- [ ] No `IGridClock`, `IClock`, or any HoneyDrunk-owned wrapper around `TimeProvider` is introduced (invariant 54 from packet 00 + ADR-0063 D11)
- [ ] Both non-test `.csproj` files in the solution are at version `0.8.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.8.0]` entry dated to the merge
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` has a `[0.8.0]` entry describing the DI helpers
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` gets NO entry (alignment bump only — invariant 12/27)
- [ ] `HoneyDrunk.Kernel/README.md` documents both helpers
- [ ] Unit tests contain no `Thread.Sleep` (invariant 51) and no `Task.Delay`-as-wall-clock-wait (invariant 57 once packet 00 lands)
- [ ] The `pr-core.yml` tier-1 gate and any Kernel contract-shape canary pass — the additions are runtime helpers (not Abstractions-shape changes), paired with the `0.8.0` bump

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0063 D1 — `TimeProvider` is the Grid-wide clock abstraction.** Every Node reads "now" via `System.TimeProvider.GetUtcNow()`. Production wires `TimeProvider.System`; tests wire `FakeTimeProvider`. The DI registration helpers live in `HoneyDrunk.Kernel` per D11.

**ADR-0063 D7 — `FakeTimeProvider` is the test substrate.** `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider` is the committed package. Tests advance time via `Advance(TimeSpan)` or `SetUtcNow(DateTimeOffset)`.

**ADR-0063 D11 — Where the contract lives — Kernel helpers, no Kernel interface.** "Kernel does not wrap [`TimeProvider`]. Kernel does not publish `IGridClock` or `IClock` or any HoneyDrunk-owned interface that proxies `TimeProvider`. The platform-level abstraction is the contract; layering an additional interface on top is ceremony without value. What Kernel does provide: DI registration helpers in `HoneyDrunk.Kernel` — `services.AddSystemTimeProvider()`, `services.AddFakeTimeProvider(DateTimeOffset? initialInstant = null)`."

**ADR-0063 Operational Consequences — `Microsoft.Extensions.TimeProvider.Testing` is a Microsoft NuGet package and adds a test-project dependency.** "It is MIT-licensed and stewardship is Microsoft; the trust posture is good. The dependency itself is small. Acceptable cost." (This packet places the `PackageReference` on the Kernel runtime package, not test-project-only, because `AddFakeTimeProvider` is a Kernel runtime API — see the Placement note in Context.)

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** The helpers ship in the `HoneyDrunk.Kernel` runtime package, not `HoneyDrunk.Kernel.Abstractions`. Do not add `Microsoft.Extensions.TimeProvider.Testing` to `Abstractions.csproj`.
- **Invariant 4 — DAG; Kernel is at the root.** No `PackageReference` to any other HoneyDrunk runtime package.
- **Invariant 13 — all public APIs have XML documentation.** Both helpers carry doc-comments with the ADR-0063 D11 rationale.
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files go to `0.8.0` in one commit. Partial bumps are forbidden. This is the bumping packet.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel` gets an entry; `HoneyDrunk.Kernel.Abstractions` (alignment bump only) gets none.
- **No `IGridClock` wrapper.** ADR-0063 D11 is explicit: Kernel ships helpers, not an interface. This packet is the test of that commitment — the implementing agent does not introduce a "thin wrapper for testability" or any equivalent. If you feel the urge to introduce one, the ADR's Alternatives Considered section ("Wrap `TimeProvider` in a HoneyDrunk-owned `IGridClock` interface") already answers it: rejected.
- **`AddFakeTimeProvider`'s default `initialInstant`.** The default is `DateTimeOffset.UtcNow` at the moment the helper is called — a documented carve-out per ADR-0063 D1's process-startup-bootstrap exception. The analyzer rule from packet 03 will need the opt-out attribute on this exact call site (or the rule must not flag this single specific line). Apply the opt-out attribute when packet 03 lands; for now, document the carve-out in XML-doc.

## Labels
`feature`, `tier-2`, `core`, `adr-0063`, `wave-1`

## Agent Handoff

**Objective:** Add `AddSystemTimeProvider` and `AddFakeTimeProvider` DI helpers to `HoneyDrunk.Kernel` per ADR-0063 D11, and bump the `HoneyDrunk.Kernel` solution to `0.8.0`.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the host-time composition surface so every production host calls `AddSystemTimeProvider()` and every test fixture calls `AddFakeTimeProvider()` — no other surface needed, no wrapper.
- Feature: ADR-0063 Date, Time, and Clock Policy rollout, Wave 1.
- ADRs: ADR-0063 D1/D7/D11 (primary), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None expressed in `dependencies:`. Packet 02 can land before packet 00 (the acceptance flip) — the helpers compile and ship against a Proposed ADR; the invariant that bans direct `DateTime.UtcNow` is only an *invariant* once packet 00 lands, and only *enforced* when packet 03 ships the analyzer rule. The merge ordering is operator discipline; this packet does not block on any other packet in the initiative.

**Constraints:**
- Helpers ship in the `HoneyDrunk.Kernel` runtime package, not Abstractions (invariant 1).
- No `IGridClock` or any HoneyDrunk-owned wrapper around `TimeProvider` (ADR-0063 D11).
- `AddSystemTimeProvider` uses `TryAddSingleton` (idempotent); `AddFakeTimeProvider` uses `AddSingleton` (explicit composition wins).
- Bump both non-test `.csproj` files to `0.8.0` in one commit (invariant 27).
- No `Thread.Sleep`, no `Task.Delay`-as-wall-clock-wait in tests.

**Key Files:**
- `HoneyDrunk.Kernel/TimeProviderServiceCollectionExtensions.cs` (or split per repo convention).
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump + new `PackageReference`.
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump (alignment).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Tests/` — new test class.

**Contracts:**
- `AddSystemTimeProvider(this IServiceCollection services)` (new extension on `HoneyDrunk.Kernel`) — registers `TimeProvider.System` as singleton `TimeProvider` via `TryAddSingleton`.
- `AddFakeTimeProvider(this IServiceCollection services, DateTimeOffset? initialInstant = null)` (new extension on `HoneyDrunk.Kernel`) — registers `FakeTimeProvider` as both `TimeProvider` and the concrete `FakeTimeProvider` via `AddSingleton`.
- Consumes the BCL `System.TimeProvider` and `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`. No HoneyDrunk contract is added or changed.
