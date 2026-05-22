# Dispatch Plan: Testing Patterns and Tooling (ADR-0047)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0047 acceptance).
**Trigger:** ADR-0047 (Testing Patterns and Tooling) — Proposed 2026-05-21; priority #2 on `initiatives/current-focus.md` (type `adr-acceptance + packet`). Scoped now, ahead of formal acceptance, so the packet set is ready the moment the ADR lands.
**Type:** Multi-repo (Architecture, Standards, Actions, Data, Kernel, Studios — plus a per-Node fan-out for the two library migrations).
**Sector:** Meta + cross-cutting (every Node with tests is touched by Wave 1's migrations).
**Site sync required:** No. Testing patterns, coverage thresholds, and CI workflows are not public-facing artifacts on the Studios marketing site. Re-evaluate only if a future "engineering practices" page surfaces the testing pyramid.
**Rollback plan:** Architecture-side edits (packets 00, 07, 08) revert cleanly via `git revert` — ADR flip, template authoring, and the `review.md` checklist edit are docs/text-only. `HoneyDrunk.Standards` packets (01, 02, 03) are additive build-tooling — the props fragment, `coverlet.runsettings` templates, and the analyzer rule have no consumers until a Node adopts them, so reverting has no consumer impact. The four `HoneyDrunk.Actions` workflows (06, 09, 12, 14) are additive reusable workflows; 06 also wires `pr-core.yml` but the job is a no-op in non-opted-in repos, so reverting the wiring is safe. The two library migrations (04, 05) are test-project-only and revert per-repo by restoring the prior `PackageReference` and `using` directives — no runtime change, no release triggered. The pilot packets (10, 11, 13, 15) add test/benchmark projects only — reverting deletes the new project with zero runtime impact.

## Summary

ADR-0047 commits the Grid to a concrete testing stack across the pyramid — xUnit + NSubstitute + AwesomeAssertions + coverlet for units; WebApplicationFactory + Testcontainers for the two integration tiers; Playwright (.NET) for web E2E; Maestro for mobile E2E; AutoFixture + Builders for test data; BenchmarkDotNet + Azure Load Testing for performance. It closes ADR-0011 Gap 1 (integration tests) and Gap 3 (E2E tests), and sets per-tier coverage thresholds aligned to the ADR-0036 DR tiers.

This initiative ships **16 packets** (`00`–`15`) across **six waves**, mapped 1:1 to ADR-0047 D14's six-phase rollout. Each phase is a discrete go/no-go per D14.

**Already complete — not scoped here:** the Invariant 15 amendment and the two new testing invariants (50, 51) already landed in `constitution/invariants.md` (commit 120f39d). ADR-0047's follow-up bullet "Update `constitution/invariants.md` with the two new invariants" is therefore done; no packet covers it.

**Packet 01 (`01-standards-directory-build-props-test-stack.md`)** was authored in a prior scoping pass and is the foundational Wave 1 packet. The remaining 15 packets were authored 2026-05-22.

## Important constraints (from ADR-0047 itself)

- **xUnit v2.x only.** D2 explicitly pins v2.x for consumption stability — v3 is in development, adopt when stable. Every packet that touches the test stack must not adopt xUnit v3.
- **No Moq, no FluentAssertions in new work.** D2 replaces both. Packets 04 and 05 migrate existing usages; after they land, a reintroduction is a regression the `review` agent flags (packet 08).
- **Tier 2b is the scoped exception to invariant 15** — the amended invariant 15 already reflects this. Container-based tests are allowed; the InMemory rule still governs units and Tier 2a.
- **E2E never runs on the PR path.** D1/D5 — E2E is nightly + tag-deploy only, for cost discipline. Packets 12 and 14 are never wired into `pr-core.yml`.
- **Benchmarks are on-demand only.** D9 — never in CI; CI-runner benchmark numbers are meaningless.
- **The 30-day coverage grace period.** D3 / Consequences — Tier 0 / Tier 1 coverage thresholds are advisory for 30 days per Node so existing Nodes can backfill, then flip to blocking. Packet 02 documents this; the CI coverage gate owns the flip.

## Wave Diagram

### Wave 1 — Phase 1: Unit-test stack + migrations + coverage gates (parallel after packet 00)

Run packet 00 first (ADR acceptance). Packet 01 may run in parallel with 00 (it is `HoneyDrunk.Standards`-only and does not depend on the ADR flip, only on the decision). Packets 02, 03 depend on 01. Packets 04, 05 are per-Node fan-outs that depend on 01.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0047** — flip status, update index, record ADR-0011 Gap 1/Gap 3 closure, register the initiative — [`00-architecture-adr-0047-acceptance.md`](00-architecture-adr-0047-acceptance.md)
- [ ] `HoneyDrunk.Standards`: Author the shared unit-test-stack `Directory.Build.props` fragment — [`01-standards-directory-build-props-test-stack.md`](01-standards-directory-build-props-test-stack.md)
  - Blocked by: nothing hard — may run parallel with 00.
- [ ] `HoneyDrunk.Standards`: Author `coverlet.runsettings` templates encoding the D3 per-tier thresholds — [`02-standards-coverlet-runsettings-tier-thresholds.md`](02-standards-coverlet-runsettings-tier-thresholds.md)
  - Blocked by: Wave 1 — `01` (hard — templates ship alongside the props fragment).
- [ ] `HoneyDrunk.Standards`: Add the `Thread.Sleep` analyzer rule for test projects — [`03-standards-thread-sleep-analyzer-rule.md`](03-standards-thread-sleep-analyzer-rule.md)
  - Blocked by: Wave 1 — `01` (hard — the rule ships to test projects via the props fragment).
- [ ] **Per-Node fan-out**: Migrate FluentAssertions → AwesomeAssertions across every Node's test projects — [`04-cross-repo-fluentassertions-to-awesomeassertions-migration.md`](04-cross-repo-fluentassertions-to-awesomeassertions-migration.md)
  - Blocked by: Wave 1 — `01` (hard — adopt the props fragment that declares AwesomeAssertions).
- [ ] **Per-Node fan-out**: Migrate Moq → NSubstitute across every Node's test projects (one independent issue per repo) — [`05-cross-repo-moq-to-nsubstitute-migration.md`](05-cross-repo-moq-to-nsubstitute-migration.md)
  - Blocked by: Wave 1 — `01` (hard). Per ADR-0047 D14 the Moq migration may run in parallel with the rest of Phase 1.

**Wave 1 exit criteria:**
- ADR-0047 reads `**Status:** Accepted`; ADR-0011 carries the Gap 1 / Gap 3 closure note; the initiative is registered in `active-initiatives.md`.
- `HoneyDrunk.Standards` ships the test-stack props fragment, the four `coverlet.runsettings` tier templates, and the `Thread.Sleep` analyzer rule.
- No `Moq` and no `FluentAssertions` `PackageReference` remains in any Node's test projects; all test suites green on NSubstitute + AwesomeAssertions.

### Wave 2 — Phase 2: Tier 2a integration tests (parallel after Wave 1)

- [ ] `HoneyDrunk.Actions`: Author `job-integration-tests.yml` (Tier 2a) and wire it into `pr-core.yml` — [`06-actions-job-integration-tests-workflow.md`](06-actions-job-integration-tests-workflow.md)
  - Blocked by: Wave 1 — `00` (soft, invariant/decision references), `01` (soft — Nodes produce `*.Tests.Integration` projects via the fragment).
- [ ] `HoneyDrunk.Architecture`: Author the integration-test scaffold template for the `scope` agent — [`07-architecture-integration-test-scaffold-template.md`](07-architecture-integration-test-scaffold-template.md)
  - Blocked by: Wave 1 — `00` (soft — the template encodes Accepted decisions).
- [ ] `HoneyDrunk.Architecture`: Update `.claude/agents/review.md` Testing Quality checklist per D13 — [`08-architecture-review-agent-testing-quality-checklist.md`](08-architecture-review-agent-testing-quality-checklist.md)
  - Blocked by: Wave 1 — `00` (soft — the checklist encodes Accepted decisions).

**Wave 2 exit criteria:**
- `job-integration-tests.yml` exists and is wired into `pr-core.yml` as a no-op-safe, auto-discovering tier-2 check.
- The integration-test scaffold template exists under `issues/templates/`.
- `.claude/agents/review.md` enforces the ADR-0047 testing standards on every PR.

### Wave 3 — Phase 3: Tier 2b container-backed integration tests (Data + Kernel pilots)

- [ ] `HoneyDrunk.Actions`: Author `job-integration-tests-containers.yml` (Tier 2b) — [`09-actions-job-integration-tests-containers-workflow.md`](09-actions-job-integration-tests-containers-workflow.md)
  - Blocked by: Wave 2 — `06` (soft — mirrors the Tier 2a workflow pattern).
- [ ] `HoneyDrunk.Data`: Pilot Tier 2b — `HoneyDrunk.Data.Tests.Integration.Containers` with Testcontainers Postgres — [`10-data-tier-2b-testcontainers-postgres-pilot.md`](10-data-tier-2b-testcontainers-postgres-pilot.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 3 — `09` (hard — wires the Tier 2b workflow into Data's CI).
- [ ] `HoneyDrunk.Kernel`: Pilot Tier 2b — `IIdempotencyStore` contract tests across InMemory (2a) + Cosmos (2b) — [`11-kernel-tier-2b-idempotency-store-contract-tests.md`](11-kernel-tier-2b-idempotency-store-contract-tests.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 2 — `07` (soft — uses the scaffold template); Wave 3 — `09` (hard — wires the Tier 2b workflow into Kernel's CI).

**Wave 3 exit criteria:**
- `job-integration-tests-containers.yml` exists (Docker-capable, container-layer caching, no-op-safe).
- `HoneyDrunk.Data` runs a Tier 2b Postgres suite on every PR; `HoneyDrunk.Kernel` runs the `IIdempotencyStore` contract test against both backings, passing identically for both.

### Wave 4 — Phase 4: E2E web (Studios pilot)

- [ ] `HoneyDrunk.Actions`: Author `job-e2e-web.yml` (Playwright .NET) — [`12-actions-job-e2e-web-workflow.md`](12-actions-job-e2e-web-workflow.md)
  - Blocked by: Wave 2 — `06` (soft — mirrors the test-workflow pattern).
- [ ] `HoneyDrunk.Studios`: Pilot E2E web — `HoneyDrunk.Studios.Tests.E2E` with Playwright + nightly schedule — [`13-studios-e2e-web-playwright-pilot.md`](13-studios-e2e-web-playwright-pilot.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 4 — `12` (hard — Studios' caller workflow invokes `job-e2e-web.yml`).

**Wave 4 exit criteria:**
- `job-e2e-web.yml` exists (browser-binary caching, failure-trace retention, never on the PR path).
- `HoneyDrunk.Studios.Tests.E2E` runs nightly against the deployed Studios `dev` site.

### Wave 5 — Phase 5: E2E mobile (PARKED until the first mobile app ships)

- [ ] `HoneyDrunk.Actions`: Author `job-e2e-mobile.yml` (Maestro) — [`14-actions-job-e2e-mobile-workflow.md`](14-actions-job-e2e-mobile-workflow.md)
  - Blocked by: Wave 4 — `12` (soft — mirrors the E2E workflow pattern).
  - **PARKED.** Per ADR-0047 D14 Phase 5 ("zero work until the first mobile app ships"), the `file-issues` agent must **not file this packet as a GitHub Issue** until the mobile-platform ADR lands and the first consumer app (PDR-0003 Lately / PDR-0004 Wayside / PDR-0005–0008) is scaffolded. It stays in `active/` as a parked draft.

### Wave 6 — Phase 6: Performance (ongoing)

- [ ] `HoneyDrunk.Kernel`: Add `HoneyDrunk.Kernel.Tests.Benchmarks` with the BenchmarkDotNet `IIdempotencyStore` lookup baseline — [`15-kernel-benchmarkdotnet-idempotency-store-baseline.md`](15-kernel-benchmarkdotnet-idempotency-store-baseline.md)
  - Blocked by: Wave 1 — `01` (soft); Wave 3 — `11` (soft — targets the same abstraction the Tier 2b contract test covers).

**Wave 6 exit criteria:**
- `HoneyDrunk.Kernel.Tests.Benchmarks` exists with an on-demand `IIdempotencyStore` lookup-latency benchmark and a recorded baseline.

## Out-of-scope items from ADR-0047

- **Azure Load Testing wiring (D9).** ADR-0047 D9 names Azure Load Testing for macro load testing, "as Notify Cloud GA approaches." It has **no forcing function yet** — Notify Cloud GA is gated on ADR-0037 (Proposed) and PDR-0002. No packet here; it is scoped via a future initiative when the Notify Cloud GA work fires. Recorded so the work is not lost.
- **Automated benchmark regression CI (D9).** D9 explicitly names "automated benchmark CI is future work." Packet 15 ships the baseline + manual comparison only.
- **Per-Node BenchmarkDotNet adoption beyond Kernel (D14 Phase 6 "ongoing").** Only the Kernel idempotency benchmark is scoped — it is the one D9 names concretely. Further per-Node benchmarks are filed ad hoc as performance needs surface.
- **Grid-wide Tier 2b wiring beyond the Data/Kernel pilots.** Phase 3 is a pilot per D14; wiring Tier 2b into more Nodes is a follow-up after the pilots prove out.
- **The `*.Tests.Unit` / `*.Tests.Integration` / `*.Tests.E2E` required-tier backfill (invariant 50).** Invariant 50 makes a missing required tier a CI gate failure. This initiative establishes the workflows and the migrations; it does not backfill every Node's missing test tiers. That backfill is per-Node test-hardening work surfaced by the `review` agent (packet 08) and the CI gate, filed as it arises.

## `gh` CLI Commands — File Wave 1–4 + Wave 6 Issues

Paths are relative to the `HoneyDrunk.Architecture` repo root. Wave 5 (packet 14) is **PARKED** and excluded from this batch — file it only when the first mobile app exists. The two migration packets (04, 05) are per-Node fan-outs: the `file-issues` agent expands each into one issue per Node repo with FluentAssertions / Moq usage.

```bash
PACKETS="generated/issue-packets/active/adr-0047-testing-patterns-and-tooling"

# --- Wave 1: Phase 1 — unit-test stack, migrations, coverage gates ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Accept ADR-0047 — flip status, close ADR-0011 Gap 1/Gap 3, register testing initiative" \
  --body-file $PACKETS/00-architecture-adr-0047-acceptance.md \
  --label "chore,tier-3,meta,docs,adr-0047,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Standards \
  --title "Author shared unit-test-stack Directory.Build.props fragment" \
  --body-file $PACKETS/01-standards-directory-build-props-test-stack.md \
  --label "feature,tier-2,ops,adr-0047,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Standards \
  --title "Author coverlet.runsettings templates for the D3 per-tier coverage thresholds" \
  --body-file $PACKETS/02-standards-coverlet-runsettings-tier-thresholds.md \
  --label "feature,tier-2,ops,adr-0047,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Standards \
  --title "Add the Thread.Sleep analyzer rule for test projects" \
  --body-file $PACKETS/03-standards-thread-sleep-analyzer-rule.md \
  --label "feature,tier-2,ops,adr-0047,wave-1"

# Packets 04 and 05 are per-Node fan-outs — file-issues expands each into one
# issue per Node repo (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest,
# Data, Audit, Pulse, Notify, Communications, Actions, Standards). Template:
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.<Node> \
#   --title "Migrate test projects from FluentAssertions to AwesomeAssertions" \
#   --body-file $PACKETS/04-cross-repo-fluentassertions-to-awesomeassertions-migration.md \
#   --label "chore,tier-2,coordination,adr-0047,wave-1"
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.<Node> \
#   --title "Migrate test projects from Moq to NSubstitute" \
#   --body-file $PACKETS/05-cross-repo-moq-to-nsubstitute-migration.md \
#   --label "chore,tier-2,coordination,adr-0047,wave-1"

# --- Wave 2: Phase 2 — Tier 2a integration tests ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author job-integration-tests.yml (Tier 2a) and wire into pr-core.yml" \
  --body-file $PACKETS/06-actions-job-integration-tests-workflow.md \
  --label "feature,tier-2,ci-cd,ops,adr-0047,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Author the integration-test scaffold template for the scope agent" \
  --body-file $PACKETS/07-architecture-integration-test-scaffold-template.md \
  --label "chore,tier-3,meta,docs,adr-0047,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Update review.md Testing Quality checklist per ADR-0047 D13" \
  --body-file $PACKETS/08-architecture-review-agent-testing-quality-checklist.md \
  --label "chore,tier-3,meta,docs,adr-0047,wave-2"

# --- Wave 3: Phase 3 — Tier 2b container-backed integration tests ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author job-integration-tests-containers.yml (Tier 2b)" \
  --body-file $PACKETS/09-actions-job-integration-tests-containers-workflow.md \
  --label "feature,tier-2,ci-cd,ops,adr-0047,wave-3"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data \
  --title "Pilot Tier 2b — Data.Tests.Integration.Containers with Testcontainers Postgres" \
  --body-file $PACKETS/10-data-tier-2b-testcontainers-postgres-pilot.md \
  --label "feature,tier-2,core,adr-0047,wave-3"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Pilot Tier 2b — IIdempotencyStore contract tests (InMemory + Cosmos)" \
  --body-file $PACKETS/11-kernel-tier-2b-idempotency-store-contract-tests.md \
  --label "feature,tier-2,core,adr-0047,wave-3"

# --- Wave 4: Phase 4 — E2E web ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author job-e2e-web.yml reusable workflow for Playwright (.NET) E2E" \
  --body-file $PACKETS/12-actions-job-e2e-web-workflow.md \
  --label "feature,tier-2,ci-cd,ops,adr-0047,wave-4"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Studios \
  --title "Pilot E2E web — Studios.Tests.E2E with Playwright and nightly schedule" \
  --body-file $PACKETS/13-studios-e2e-web-playwright-pilot.md \
  --label "feature,tier-2,meta,adr-0047,wave-4"

# --- Wave 6: Phase 6 — performance ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Add Kernel.Tests.Benchmarks with BenchmarkDotNet idempotency-store baseline" \
  --body-file $PACKETS/15-kernel-benchmarkdotnet-idempotency-store-baseline.md \
  --label "feature,tier-2,core,adr-0047,wave-6"

# Wave 5 — packet 14 (job-e2e-mobile.yml) is PARKED. Do NOT file until the first
# mobile app repo exists per ADR-0047 D14 Phase 5.
```

## After filing — board fields and blocking relationships

For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>` then set Status=Backlog, Wave (1–6), Initiative=`adr-0047-testing-patterns-and-tooling`, Node (`honeydrunk-architecture` / `honeydrunk-actions` / `honeydrunk-data` / `honeydrunk-kernel` / `honeydrunk-studios`; `HoneyDrunk.Standards` packets use `honeydrunk-architecture` per the convention in packet 01's frontmatter — Standards is not in `nodes.json`), Tier (per packet frontmatter), Actor=Agent (every packet in this initiative is `Actor=Agent` — none carries `human-only`; packets 13 and 15 have Human Prerequisites but the code-authoring critical path is delegable).

Field and option IDs: see `infrastructure/github-projects-field-ids.md` (note: this file's existence is a known pre-existing gap across initiatives — if absent, hand-populate from another already-filed packet's project-item state).

Wire the following `addBlockedBy` relationships (resolved from each packet's `dependencies:` array):

- `02` blocked-by `01` (hard)
- `03` blocked-by `01` (hard)
- `04` blocked-by `01` (hard) — wired on each per-Node fan-out issue
- `05` blocked-by `01` (hard) — wired on each per-Node fan-out issue
- `06` blocked-by `00` (soft), `01` (soft)
- `07` blocked-by `00` (soft)
- `08` blocked-by `00` (soft)
- `09` blocked-by `06` (soft)
- `10` blocked-by `01` (hard), `09` (hard)
- `11` blocked-by `01` (hard), `07` (soft), `09` (hard)
- `12` blocked-by `06` (soft)
- `13` blocked-by `01` (hard), `12` (hard)
- `14` blocked-by `12` (soft) — wired only when packet 14 is un-parked and filed
- `15` blocked-by `01` (soft), `11` (soft)

## Notes

- **Acceptance precedes flip.** ADR-0047 stays Proposed until packet 00's PR merges. Packet 01 may run in parallel with 00 — it is `HoneyDrunk.Standards`-only build tooling and does not require the ADR flip, only the committed decision.
- **The Invariant 15 amendment and invariants 50/51 already landed** (commit 120f39d). No packet re-touches `constitution/invariants.md` beyond packet 00's conditional "(Proposed)" qualifier strip.
- **Packets 04 and 05 are per-Node fan-outs**, not single-repo packets. The `file-issues` agent expands each into one issue per Node repo. Packet 05's per-Node issues are mutually independent (parallel-safe); they share only the upstream dependency on packet 01.
- **Test projects are excluded from the solution version (invariant 27).** None of the migration or pilot packets triggers a release — they are test-project-only changes recorded as tooling/chore CHANGELOG entries.
- **Packet 14 is PARKED.** It is authored so the Maestro CI shape is recorded, but per ADR-0047 D14 Phase 5 it is not filed as a GitHub Issue until the first mobile app exists. The `file-issues` agent holds it.
- **Each wave maps 1:1 to an ADR-0047 D14 phase, and each phase is a discrete go/no-go.** Do not start a wave before the prior wave's exit criteria are met.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).
- **No new repo, no new ADR, no new contract.** This initiative ships docs + build tooling + CI workflows + per-Node test migrations and pilots. The Grid topology is unchanged. `catalogs/contracts.json` is untouched — no runtime contract changes.
- **No Azure resources are provisioned.** Testcontainers runs locally on CI runners; the Cosmos/Postgres emulators are pulled from public registries. Azure Load Testing (D9) is explicitly out of scope until Notify Cloud GA. Cost: $0 recurring, plus a higher macOS-runner-minute multiplier when packet 14's iOS leg eventually runs.

## Archival

Per ADR-0008 D10, when every filed packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0047-testing-patterns-and-tooling/` folder moves to `archive/adr-0047-testing-patterns-and-tooling/` in a single commit. Partial archival is forbidden. Note: packet 14 stays parked — the initiative cannot fully archive until either packet 14 is filed-and-completed (first mobile app shipped) or a future revision re-homes it.

## Revision history

- **2026-05-22 initial scope** — 16 packets across six waves, mapped 1:1 to ADR-0047 D14's six phases. Packet 01 carried over from a prior scoping pass; packets 00, 02–15 authored 2026-05-22. Drafted ahead of ADR-0047 acceptance per the developer's request; packets are pending-acceptance drafts, not yet filed as GitHub Issues.
