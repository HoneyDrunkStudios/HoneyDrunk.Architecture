---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0066", "wave-5"]
dependencies: ["packet:06"]
adrs: ["ADR-0066"]
wave: 5
initiative: adr-0066-health-endpoints
node: honeydrunk-notify
---

# Amend Notify contributors to implement IHealthContributor directly; remove INotifyHealthContributor

## Summary
Amend every Notify-private `INotifyHealthContributor` implementation to implement `IHealthContributor` from `HoneyDrunk.Kernel.Abstractions.Lifecycle` directly; remove `NotifyHealthContributorAdapter`, `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, and `NotifyHealthStatus` from `HoneyDrunk.Notify.Hosting.AspNetCore`. Closes ADR-0066 D9's reconciliation: after this packet there is no Notify-private health interface; every Notify contributor implements the Kernel-shaped `IHealthContributor` directly. This is a **breaking change** in the public API surface of `HoneyDrunk.Notify.Hosting.AspNetCore` (removing `INotifyHealthContributor` is a major API removal) — but ADR-0066 Operational Consequences names the bridge in packet 06 as the accommodation that prevents the *aggregate* Notify CHANGELOG from being a breaking event. This packet bumps the Notify solution one minor version (per the additive-removal-by-`[Obsolete]` pattern in ADR-0035 — `[Obsolete]` was applied in packet 06; removal one minor later is the standard deprecation cycle).

## Context
ADR-0066 D9 names the three-stage Notify reconciliation:
1. Bridge adapter lands (packet 06 — done).
2. Notify contributors amend to `IHealthContributor` directly (this packet).
3. `INotifyHealthContributor` is removed (this packet).

Stages 2 and 3 are bundled because once existing contributors implement `IHealthContributor` directly, the adapter has no remaining purpose and the Notify-private interface has no remaining implementations — removing both together keeps Notify's surface clean and avoids a partial-removal state. The deprecation window between packet 06's `[Obsolete]` and this packet's removal is the standard ADR-0035 60-day window (or whatever shorter window the operator decides; ADR-0035 D5 names 60 days as the minimum for member removals — for an internal-only Notify type that has no external consumers documented, a tighter window is acceptable if the operator decides so. Document the window choice in the PR.).

Notify's existing contributors (audited at packet 06 time):
- `DefaultNotifyHealthContributor` in `HoneyDrunk.Notify.Hosting.AspNetCore/Health/`.
- Possibly more inside `HoneyDrunk.Notify.Worker` / `HoneyDrunk.Notify.HostBootstrap` (audit at execution time).

Per the existing `DefaultNotifyHealthContributor` shape: it implements `INotifyHealthContributor.CheckAsync` returning `Task<NotifyHealthReport>`. After this packet it implements `IHealthContributor.CheckHealthAsync` returning `Task<(HealthStatus, string?)>`, plus the three properties (`Name`, `Priority`, `IsCritical`) that `IHealthContributor` exposes. The mapping is the same the adapter performed in packet 06; the contributor now does it directly.

This packet is the **second packet on the `HoneyDrunk.Notify` solution in this initiative**. Per invariant 27 it bumps the whole solution to the next minor version above what packet 06 set (a removal is a minor-bump-with-`[Obsolete]`-removal-window in the ADR-0035 model). The repo-level `CHANGELOG.md` gets a new minor-version entry; per-package CHANGELOG entries note: "Removed: `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `NotifyHealthContributorAdapter`. All Notify health contributors now implement `IHealthContributor` directly."

## Scope
- Every `INotifyHealthContributor` implementation in the Notify repo — amended to implement `IHealthContributor` directly. Map `Task<NotifyHealthReport> CheckAsync(...)` → `Task<(HealthStatus, string?)> CheckHealthAsync(...)`. Add `Name`, `Priority`, `IsCritical` properties (likely already implicitly present via constructor parameters in some form; explicit now).
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/` — remove `INotifyHealthContributor.cs`, `NotifyHealthEvaluator.cs`, `NotifyHealthReport.cs`, `NotifyHealthStatus.cs`, `NotifyHealthContributorAdapter.cs`.
- `HoneyDrunk.Notify.Hosting.AspNetCore/ServiceCollectionExtensions/HoneyDrunkNotifyServiceCollectionExtensions.cs` — drop the adapter-wrapping registration; register contributors directly as `IHealthContributor` with `ReadinessPolicy` values (the policies stay the same as packet 06 chose; document any change in the PR).
- Notify tests — remove tests targeting the removed types; amend tests that exercised contributors through the Notify-private surface to exercise them through the Kernel-shaped surface.
- Version bump across the `HoneyDrunk.Notify` solution (invariant 27).

## Proposed Implementation
1. **Audit.** Enumerate every `INotifyHealthContributor` implementation in the Notify repo. State the list in the PR. (Expected at minimum: `DefaultNotifyHealthContributor`; possibly more.)
2. **Amend each contributor.** For each implementation:
   - Change the class declaration: `: INotifyHealthContributor` → `: IHealthContributor`.
   - Add (or expose) `Name`, `Priority`, `IsCritical` per the `IHealthContributor` contract. If the existing contributor was registered with these values externally (e.g. via constructor injection or DI registration data), surface them on the class directly.
   - Rename `Task<NotifyHealthReport> CheckAsync(...)` → `Task<(HealthStatus status, string? message)> CheckHealthAsync(...)`.
   - Map the existing body's `NotifyHealthStatus` results to `HealthStatus` results (same mapping the adapter performed in packet 06: `Healthy`→`Healthy`, `Degraded`→`Degraded`, `Unhealthy`→`Unhealthy`).
   - The contributor's message string still must obey Invariant `{N3}` (no secrets, connection strings, tenant identifiers, or provider opaque IDs). Re-audit each contributor's message strings during the rewrite.
3. **Remove the Notify-private surface.** Delete:
   - `HoneyDrunk.Notify.Hosting.AspNetCore/Health/INotifyHealthContributor.cs`
   - `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthEvaluator.cs`
   - `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthReport.cs`
   - `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthStatus.cs`
   - `HoneyDrunk.Notify.Hosting.AspNetCore/Health/NotifyHealthContributorAdapter.cs` (the bridge from packet 06, no longer needed).
4. **Amend the host composition.** In `HoneyDrunkNotifyServiceCollectionExtensions` (or wherever contributor registration lives), drop the adapter-wrapping registration calls. Register each contributor directly as `IHealthContributor` with its `ReadinessPolicy`. The policies stay the same as packet 06 chose unless audit reveals a needed change — document any change in the PR.
5. **Tests.** Remove tests targeting the removed types. Amend tests that previously exercised contributors via the Notify-private surface to exercise them via `IHealthContributor`. Confirm endpoint contract tests (from packet 06) still pass — they should, since the endpoints already go through the Kernel aggregator and the adapter was the only thing between the contributors and the aggregator.
6. **Versioning.** Bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution to the next minor version in one commit (invariant 27). The bump reflects: (a) removal of public API (`INotifyHealthContributor` and friends — major-bump-with-deprecation-window per ADR-0035, mitigated by the `[Obsolete]` warning from packet 06; treat as minor bump under ADR-0035's "removal after `[Obsolete]` deprecation window" allowance), and (b) the visible behavioural completion of the reconciliation.
7. **CHANGELOG and README.**
   - Repo-level `CHANGELOG.md` new-version entry naming the removal: "`INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `NotifyHealthContributorAdapter` removed. Notify health contributors now implement `IHealthContributor` directly."
   - `HoneyDrunk.Notify.Hosting.AspNetCore/CHANGELOG.md` (or per-package equivalent) — same removal note.
   - `HoneyDrunk.Notify.Hosting.AspNetCore/README.md` — if the README documented `INotifyHealthContributor` as a public extension point, remove that documentation and replace with the now-canonical `IHealthContributor` guidance (cross-link to `HoneyDrunk.Kernel/docs/Health.md` from packet 04).

## Affected Files
- Each Notify `INotifyHealthContributor` implementation — class declaration, method signatures, body amendments.
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/` — five file removals.
- `HoneyDrunk.Notify.Hosting.AspNetCore/ServiceCollectionExtensions/HoneyDrunkNotifyServiceCollectionExtensions.cs` — registration changes.
- Notify test projects — test removals and amendments.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`; `HoneyDrunk.Notify.Hosting.AspNetCore` per-package CHANGELOG.
- `HoneyDrunk.Notify.Hosting.AspNetCore/README.md` (if affected).

## NuGet Dependencies
- No new `PackageReference`. The dependencies on `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 06 stay; versions may move forward to the latest released Kernel `0.8.x` if a patch has shipped, otherwise unchanged.
- `HoneyDrunk.Standards` is already on every project; no change.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — its own contributors, host composition, and tests. Routing rule maps here.
- [x] No contract change in Notify's hot path — `INotificationSender` / `INotificationGateway` shapes are not touched.
- [x] Removing `INotifyHealthContributor` is a Notify-internal API removal; the Kernel-shaped `IHealthContributor` is the canonical surface and remains stable.
- [x] No Container App YAML change; no deploy-workflow change in this packet.

## Acceptance Criteria
- [ ] Every Notify `INotifyHealthContributor` implementation now implements `IHealthContributor` from `HoneyDrunk.Kernel.Abstractions.Lifecycle` directly
- [ ] `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `NotifyHealthContributorAdapter` source files are removed from `HoneyDrunk.Notify.Hosting.AspNetCore`
- [ ] Host composition registers contributors directly as `IHealthContributor` with `ReadinessPolicy` values; the chosen policies match packet 06 unless documented otherwise in the PR
- [ ] Existing endpoint contract tests (from packet 06) continue to pass — the three endpoints still behave per ADR-0066 D2 contract
- [ ] Contributor `output` strings continue to obey Invariant `{N3}` (no secrets, connection strings, tenant identifiers, or provider opaque IDs) — re-audited during the rewrite
- [ ] Every non-test `.csproj` in the `HoneyDrunk.Notify` solution is at the next minor version above what packet 06 set, in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries a new-version entry naming the removed types and the reconciliation closure
- [ ] `HoneyDrunk.Notify.Hosting.AspNetCore` per-package `CHANGELOG.md` carries the same removal note
- [ ] `HoneyDrunk.Notify.Hosting.AspNetCore/README.md` updated if it previously documented `INotifyHealthContributor` as a public extension point
- [ ] No `Thread.Sleep` in tests (invariant 51)
- [ ] `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Confirm the deprecation window between packet 06's `[Obsolete]` marking and this removal.** ADR-0035 D5 names 60 days as the minimum for member removals. For an internal-Notify type with no documented external consumers, a tighter window is acceptable if the operator decides so. Document the chosen window in the PR description. If a 60-day minimum is honoured, do not file this packet earlier than 60 days after packet 06 merges; if a tighter window is chosen, justify it.

## Referenced ADR Decisions
**ADR-0066 D9 — Notify reconciliation.** Three-stage: bridge adapter, contributor amendments, interface removal. This packet closes stages 2 and 3.

**ADR-0066 Operational Consequences — "The Notify amendment requires care."** "The amendment packet stages: (1) bridge adapter lands, (2) Notify contributors amend to `IHealthContributor` directly, (3) `INotifyHealthContributor` is removed. The bridge keeps Notify's CHANGELOG entry from being a breaking event." Stages (2) + (3) are bundled in this packet; stage (1) was packet 06.

**ADR-0035 — Deprecation window.** Member removals after a 60-day `[Obsolete]` deprecation window are allowed at minor-bump cadence. Packet 06 marked the Notify-private types `[Obsolete]`; this packet removes them.

## Constraints
- **Invariant 4 — DAG.** Notify depends on Kernel; no inversion.
- **Invariants 41–43 — Notify hot-path contracts.** Do NOT change `INotificationSender`, `INotificationGateway`, decision-log or cadence shapes. This packet only finalizes the health-contributor reconciliation.
- **Invariant 13 — XML documentation on public types.** Contributor classes are public; their `IHealthContributor` member implementations carry XML documentation.
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together; per-package CHANGELOG only for packages with functional changes.
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **Invariant `{N3}` — contributor messages free of secrets/connection strings/tenant identifiers/provider opaque IDs.** Re-audit each contributor's message strings during the rewrite.
- **ADR-0035 deprecation window.** Honour at least 60 days between packet 06's `[Obsolete]` marking and this packet's removal, OR document the chosen tighter window in the PR.

## Labels
`feature`, `tier-2`, `ops`, `adr-0066`, `wave-5`

## Agent Handoff

**Objective:** Amend every Notify `INotifyHealthContributor` implementation to implement `IHealthContributor` directly, then remove the Notify-private health surface (the interface, the evaluator, the report, the status enum, and the bridge adapter).

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Close ADR-0066 D9's reconciliation — no Notify-private health interface; the Kernel-shaped contract is the only surface.
- Feature: ADR-0066 Health, Readiness, and Liveness Endpoint Contract rollout, Wave 5 (final wave).
- ADRs: ADR-0066 D9 (primary), ADR-0035 (deprecation window), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:06` — the bridge adapter, the `[Obsolete]` marking, and the host registration via the adapter were introduced. The deprecation window between packet 06 and this packet is honoured (default 60 days per ADR-0035 minimum, or document a tighter window in the PR).

**Constraints:**
- Bundle stages (2) + (3) of the Notify reconciliation in this packet — partial states (contributors amended but interface not removed, or vice versa) are explicitly excluded by the bundling.
- No change to Notify hot-path contracts.
- Re-audit each contributor's message strings against Invariant `{N3}` during the rewrite.
- Bump the whole Notify solution one minor version (invariant 27).

**Key Files:**
- Each Notify `INotifyHealthContributor` implementation (audit at execution time; at minimum `DefaultNotifyHealthContributor`).
- `HoneyDrunk.Notify.Hosting.AspNetCore/Health/` (five file removals).
- `HoneyDrunk.Notify.Hosting.AspNetCore/ServiceCollectionExtensions/HoneyDrunkNotifyServiceCollectionExtensions.cs` (registration changes).
- Notify test projects.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:**
- Removed: `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `NotifyHealthContributorAdapter` (all in `HoneyDrunk.Notify.Hosting.AspNetCore`).
- Consumed: `IHealthContributor`, `ReadinessPolicy` from `HoneyDrunk.Kernel.Abstractions` `0.8.0+`.
- Notify hot-path contracts unchanged.
