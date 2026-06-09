# Node Audit: HoneyDrunk.Kernel

**Auditor:** node-audit agent
**Date:** 2026-06-09
**Verdict:** At Risk

## Recommendation Breakdown

- **Architecture catalogs still advertise Kernel 0.7.0 while the repo is 0.8.0**
  - Recommendation: promote
  - Why: Kernel is the root dependency for the Grid. Architecture `repos/HoneyDrunk.Kernel/overview.md` and `catalogs/compatibility.json` still identify the Node as `0.7.0`, while both shipped Kernel projects set `<Version>0.8.0</Version>`. This misleads downstream compatibility and release planning.
  - Proposed packet path: `generated/issue-packets/proposed/2026-06-09-architecture-reconcile-kernel-080-catalog-drift.md`
  - Human action: Review and promote the Architecture reconciliation packet if Kernel `0.8.0` is the intended current source of truth.
  - Urgency: high
  - Dedupe/Skipped reason: _None._
- **Kernel.Abstractions carries a non-permitted third-party runtime dependency**
  - Recommendation: promote
  - Why: `HoneyDrunk.Kernel.Abstractions.csproj` directly references `Ulid` 1.4.1, and public identity types expose `Ulid` members. Grid invariant 1 and the Kernel repo invariant require Abstractions packages to remain dependency-light and limited to permitted abstractions.
  - Proposed packet path: `generated/issue-packets/proposed/2026-06-09-kernel-remove-ulid-abstractions-dependency.md`
  - Human action: Review whether to promote the Kernel contract-cleanup packet; this is a breaking pre-1.0 contract cleanup and should be treated as a focused Kernel release.
  - Urgency: high
  - Dedupe/Skipped reason: _None._
- **Repository-level changelog does not have a released 0.8.0 heading**
  - Recommendation: promote
  - Why: The package changelogs contain `## [0.8.0] - 2026-05-26`, but the repo-level changelog keeps those release notes under `## [Unreleased]` with `Changed (breaking - v0.8.0)`. Invariant 12 makes the repo-level changelog the source for release notes and requires every shipped version to have an entry.
  - Proposed packet path: `generated/issue-packets/proposed/2026-06-09-kernel-add-repo-changelog-080-entry.md`
  - Human action: Promote the small Kernel docs/release-hygiene packet if no existing Kernel PR already corrects the changelog on origin.
  - Urgency: normal
  - Dedupe/Skipped reason: _None._

## Identity and Intent

HoneyDrunk.Kernel is the Core-sector root Node. Per `repos/HoneyDrunk.Kernel/overview.md`, it owns the semantic OS primitives for the Grid: context propagation, lifecycle orchestration, configuration scoping, identity primitives, and telemetry hooks. Per `repos/HoneyDrunk.Kernel/boundaries.md`, Kernel owns the three-tier Grid/Node/Operation context model, lifecycle, identity grammar, telemetry hooks, service discovery primitives, and tenancy seams, while explicitly not owning transport, secrets, HTTP response shaping, data access, authentication, telemetry backends, or business logic. `catalogs/relationships.json` lists Kernel as consumed by Transport, Vault, Auth, Web.Rest, Data, Notify, Pulse, and Communications, with planned consumers across AI, Audit, and Observe. Its blast radius is therefore Grid-wide.

## Drift from Definition

- **Blocking - Version source-of-truth drift:** Architecture still declares Kernel as `0.7.0` in `repos/HoneyDrunk.Kernel/overview.md` and `catalogs/compatibility.json`, but the local Kernel repo sets both `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` to `0.8.0` in their `.csproj` files. The repo-level `CHANGELOG.md` also describes `v0.8.0` release content. Because Kernel is the root package, this is downstream-misleading catalog drift.
- Source layout matches the definition: runtime and Abstractions projects exist, tests are present, docs and samples are present, and CI workflows are wired.
- The local Kernel checkout reports `main...origin/main [behind 5]`. This audit used the local on-disk repo per the scheduled job prompt; the version findings are still reproducible in that checkout.

## Boundary Overlap

- **Blocking - Abstractions dependency hygiene:** `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` directly references `Ulid` 1.4.1. `dotnet list ... package --include-transitive` confirms `Ulid` as a top-level dependency. Identity primitives and `GridContextSnapshot` use and expose `Ulid` in the Abstractions package. This conflicts with Grid invariant 1 and Kernel invariant 1, which keep Abstractions packages constrained to permitted abstractions. The identity grammar itself belongs in Kernel; the third-party package dependency leaking into the contracts package is the boundary defect.
- No evidence found that Kernel implements Transport, Vault, Auth, Data, Web.Rest, or Pulse responsibilities. The runtime package has ASP.NET Core framework usage for context middleware and health integration, which is consistent with the documented Kernel context-entry role.

## Producer Quality

- Kernel is heavily consumed and exposes declared contracts in `catalogs/contracts.json`: `IGridContext`, `IGridContextAccessor`, `INodeContext`, `IOperationContext`, lifecycle hooks, health/readiness contributors, telemetry interfaces, agent context, and identity primitives.
- Public API XML documentation is enabled for both runtime and Abstractions packages.
- **Changes Requested - Release-note source drift:** Package-level changelogs contain `0.8.0` entries, but the repository-level changelog keeps the `0.8.0` release notes under `Unreleased`. Invariant 12 identifies the repo-level changelog as mandatory and the release-notes source of truth.
- The contract surface has active upcoming packets in Architecture for health endpoints, rate limiting, and money/currency, so future Kernel contract growth should be checked against existing active work before implementation.

## Consumer Quality

- Kernel is the root Node and has no upstream HoneyDrunk dependencies in `catalogs/relationships.json`.
- `HoneyDrunk.Kernel` references `HoneyDrunk.Kernel.Abstractions` and allowed Microsoft.Extensions packages plus the same `Ulid` package used by Abstractions. The runtime dependency is less concerning than the Abstractions dependency because runtime packages may carry implementation dependencies.
- `HoneyDrunk.Kernel.Abstractions` references `HoneyDrunk.Standards` as analyzer/build tooling with `PrivateAssets=all`; this does not appear to be a runtime dependency leak.

## Job Performance

- Local verification passed: `dotnet test HoneyDrunk.Kernel/HoneyDrunk.Kernel.slnx --configuration Release --no-restore` reported 941 passed, 0 failed, 0 skipped.
- PR, publish, nightly security, weekly dependency, SonarQube Cloud, coverage ratchet, and Grid Review workflows are present.
- The committed coverage baseline is 70.9% and the PR workflow sets an absolute coverage floor of 70 with a patch coverage threshold of 75.
- The root package changelog issue is the main release-hygiene defect observed.

## Cross-Cutting Health

- Secret scanning is enabled in both PR and nightly security workflows. No committed secret value was identified during this audit.
- Test code scan found no `Thread.Sleep` usage in tracked source files.
- The repo includes `.honeydrunk-review.yaml` with `enabled: true`, satisfying the review-agent enablement posture.
- The local checkout being five commits behind origin should be resolved by the runner checkout process for future audits, but this is not a Kernel repo defect by itself and no packet was created.

## Findings Summary

### Blocking

- **Phase 2 - Version drift:** Architecture advertises Kernel `0.7.0` while the repo packages are `0.8.0`. Update Architecture context and compatibility metadata.
- **Phase 3 - Abstractions dependency hygiene:** `HoneyDrunk.Kernel.Abstractions` carries a top-level `Ulid` package dependency and exposes `Ulid` in public identity APIs. Remove or otherwise reconcile the dependency against the Abstractions invariant.

### Changes Requested

- **Phase 6 - Changelog discipline:** Root `HoneyDrunk.Kernel/CHANGELOG.md` does not contain a released `## [0.8.0] - 2026-05-26` entry even though package changelogs and `.csproj` versions indicate `0.8.0` shipped.

### Suggestions

- **Phase 7 - Audit freshness:** Future scheduled audits should start from an up-to-date target-repo checkout. The local Kernel repo is behind `origin/main` by five commits.

## Recommended Handoffs

1. **Reconcile Kernel 0.8.0 Architecture drift** -> `scope` for Architecture packet review and promotion.
2. **Remove `Ulid` from Kernel.Abstractions dependency closure** -> `scope` for Kernel packet review and promotion; subsequent review should treat the PR as a contract-shape change.
3. **Add root changelog 0.8.0 entry** -> `scope` for small Kernel release-hygiene packet review and promotion.

## Checklist

- [x] Architecture context fully loaded
- [x] Repo walked on disk
- [x] Drift from definition
- [x] Boundary overlap
- [x] Producer quality
- [x] Consumer quality
- [x] Job performance
- [x] Cross-cutting health
