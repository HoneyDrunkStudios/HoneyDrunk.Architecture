---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0047", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0047", "ADR-0036", "ADR-0032"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-standards
---

# Author shared `coverlet.runsettings` templates encoding the D3 per-tier coverage thresholds

## Summary
Create the shared `coverlet.runsettings` template set in `HoneyDrunk.Standards` — one per Node tier (Tier 0, Tier 1, Tier 2, Untiered per ADR-0047 D3 / ADR-0036 DR tiers) — so each Node drops the matching `coverlet.runsettings` at its repo root and the CI coverage gate (per ADR-0011 D2 tier 1 / ADR-0032) reads a single canonical threshold definition instead of per-repo drift.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0047 D3 sets specific per-tier line and branch coverage numbers and states "Coverage thresholds are configured per-project in `coverlet.runsettings` files at the Node root." ADR-0032's PR Validation Policy already mandates a coverage gate; ADR-0047 D3 supplies the numbers. The numbers map to the ADR-0036 DR tiers. Authoring one canonical template per tier in `HoneyDrunk.Standards` (the existing home of shared build tooling, packet 01) means a Node's adoption is "copy the Tier-N template to the repo root" rather than "hand-author thresholds and risk a typo on a hard CI gate."

This packet authors the templates only. Per-Node adoption (dropping the file at each repo root and wiring `dotnet test --settings`) happens in the migration packets and in each Node's own future test-hardening work — it is NOT in this packet's scope.

## Proposed Implementation
ADR-0047 D3 — per-Node coverage thresholds:

| Node tier | Line coverage | Branch coverage | Gate behavior |
|-----------|---------------|-----------------|---------------|
| Tier 0 (Vault, Audit, Notify Cloud tenant data) | 85% | 80% | Hard CI gate |
| Tier 1 (Notify, Memory, Knowledge) | 75% | 70% | Hard CI gate |
| Tier 2 (Pulse, Flow, Evals) | 60% | 55% | Warning, not gate |
| Untiered (Architecture, Studios) | none | none | No gate |

Approach:
1. Add four `coverlet.runsettings` templates under `HoneyDrunk.Standards` (path per repo convention, e.g. `runsettings/coverlet.tier0.runsettings` … `coverlet.tier2.runsettings`; Untiered Nodes need no file).
2. Each template configures the coverlet data collector: `Threshold` (line) and `ThresholdType` covering line + branch, the `ThresholdStat` aggregation, and the standard `Exclude` filters for generated code, migrations, and `*.Tests.*` assemblies.
3. Tier 0 / Tier 1 templates set `ThresholdType` so a sub-threshold run fails the test command (hard gate). Tier 2 template emits coverage but does not fail the run (warning posture) — document that the warning-vs-gate distinction is enforced by the CI job, not coverlet itself, if coverlet cannot express "warn only"; in that case the Tier 2 template omits the failing threshold and the CI job logs a `::warning::`.
4. Document the **30-day grace period** (ADR-0047 Consequences): on first adoption per Node the threshold is advisory; the CI job flips it to blocking after the grace window. The templates carry a header comment explaining this and pointing the reader at the CI job that owns the grace-window flip (packet 06, `job-integration-tests.yml` reuses the same coverage-gate logic — note the grace flip is a CI-job concern).
5. Document in the repo `README.md` which template each Node tier uses and how a Node consumes it (`dotnet test --settings coverlet.runsettings`).

**Forward-declared tiers.** The D3 tier table names Nodes that are not yet scaffolded — Notify Cloud (Tier 0), Memory and Knowledge (Tier 1), Flow and Evals (Tier 2). This packet authors the templates for every tier regardless; the templates are tier-keyed, not Node-keyed, so a Node simply copies the template matching its tier when it is stood up. No template is blocked on a Node existing. The README's tier→template mapping should note that the Notify Cloud / Memory / Knowledge / Flow / Evals tier assignments are forward-declared and become live the moment each Node is scaffolded.

## Affected Packages
- `HoneyDrunk.Standards` — gains the `coverlet.runsettings` template set.

## NuGet Dependencies
None new. The `coverlet.collector` package that reads these settings is already declared by the shared test-stack props fragment from packet 01. This packet ships static `.runsettings` content as additional build-asset content in the **same** `HoneyDrunk.Standards` build-assets package that carries packet 01's props fragment — no new `.csproj` and no new analyzer reference. Only if the repo's packaging cannot carry the templates as content should a new build-assets project be added, in which case it references `HoneyDrunk.Standards` analyzers with `PrivateAssets: all` per invariant 26.

## Boundary Check
- [x] Shared build-tooling defaults belong in `HoneyDrunk.Standards` (same rationale as packet 01).
- [x] No Node behavior changes; this packet only publishes definitions.
- [x] Does not duplicate any other Node's responsibility.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards` contains `coverlet.runsettings` templates for Tier 0 (85% line / 80% branch), Tier 1 (75% / 70%), and Tier 2 (60% / 55%); Untiered Nodes have no template by design and the README says so
- [ ] Tier 0 and Tier 1 templates fail the `dotnet test` run on sub-threshold coverage (hard gate)
- [ ] Tier 2 template emits coverage without failing the run; if coverlet cannot express warn-only, the README records that the Tier 2 warning posture is enforced by the CI job
- [ ] Each template excludes generated code, EF migrations, and `*.Tests.*` assemblies from the coverage denominator
- [ ] Each template carries a header comment explaining the 30-day advisory grace period and that the grace-to-blocking flip is owned by the CI coverage gate, not coverlet
- [ ] Repo `README.md` documents the tier→template mapping and the `dotnet test --settings` consumption command
- [ ] Repo-level `CHANGELOG.md` updated — append to the in-progress version entry opened by packet 01 (invariants 12, 27); per-package `CHANGELOG.md` updated for the package that gained the templates
- [ ] Build green; existing `HoneyDrunk.Standards` consumers unaffected

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D3 — Coverage targets per Node tier.** Tier 0 (Vault, Audit, Notify Cloud tenant data): 85% line / 80% branch, hard gate. Tier 1 (Notify, Memory, Knowledge): 75% / 70%, hard gate. Tier 2 (Pulse, Flow, Evals): 60% / 55%, warning not gate. Untiered (Architecture, Studios): no threshold. Thresholds live in per-Node `coverlet.runsettings` at the Node root; the ADR-0011 D2 tier-1 CI gate reads them.

**ADR-0036 — DR tiers.** ADR-0047 D3's Node tiers are aligned to the ADR-0036 disaster-recovery tiers; the coverage numbers track DR cost-of-loss, which is why Tier 0 carries the strictest gate.

**ADR-0032 — PR Validation Policy.** Already mandates a coverage gate exists; ADR-0047 D3 sets the specific per-tier numbers the gate enforces.

**ADR-0047 Consequences — grace period.** "The rollout includes a 30-day grace period during which thresholds are advisory (warning, not gate) so existing Nodes can backfill; after the grace window, the gate flips to blocking."

## Constraints
- **Numbers are exact.** 85/80, 75/70, 60/55 — transcribe ADR-0047 D3 verbatim. A typo on a hard CI gate is a silent quality regression.
- **Do not adopt these templates into any Node in this packet.** Per-Node adoption is separate work.
- **Tier 2 is warn-only.** Do not make the Tier 2 template a hard gate — ADR-0047 D3 explicitly says best-effort, "over-investment in coverage on best-effort Nodes is poor ROI."

## Labels
`feature`, `tier-2`, `ops`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Author the shared `coverlet.runsettings` template set in `HoneyDrunk.Standards` encoding the ADR-0047 D3 per-tier coverage thresholds (Tier 0 85/80 hard, Tier 1 75/70 hard, Tier 2 60/55 warn).

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: One canonical per-tier coverage-threshold definition; eliminate per-Node drift on a hard CI gate.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 1.
- ADRs: ADR-0047 (D3), ADR-0036 (DR tiers feed the numbers), ADR-0032 (coverage gate mandate).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- work-item:01 — the shared test-stack props fragment declares `coverlet.collector`; this packet's templates are consumed alongside it. Sequence after 01.

**Constraints:**
- Transcribe the D3 numbers exactly: 85/80, 75/70, 60/55.
- Tier 2 template is warn-only, never a hard gate.
- Do not adopt the templates into any Node here — templates only.

**Key Files:**
- New `coverlet.runsettings` templates under `HoneyDrunk.Standards` (path per repo convention).
- `README.md` — tier→template mapping and consumption docs.
- `CHANGELOG.md` (repo-level + per-package).

**Contracts:** None — build tooling, not a runtime contract.
