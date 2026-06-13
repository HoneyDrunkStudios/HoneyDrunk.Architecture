---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0047", "wave-1"]
dependencies: []
adrs: ["ADR-0047", "ADR-0011"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-architecture
---

# Accept ADR-0047 — flip status, close ADR-0011 Gap 1 and Gap 3, register the testing-patterns initiative

## Summary
Flip ADR-0047 (Testing Patterns and Tooling) from Proposed to Accepted: update the ADR header, update the ADR index, record in ADR-0011 that ADR-0047 D12 closes its Gap 1 (integration tests) and Gap 3 (E2E tests), and register the `adr-0047-testing-patterns-and-tooling` initiative in the tracking files.

## Context
ADR-0047 is priority #2 on `initiatives/current-focus.md` (type: `adr-acceptance + packet`). Every other packet in this initiative references ADR-0047's D-decisions as live rules — the unit-test stack, the per-tier coverage thresholds, the two integration tiers, the four new reusable workflows. The acceptance flip must land first so those references read against Accepted text rather than Proposed text.

The Invariant 15 amendment and the two new testing invariants (numbers 50 and 51) are **already landed** in `constitution/invariants.md` (commit 120f39d) — this packet does **not** touch `constitution/invariants.md`. It only flips the ADR, updates the index, records the ADR-0011 gap closures, and registers the initiative.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0047-testing-patterns-and-tooling.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- The ADR index (`adrs/README.md` or equivalent index file) — update the ADR-0047 row to Accepted.
- `adrs/ADR-0011-code-review-and-merge-flow.md` — append an "Amended by ADR-0047" note recording that ADR-0047 D12 closes Gap 1 (integration tests) and Gap 3 (E2E tests). Do not change ADR-0011's Status; Gaps 2, 4, 5 remain ADR-0011's responsibility and are explicitly untouched.
- `initiatives/active-initiatives.md` — register the `adr-0047-testing-patterns-and-tooling` initiative with the packet checklist for this folder.
- `constitution/invariants.md` — **no change.** Invariants 50, 51 and the Invariant 15 amendment already landed in commit 120f39d. If the implementing agent finds those still carry a "(Proposed)" qualifier, strip the qualifier as the only permitted edit; otherwise leave the file alone.

## Proposed Implementation
1. Edit the ADR-0047 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR index row for ADR-0047 to Accepted.
3. Append to ADR-0011 a short "Amended by ADR-0047" section recording the Gap 1 / Gap 3 closures, mirroring how other ADRs record cross-ADR amendments. Quote ADR-0047 D12 verbatim intent: "D4 commits the WebApplicationFactory + Testcontainers split; D11 commits the CI jobs" (Gap 1); "D5 commits Playwright (.NET binding); D6 commits Maestro for mobile; D11 commits the CI jobs" (Gap 3).
4. Register the initiative in `initiatives/active-initiatives.md` with the six-wave structure (Phases 1-6 per ADR-0047 D14) and the packet checklist.
5. Strip any "(Proposed)" qualifier on invariants 50/51 in `constitution/invariants.md` only if one is still present — otherwise no edit.

## Affected Files
- `adrs/ADR-0047-testing-patterns-and-tooling.md`
- `adrs/README.md` (or the ADR index file in use)
- `adrs/ADR-0011-code-review-and-merge-flow.md`
- `initiatives/active-initiatives.md`
- `constitution/invariants.md` (qualifier-strip only, conditional)

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0047 header reads `**Status:** Accepted`
- [ ] ADR index row for ADR-0047 reflects Accepted
- [ ] ADR-0011 carries an "Amended by ADR-0047" note recording the Gap 1 and Gap 3 closures; ADR-0011's own Status is unchanged; Gaps 2, 4, 5 are explicitly noted as still open
- [ ] `initiatives/active-initiatives.md` registers the `adr-0047-testing-patterns-and-tooling` initiative with a six-wave packet checklist
- [ ] `constitution/invariants.md` is either unchanged or has only a "(Proposed)" qualifier removed from invariants 50/51 — no other edit
- [ ] No catalog schema change in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D12 — Closes ADR-0011 Gap 1 and Gap 3.** Gap 1 (integration tests): D4 commits the WebApplicationFactory + Testcontainers split, D11 commits the CI jobs. Gap 3 (E2E tests): D5 commits Playwright (.NET binding), D6 commits Maestro for mobile, D11 commits the CI jobs. ADR-0011's Gap 2 (SonarCloud), Gap 4 (quantitative cost discipline), Gap 5 (SonarCloud on private repos) are NOT addressed by ADR-0047 and remain ADR-0011's responsibility.

**ADR-0047 D14 — Phased rollout.** Six discrete go/no-go phases: Phase 1 (unit-test stack + coverage gates), Phase 2 (`job-integration-tests.yml` Tier 2a), Phase 3 (`job-integration-tests-containers.yml` Tier 2b, pilot Data + Kernel), Phase 4 (`job-e2e-web.yml`, pilot Studios), Phase 5 (`job-e2e-mobile.yml`, when first mobile app ships), Phase 6 (BenchmarkDotNet + Azure Load Testing, ongoing).

## Constraints
- **Acceptance precedes flip.** ADR-0047 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not edit `constitution/invariants.md` beyond a conditional qualifier-strip.** Invariants 50/51 and the Invariant 15 amendment already landed; re-adding or renumbering them is forbidden.
- **Do not change ADR-0011's Status.** ADR-0011 is itself still Proposed; ADR-0047 amends it but does not accept it.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0047 to Accepted, record the ADR-0011 Gap 1 / Gap 3 closures, and register the testing-patterns initiative in the trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0047 so the testing-patterns build packets can reference its decisions as live rules.
- Feature: ADR-0047 Testing Patterns and Tooling rollout, Phase 1.
- ADRs: ADR-0047 (primary), ADR-0011 (amended — Gap 1 / Gap 3 closed), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0047 stays Proposed until this PR merges.
- Do not edit `constitution/invariants.md` beyond a conditional "(Proposed)" qualifier-strip on invariants 50/51 — those already landed in commit 120f39d.
- Do not change ADR-0011's Status.

**Key Files:**
- `adrs/ADR-0047-testing-patterns-and-tooling.md`
- `adrs/README.md`
- `adrs/ADR-0011-code-review-and-merge-flow.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
