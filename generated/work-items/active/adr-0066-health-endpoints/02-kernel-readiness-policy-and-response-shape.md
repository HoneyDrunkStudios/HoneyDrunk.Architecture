---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0066", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0066"]
wave: 2
initiative: adr-0066-health-endpoints
node: honeydrunk-kernel
---

# Add ReadinessPolicy and the IETF response-shape contracts to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0066 contract surface that downstream packets compile against to `HoneyDrunk.Kernel.Abstractions`: the `ReadinessPolicy` enum (D7), the IETF `health+json` response DTOs (`HealthCheckResponse`, `HealthCheckEntry`), and the contributor-registration helper signatures the Kernel runtime helper consumes. Pure contracts — zero HoneyDrunk runtime dependencies. **This is the version-bumping packet for the `HoneyDrunk.Kernel` solution in this initiative.**

## Context
ADR-0066 D7 commits a `ReadinessPolicy` enum with three values (`Required` (default), `OptionalReported`, `NotReadinessRelevant`) that declares whether an `IHealthContributor` gates traffic at `/health/ready` or only appears in the `/health` aggregate. The enum is `Kernel.Abstractions`-side because every contributor implementation needs to declare its policy at registration time and the host wiring composes against it.

ADR-0066 D2 commits the IETF `application/health+json` response shape for `/health`. The wire-shape DTOs (`HealthCheckResponse`, `HealthCheckEntry`) live in `Kernel.Abstractions` so that downstream Nodes amending their health-endpoint code (Pulse.Collector, Notify) can reference the shape if they need typed access to it. Per ADR-0066 D3 the Kernel `HealthStatus` enum stays the implementation surface; the wire encoding (`Healthy`→`"pass"`, `Degraded`→`"warn"`, `Unhealthy`→`"fail"`) maps from `HealthStatus` to the IETF string at the response-writer boundary in packet 03.

This packet ships **contracts only** — the enum, the records, and the registration-helper signatures (interface or static-method shape per existing Kernel registration patterns). The endpoint mapping (`MapHoneyDrunkHealthEndpoints`), the IETF response writer, the Functions-host helper, and the contributor-execution timeout wrapper land in packet 03 (the runtime package). Splitting contract-from-runtime keeps `HoneyDrunk.Kernel.Abstractions` honest under invariant 1 (Abstractions have zero runtime dependencies on other HoneyDrunk packages).

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0`; new feature, additive contracts, no break). Packet 03 (also Kernel) appends to the in-progress `[0.8.0]` CHANGELOG entry; packet 04 (Kernel docs) is repo-state-only.

> **Cross-initiative version coordination.** ADR-0042 packet 02 *also* bumps `HoneyDrunk.Kernel` to `0.8.0` (its own contract additions: `IGridMessageEnvelope`, `IIdempotencyStore`, etc.). If both initiatives run concurrently, they share the same `0.8.0` line. Coordinate at execution time: if ADR-0042 packet 02 has already merged when this packet starts, the solution is already at `0.8.0` and this packet **appends to the existing `[0.8.0]` CHANGELOG entry without bumping** (per invariant 27, two simultaneous initiatives must not partially overlap a single version line via parallel bumps). If neither has merged yet, this packet is the bumping packet; coordinate with the ADR-0042 packet-02 author to share the version-bumping commit if both go in the same PR window. State the chosen sequence in the PR.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `ReadinessPolicy` — `enum` with `Required` (default), `OptionalReported`, `NotReadinessRelevant`.
  - `HealthCheckResponse` — record/DTO for the `/health` body root (`status`, `version`, `releaseId`, `checks`).
  - `HealthCheckEntry` — record/DTO for a per-contributor entry inside `checks` (`status`, `time`, optional `output`).
  - The registration helper signature for declaring a contributor's `ReadinessPolicy` at composition time. Match the existing Kernel registration pattern (likely an extension method on `IServiceCollection` or a registration-options shape consumed by `MapHoneyDrunkHealthEndpoints` in packet 03 — pick the shape that matches existing Kernel registration conventions and document it in the PR).
- Both `.csproj` files in the solution version-bumped to `0.8.0` (invariant 27) — **see Cross-Initiative Version Coordination above; defer the bump if ADR-0042 packet 02 has already landed it**.
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` gets a `[0.8.0]` entry (new or appended depending on the ADR-0042 sequencing).

## Proposed Implementation
1. **`ReadinessPolicy`** — an enum with three named values:
   - `Required` (default) — contributor degraded/unhealthy fails `/health/ready`.
   - `OptionalReported` — contributor appears in `/health` body but does not affect `/health/ready`.
   - `NotReadinessRelevant` — contributor only appears in `/health`, never participates in readiness aggregation.
   XML-doc each value with ADR-0066 D7's prose. Make `Required` the zero/default value (so a `default(ReadinessPolicy)` resolves to `Required`, matching D7's "default at registration is `Required`").
2. **`HealthCheckResponse`** — a record matching the IETF `application/health+json` minimum payload from ADR-0066 D2:
   ```csharp
   public sealed record HealthCheckResponse
   {
       public required string Status { get; init; }       // "pass" | "warn" | "fail"
       public string? Version { get; init; }
       public string? ReleaseId { get; init; }
       public IReadOnlyDictionary<string, IReadOnlyList<HealthCheckEntry>> Checks { get; init; } =
           new Dictionary<string, IReadOnlyList<HealthCheckEntry>>();
   }
   ```
   The IETF draft allows multiple entries per check key (some checks report multiple instances over time); honour that by typing `Checks` as `name → list-of-entries`. ADR-0066 D2's sample carries a single-element list per key — match that.
3. **`HealthCheckEntry`** — a record for a single per-contributor entry:
   ```csharp
   public sealed record HealthCheckEntry
   {
       public required string Status { get; init; }       // "pass" | "warn" | "fail"
       public required DateTimeOffset Time { get; init; }
       public string? Output { get; init; }
   }
   ```
   XML-doc the `Output` property with the ADR-0066 D8 PII rule (must not carry secrets, connection strings, tenant identifiers, or provider opaque IDs — the contributor is responsible for redaction at the report site).
4. **Registration helper.** The shape depends on whether existing Kernel registration uses options-pattern, extension-methods, or DI-keyed registrations. Choose the shape that matches existing Kernel conventions for registering `IStartupHook` / `IHealthContributor` / `IReadinessContributor` today. Likely candidate: a new overload of the existing contributor-registration extension that takes a `ReadinessPolicy` parameter, plus a property-shaped form for the policy on a registration record. Whatever shape is chosen must be reachable from packet 03's `MapHoneyDrunkHealthEndpoints` so the aggregator can read per-contributor policy at runtime. State the chosen shape in the PR.
5. **Records use `init` members, not positional syntax** (per ADR-0035 D-record convention; also the Grid naming-rule memory note that records drop the `I`).
6. All public types get full XML documentation (invariant 13).
7. **Version bump.** Bump both `.csproj` files to `0.8.0` (or skip the bump if ADR-0042 packet 02 has already shipped it — see Cross-Initiative Version Coordination above; in that case this packet only adds new types and appends to the existing CHANGELOG entry).
8. **CHANGELOG.** Add a `[0.8.0]` repo-level entry (or append to the existing one). Add a `[0.8.0]` per-package entry to `HoneyDrunk.Kernel.Abstractions` (it has real changes). The `HoneyDrunk.Kernel` runtime package gets no per-package CHANGELOG entry in *this* packet (no functional change yet — packet 03 adds the runtime code and its entry); it is still version-bumped to `0.8.0` to keep the solution aligned, with no noise entry (invariant 12/27).
9. **README.** Update `HoneyDrunk.Kernel.Abstractions/README.md` — the public API surface gained the readiness-policy enum and the IETF response DTOs; document them in the API-surface section.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files. Likely under `Lifecycle/` (next to `IHealthContributor.cs` and `IReadinessContributor.cs`) for `ReadinessPolicy`; under `Health/` (next to `HealthStatus.cs`) for the IETF response DTOs.
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump (conditional).
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump (alignment, conditional).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Tests` (the existing test project) — tests for `ReadinessPolicy` default value, `HealthCheckResponse`/`HealthCheckEntry` JSON round-trip (using the IETF field names).

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions. The records use BCL types (`DateTimeOffset`, `IReadOnlyDictionary<,>`); JSON serialization is the consumer's concern at the response-writer boundary (packet 03). `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — no new `PackageReference` in this packet (runtime code lands in packet 03).
- The unit-test project follows the repo's existing test stack (ADR-0047 stack: xUnit v2 + NSubstitute + AwesomeAssertions); no new packages introduced by this packet beyond what the test project already references.

## Boundary Check
- [x] `ReadinessPolicy`, the IETF response DTOs, and the registration-helper signatures are Kernel contracts per ADR-0066 D7/D2/D9. Routing rule "context, GridContext, ... health contributor → HoneyDrunk.Kernel" maps here.
- [x] No dependency on ASP.NET Core in `Abstractions` (the ASP.NET-coupled `MapHoneyDrunkHealthEndpoints` lands in the runtime package in packet 03).
- [x] Contracts only; the endpoint mapping (packet 03), Pulse amendment (packet 05), and Notify amendments (packets 06, 07) are separate packets.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `ReadinessPolicy` as an enum with values `Required`, `OptionalReported`, `NotReadinessRelevant`
- [ ] `Required` is the default (zero-value) member of the enum
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `HealthCheckResponse` as a record matching the IETF `application/health+json` minimum payload (`status`, `version`, `releaseId`, `checks`)
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `HealthCheckEntry` as a record (`status`, `time`, `output?`)
- [ ] The registration-helper shape for declaring a contributor's `ReadinessPolicy` is added, matching existing Kernel registration conventions; the chosen shape is described in the PR
- [ ] Records use `init` members, not positional syntax (ADR-0035 convention)
- [ ] All new public types have XML documentation; `HealthCheckEntry.Output` XML doc references the ADR-0066 D8 PII rule (no secrets, connection strings, tenant identifiers, or provider opaque IDs)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1)
- [ ] Both non-test `.csproj` files in the solution are at the agreed version (`0.8.0` if this packet bumps; same as current if ADR-0042 packet 02 already bumped — see Cross-Initiative Version Coordination); they move together in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a `[0.8.0]` entry (new or appended) for the readiness-policy enum + IETF DTOs
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has a `[0.8.0]` entry describing the new types
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry in this packet (alignment bump only — invariant 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new types in the public-API section
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new contracts are additive, paired with the `0.8.0` line

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0066 D7 — `ReadinessPolicy` enum.** Three values: `Required` (default; degraded/unhealthy fails `/health/ready`), `OptionalReported` (in `/health` body only), `NotReadinessRelevant` (only in `/health`). Default at registration is `Required`.

**ADR-0066 D2 — IETF `application/health+json` response shape.** Minimum payload: `status` (`pass`/`warn`/`fail`), `version`, `releaseId`, `checks` keyed by contributor name carrying per-entry `status`/`time`/optional `output`.

**ADR-0066 D3 — Status mapping.** Kernel `HealthStatus` enum stays the implementation surface; wire encoding is `Healthy`→`"pass"`, `Degraded`→`"warn"`, `Unhealthy`→`"fail"`. The mapping lives at the response-writer boundary in the Kernel runtime helper (packet 03), not in the DTO itself — the DTO carries the wire-string form.

**ADR-0066 D8 — Contributor message PII rule.** The DTO's `Output` field carries the contributor's message string; per D8 this string must never carry secrets, connection strings, tenant identifiers, or provider opaque IDs. Redaction is the contributor's responsibility at the report site, not the DTO's or the response writer's. XML-doc the rule on `Output` so consumers see the constraint when they reference the type.

**ADR-0066 D9 — Implementation home.** The endpoint helpers live in `HoneyDrunk.Kernel` (runtime, not Abstractions — runtime composes with ASP.NET Core which Abstractions does not). The substrate is `Microsoft.Extensions.Diagnostics.HealthChecks` plus a Kernel-shipped response writer.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted. No ASP.NET-Core types in Abstractions; the endpoint mapping helper is runtime-package territory.
- **Invariant 4 — DAG; Kernel is at the root.** No reference to other HoneyDrunk runtime packages from `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 13 — all public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files go to `0.8.0` in one commit. Partial bumps are forbidden. Coordinate with ADR-0042 packet 02 if both initiatives are concurrent — see Cross-Initiative Version Coordination above.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment bump only here) gets none.
- **ADR-0035 — records use `init` members, not positional syntax.** No record positional declarations.
- **Records drop the `I`; interfaces keep it.** `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry` are enum/records — no `I` prefix. The existing `IHealthContributor` / `IReadinessContributor` stay `I`-prefixed.
- **`Required` is the zero default of `ReadinessPolicy`.** A `default(ReadinessPolicy)` resolves to `Required`, matching ADR-0066 D7's "default at registration is `Required`" prose.

## Labels
`feature`, `tier-2`, `core`, `adr-0066`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0066 contract surface (`ReadinessPolicy`, IETF response DTOs, contributor-registration shape) to `HoneyDrunk.Kernel.Abstractions`.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the contracts every other packet in this initiative (packet 03 runtime, packet 05 Pulse, packets 06/07 Notify) compiles against.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 2 (the foundation).
- ADRs: ADR-0066 D2/D3/D7/D8/D9 (primary), ADR-0035 (additive minor-bump policy + record convention), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0066 Accepted and its three invariants live before the contracts are built against them.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). No reference to ASP.NET-Core types.
- Records use `init` members (ADR-0035).
- Records/enums drop the `I`; existing `IHealthContributor` / `IReadinessContributor` keep it.
- `Required` is the zero-default `ReadinessPolicy`.
- Bump both non-test `.csproj` files together (invariant 27). Coordinate with ADR-0042 packet 02 if both initiatives concurrently target `0.8.0`.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/Lifecycle/ReadinessPolicy.cs` (new — alongside `IHealthContributor.cs` and `IReadinessContributor.cs`).
- `HoneyDrunk.Kernel.Abstractions/Health/HealthCheckResponse.cs` (new — alongside `HealthStatus.cs`).
- `HoneyDrunk.Kernel.Abstractions/Health/HealthCheckEntry.cs` (new).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the (conditional) version bump.

**Contracts:**
- `ReadinessPolicy` (new enum) — `Required` / `OptionalReported` / `NotReadinessRelevant`.
- `HealthCheckResponse` (new record) — IETF `health+json` body root.
- `HealthCheckEntry` (new record) — per-contributor entry inside `checks`.
- Contributor-registration shape (signature TBD by existing Kernel conventions; documented in the PR).
