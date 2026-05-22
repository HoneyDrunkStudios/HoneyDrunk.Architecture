---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repos: []
labels: ["chore", "tier-2", "coordination", "adr-0047", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-architecture
---

# Migrate every Node's test projects from FluentAssertions to AwesomeAssertions

## Summary
Replace the `FluentAssertions` package reference with `AwesomeAssertions` (the MIT-licensed community fork of the FluentAssertions v7 API) across every Node repo's test projects, and remove any local FluentAssertions declaration in favor of the shared test-stack props fragment from packet 01. The migration is drop-in for v7-compatible assertion code per ADR-0047 D2.

## Affected Repos (one issue per repo at filing time)
Every Node repo that currently references FluentAssertions in a test project. The `file-issues` agent fans this packet out per-repo at filing time; the candidate set is every .NET Node in `catalogs/nodes.json` with existing test projects — Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Actions (its .NET test projects, if any), and HoneyDrunk.Standards itself. A repo with zero FluentAssertions usages is a no-op and that per-repo issue is closed immediately.

## Motivation
ADR-0047 D2: "AwesomeAssertions as the assertion library. Not FluentAssertions — FluentAssertions v8 (October 2024) moved to a paid commercial license, and the Studio is technically a commercial entity. AwesomeAssertions is the community MIT-licensed fork of FluentAssertions v7, drop-in compatible with the v7 API." The ADR Consequences name "Migrate existing FluentAssertions usages to AwesomeAssertions across all Node repos (Phase 1)" as explicit follow-up. This is the cheap, mechanical half of the Phase 1 library migration (the Moq→NSubstitute migration, packet 05, is the heavier, per-Node lift).

## Change Plan
Per repo:
1. Remove every `<PackageReference Include="FluentAssertions" ... />` from `*.Tests.*` `.csproj` files.
2. Adopt the shared test-stack props fragment from packet 01 (which already declares `AwesomeAssertions`), OR — if the repo is not yet ready to adopt the full fragment — add `<PackageReference Include="AwesomeAssertions" ... />` directly. Prefer adopting the fragment; note in the PR which path was taken.
3. Update `using FluentAssertions;` directives to `using AwesomeAssertions;` (the namespace differs; the API surface does not for v7-compatible code).
4. Build and run the full test suite — AwesomeAssertions is drop-in for the v7 API, so no assertion rewrites are expected. If a test references a FluentAssertions v8-only API, flag it in the PR (rare; the Grid was on v7-compatible usage per the ADR's "drop-in" framing).
5. Confirm no `FluentAssertions` reference remains anywhere in the repo.

## Contracts Affected
None. Assertion-library choice is test-internal; no runtime contract, no `catalogs/contracts.json` change.

## NuGet Dependencies
Per affected test project:
- **Remove:** `FluentAssertions`.
- **Add (or inherit from packet-01 fragment):** `AwesomeAssertions` — current stable, the MIT fork of FluentAssertions v7.
No runtime `.csproj` is touched (test projects only — invariant 16). No new project is created, so no new `HoneyDrunk.Standards` analyzer reference is required.

## Cascade Validation
- [ ] No runtime package version bump — this is test-project-only; per invariant 27 test projects are excluded from the solution version, so no solution-wide version move is triggered by this packet.
- [ ] No circular dependency introduced (assertion library is a leaf test dependency).
- [ ] Canary projects unaffected unless a canary uses FluentAssertions — if so, migrate it too.

## Acceptance Criteria
- [ ] No `FluentAssertions` `PackageReference` remains in any test project in the repo
- [ ] `AwesomeAssertions` is referenced (preferably inherited from the packet-01 test-stack props fragment)
- [ ] All `using FluentAssertions;` directives updated to `using AwesomeAssertions;`
- [ ] Full test suite builds and passes — no assertion behavior change expected (drop-in v7 API)
- [ ] Any FluentAssertions v8-only API encountered is flagged in the PR body (expected: none)
- [ ] Repo-level `CHANGELOG.md`: a line under the in-progress version entry noting the test-tooling migration (invariant 12) — this is a test-only change so no runtime version bump; record it as a tooling/chore entry
- [ ] No per-package `CHANGELOG.md` change for runtime packages (no runtime change); no README change (no public API or installation change)
- [ ] CI green

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D2 — AwesomeAssertions, not FluentAssertions.** FluentAssertions v8 (October 2024) moved to a paid commercial license. AwesomeAssertions is the MIT community fork of the v7 API, drop-in compatible. ADR Consequences: "API is drop-in for v7-compatible code; mechanical change, low risk. One-time effort per Node."

## Constraints
- **Test projects only.** Do not touch runtime `.csproj` files (invariant 16).
- **No solution version bump.** Test projects are excluded from the solution version (invariant 27); this migration does not trigger a release.
- **Prefer adopting the packet-01 props fragment** over a local `AwesomeAssertions` reference — that is the whole point of centralizing the stack. Note the chosen path in the PR.
- **Drop-in expectation.** If a migration requires non-trivial assertion rewrites, stop and flag — that signals FluentAssertions v8-only API usage and needs a human decision.

## Labels
`chore`, `tier-2`, `coordination`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Replace FluentAssertions with AwesomeAssertions across the target repo's test projects; remove the local FluentAssertions reference; adopt the packet-01 shared test-stack props fragment where possible.

**Target:** The per-repo target assigned at filing time (one issue per Node repo with FluentAssertions usage), branch from `main`.

**Context:**
- Goal: Move off the now-commercially-licensed FluentAssertions to the MIT fork; converge on the shared test stack.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 1.
- ADRs: ADR-0047 (D2).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment declares `AwesomeAssertions`. Sequence after 01 so the fragment exists to adopt.

**Constraints:**
- Test projects only — never touch runtime `.csproj` (invariant 16).
- No solution version bump — test projects are excluded from the solution version (invariant 27).
- Prefer adopting the packet-01 fragment over a local reference.
- If non-trivial assertion rewrites are needed, stop and flag (FluentAssertions v8-only API).

**Key Files:**
- `*.Tests.*` `.csproj` files in the target repo.
- Test source files with `using FluentAssertions;`.
- `CHANGELOG.md` (repo-level — tooling/chore entry).

**Contracts:** None changed.
