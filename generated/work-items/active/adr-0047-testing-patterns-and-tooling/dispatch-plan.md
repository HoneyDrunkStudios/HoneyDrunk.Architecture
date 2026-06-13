# Dispatch Plan: Testing Patterns and Tooling (ADR-0047)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0047 acceptance).
**Trigger:** ADR-0047 (Testing Patterns and Tooling) — Proposed 2026-05-21; priority #2 on `initiatives/current-focus.md` (type `adr-acceptance + packet`). Scoped now, ahead of formal acceptance, so the packet set is ready the moment the ADR lands.
**Type:** Multi-repo (Architecture, Standards, Actions, Data, Kernel, Studios — plus a per-Node fan-out for the two library migrations).
**Sector:** Meta + cross-cutting (every Node with tests is touched by Wave 1's migrations).
**Site sync required:** No. Testing patterns, coverage thresholds, and CI workflows are not public-facing artifacts on the Studios marketing site. Re-evaluate only if a future "engineering practices" page surfaces the testing pyramid.
**Rollback plan:** Architecture-side edits (packets 00, 07, 08) revert cleanly via `git revert` — ADR flip, template authoring, and the `review.md` checklist edit are docs/text-only. `HoneyDrunk.Standards` packets (01, 02, 03) are additive build-tooling — the props fragment, `coverlet.runsettings` templates, and the analyzer rule have no consumers until a Node adopts them, so reverting has no consumer impact. The four `HoneyDrunk.Actions` workflows (06, 09, 13, 15) are additive reusable workflows; 06 also wires `pr-core.yml` but the job is a no-op in non-opted-in repos, so reverting the wiring is safe. The two library migrations (04, 05) are test-project-only and revert per-repo by restoring the prior `PackageReference` and `using` directives — no runtime change, no release triggered. The pilot packets (10, 11, 12, 14, 16) add test/benchmark projects only — reverting deletes the new project with zero runtime impact.

## Summary

ADR-0047 commits the Grid to a concrete testing stack across the pyramid — xUnit + NSubstitute + AwesomeAssertions + coverlet for units; WebApplicationFactory + Testcontainers for the two integration tiers; Playwright (.NET) for web E2E; Maestro for mobile E2E; AutoFixture + Builders for test data; BenchmarkDotNet + Azure Load Testing for performance. It closes ADR-0011 Gap 1 (integration tests) and Gap 3 (E2E tests), and sets per-tier coverage thresholds aligned to the ADR-0036 DR tiers.

This initiative ships **17 packets** (`00`–`16`) across **six waves**, mapped to ADR-0047 D14's six-phase rollout. Each phase is a discrete go/no-go per D14. The Phase 3 (Wave 3) Kernel idempotency pilot is split across two packets — packet 11 (Tier 2a InMemory contract test, independently shippable) and packet 12 (Tier 2b Cosmos binding, hard-preconditioned on ADR-0042 being Accepted) — so the InMemory half is not blocked on a Proposed-ADR-gated package.

**Catalog change landed with this initiative:** `HoneyDrunk.Standards` is now modeled as a Node — `catalogs/nodes.json` id `honeydrunk-standards` (Meta sector, library-only, no-vault tooling repo), `catalogs/relationships.json` and `catalogs/grid-health.json` entries added, and `repos/HoneyDrunk.Standards/{overview,boundaries}.md` created. Standards is the Grid-wide analyzer / EditorConfig / build-tooling home referenced by invariants 26, 27, 58. Packets 01–03 target it directly with `node: honeydrunk-standards`.

**Already complete — not scoped here:** the Invariant 15 amendment and the two new testing invariants (50, 51) already landed in `constitution/invariants.md` (commit 120f39d). ADR-0047's follow-up bullet "Update `constitution/invariants.md` with the two new invariants" is therefore done; no packet covers it.

**Packet 01 (`01-standards-directory-build-props-test-stack.md`)** was authored in a prior scoping pass and is the foundational Wave 1 packet. The remaining 15 packets were authored 2026-05-22.

## Important constraints (from ADR-0047 itself)

- **xUnit v2.x only.** D2 explicitly pins v2.x for consumption stability — v3 is in development, adopt when stable. Every packet that touches the test stack must not adopt xUnit v3.
- **No Moq, no FluentAssertions in new work.** D2 replaces both. Packets 04 and 05 migrate existing usages; after they land, a reintroduction is a regression the `review` agent flags (packet 08).
- **Tier 2b is the scoped exception to invariant 15** — the amended invariant 15 already reflects this. Container-based tests are allowed; the InMemory rule still governs units and Tier 2a.
- **E2E never runs on the PR path.** D1/D5 — E2E is nightly + tag-deploy only, for cost discipline. Packets 13 and 15 are never wired into `pr-core.yml`.
- **Benchmarks are on-demand only.** D9 — never in CI; CI-runner benchmark numbers are meaningless.
- **The 30-day coverage grace period.** D3 / Consequences — Tier 0 / Tier 1 coverage thresholds are advisory for 30 days per Node so existing Nodes can backfill, then flip to blocking. Packet 02 documents this; the CI coverage gate owns the flip.
- **Some D3 coverage tiers are forward-declared.** The D3 tier table assigns thresholds to Nodes not yet scaffolded — Notify Cloud (Tier 0), Memory and Knowledge (Tier 1), Flow and Evals (Tier 2). Packet 02 authors all tier templates regardless (templates are tier-keyed, not Node-keyed); the Notify Cloud / Memory / Knowledge / Flow / Evals threshold assignments become live the moment each Node is scaffolded. No template is blocked on a Node existing, and no packet here backfills these Nodes' coverage — that is per-Node standup work.

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
- [ ] `HoneyDrunk.Kernel`: Pilot Tier 2a — reusable `IIdempotencyStore` contract test + InMemory binding under `Contracts/` — [`11-kernel-tier-2a-idempotency-store-contract-tests.md`](11-kernel-tier-2a-idempotency-store-contract-tests.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 2 — `06` (hard — `job-integration-tests.yml` discovers the Tier 2a project), `07` (soft — uses the scaffold template).
  - **Independently shippable.** Depends only on the `IIdempotencyStore` abstraction and `InMemoryIdempotencyStore` — no container, no Cosmos package, no Tier 2b workflow. This is the un-gated half of the Phase 3 Kernel pilot.
- [ ] `HoneyDrunk.Kernel`: Bind the `IIdempotencyStore` contract test to the Cosmos backing in Tier 2b (Testcontainers) — [`12-kernel-tier-2b-idempotency-store-cosmos-binding.md`](12-kernel-tier-2b-idempotency-store-cosmos-binding.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 2 — `07` (soft); Wave 3 — `09` (hard — wires the Tier 2b workflow into Kernel's CI), `11` (hard — binds the reusable contract test packet 11 authors).
  - **HARD PRECONDITION — do not file or start until ADR-0042 is Accepted AND the Cosmos `IIdempotencyStore` backing package has shipped.** ADR-0042 is Proposed as of 2026-05-22; `HoneyDrunk.Kernel.Idempotency.Cosmos` is an unverified package. The `file-issues` agent holds this packet until both preconditions are confirmed. This is not a runtime "verify the package name" guess — if the package does not exist, the packet does not run. See the packet's HARD PRECONDITION section.

**Wave 3 exit criteria:**
- `job-integration-tests-containers.yml` exists (Docker-capable, container-layer caching, no-op-safe).
- `HoneyDrunk.Data` runs a Tier 2b Postgres suite on every PR.
- `HoneyDrunk.Kernel` runs the reusable `IIdempotencyStore` contract test against `InMemoryIdempotencyStore` in Tier 2a (packet 11).
- *Conditional:* if packet 12's preconditions are met within the wave, `HoneyDrunk.Kernel` also runs the contract test against the Cosmos backing in Tier 2b, passing identically for both. If ADR-0042 is not yet Accepted, packet 12 is held and Wave 3 exits on packets 09/10/11 alone — packet 12 is filed later when its preconditions clear, without re-opening the wave.

### Wave 4 — Phase 4: E2E web (Studios pilot)

- [ ] `HoneyDrunk.Actions`: Author `job-e2e-web.yml` (Playwright .NET) — [`13-actions-job-e2e-web-workflow.md`](13-actions-job-e2e-web-workflow.md)
  - Blocked by: Wave 2 — `06` (soft — mirrors the test-workflow pattern).
- [ ] `HoneyDrunk.Studios`: Pilot E2E web — `HoneyDrunk.Studios.Tests.E2E` with Playwright + nightly schedule — [`14-studios-e2e-web-playwright-pilot.md`](14-studios-e2e-web-playwright-pilot.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 4 — `13` (hard — Studios' caller workflow invokes `job-e2e-web.yml`).
  - Note: Studios is a Next.js repo with no .NET solution; packet 14 scaffolds a minimal `HoneyDrunk.Studios.E2E.sln` for the standalone .NET E2E project.

**Wave 4 exit criteria:**
- `job-e2e-web.yml` exists (browser-binary caching, failure-trace retention, never on the PR path).
- `HoneyDrunk.Studios.Tests.E2E` runs nightly against the deployed Studios `dev` site.

### Wave 5 — Phase 5: E2E mobile (PARKED until the first mobile app ships)

- [ ] `HoneyDrunk.Actions`: Author `job-e2e-mobile.yml` (Maestro) — [`15-actions-job-e2e-mobile-workflow.md`](15-actions-job-e2e-mobile-workflow.md)
  - Blocked by: Wave 4 — `13` (soft — mirrors the E2E workflow pattern).
  - **PARKED.** Per ADR-0047 D14 Phase 5 ("zero work until the first mobile app ships"), the `file-issues` agent must **not file this packet as a GitHub Issue** until the mobile-platform ADR lands and the first consumer app (PDR-0003 Lately / PDR-0004 Wayside / PDR-0005–0008) is scaffolded. It stays in `active/` as a parked draft.
  - **Archival-gate decision (see Archival section):** packet 15 is **explicitly exempted from this initiative's archival gate.** Waiting on a mobile app that does not exist would block archival of an otherwise-complete initiative indefinitely. The Maestro CI shape is recorded here; when the first mobile app ships, packet 15 is re-homed to that mobile initiative and filed there.

### Wave 6 — Phase 6: Performance (ongoing)

- [ ] `HoneyDrunk.Kernel`: Add `HoneyDrunk.Kernel.Tests.Benchmarks` with the BenchmarkDotNet `IIdempotencyStore` lookup baseline — [`16-kernel-benchmarkdotnet-idempotency-store-baseline.md`](16-kernel-benchmarkdotnet-idempotency-store-baseline.md)
  - Blocked by: Wave 1 — `01` (hard); Wave 3 — `11` (soft — packet 11 stands up the `IIdempotencyStore` Tier 2a contract test; the benchmark targets the same `InMemoryIdempotencyStore` backing but depends only on that backing existing, not on packet 11's test project).

**Wave 6 exit criteria:**
- `HoneyDrunk.Kernel.Tests.Benchmarks` exists with an on-demand `IIdempotencyStore` lookup-latency benchmark and a recorded baseline.

## Out-of-scope / deferred items from ADR-0047

- **Test-data tooling — AutoFixture + Builders + Bogus (D7).** ADR-0047 D7 commits AutoFixture for filler test data, the hand-written Builder pattern (in a `Testing` namespace, `[InternalsVisibleTo]`-exposed) for shape-sensitive data, and Bogus for realistic integration-test seed data. **No packet is filed for D7 in this initiative**, deliberately. Rationale: D7 is a *convention*, not a discrete deliverable — it has no single artifact to ship and no forcing function. Unlike the unit-test stack (D2, a `Directory.Build.props` fragment) or the analyzer rule (D10/invariant 51), D7's AutoFixture/Builder/Bogus pattern is adopted per test as tests are written; mandating a Grid-wide AutoFixture rollout packet would be make-work. The convention is captured for the `review` agent via packet 08's Testing Quality checklist update (D13 maps "test architecture — maintainable, not brittle" to D7), and the integration-test scaffold template (packet 07) can reference the Builder pattern. If a future need arises for a shared `HoneyDrunk.Testing` builder/fixture package, that is a separate `scope` pass. Recorded here so D7 is not silently dropped.
- **Canary formalization (D8).** ADR-0047 D8 formalizes the Invariant 14 canary pattern — file location (`tests/Canaries/HoneyDrunk.<Node>.Canary/`), one canary per `.Abstractions` package and per default backing, nightly + post-publish invocation. **No packet is filed for D8 in this initiative.** Rationale: canaries already exist Grid-wide (Invariant 14; `catalogs/grid-health.json` tracks canary status per Node — 13 passing today), and D8 is codification of an existing pattern, not new construction. The post-publish invocation hook is owned by ADR-0034's publish workflow and the nightly run by ADR-0012's grid-health aggregator — both pre-existing. D8's concrete value is enabling the `scope` agent to author canary-creation packets for *new* Nodes without re-inventing structure; that is realized when AI-sector Nodes are scaffolded (their standup initiatives), not here. A future `scope` pass should add a canary-scaffold template to `issues/templates/` alongside packet 07's integration-test template — noted as a follow-up, not filed. Recorded here so D8 is not silently dropped.
- **Azure Load Testing wiring (D9).** ADR-0047 D9 names Azure Load Testing for macro load testing, "as Notify Cloud GA approaches." It has **no forcing function yet** — Notify Cloud GA is gated on ADR-0037 (Proposed) and PDR-0002. No packet here; it is scoped via a future initiative when the Notify Cloud GA work fires. Recorded so the work is not lost.
- **Automated benchmark regression CI (D9).** D9 explicitly names "automated benchmark CI is future work." Packet 15 ships the baseline + manual comparison only.
- **Per-Node BenchmarkDotNet adoption beyond Kernel (D14 Phase 6 "ongoing").** Only the Kernel idempotency benchmark is scoped — it is the one D9 names concretely. Further per-Node benchmarks are filed ad hoc as performance needs surface.
- **Grid-wide Tier 2b wiring beyond the Data/Kernel pilots.** Phase 3 is a pilot per D14; wiring Tier 2b into more Nodes is a follow-up after the pilots prove out.
- **The `*.Tests.Unit` / `*.Tests.Integration` / `*.Tests.E2E` required-tier backfill (invariant 50).** Invariant 50 makes a missing required tier a CI gate failure. This initiative establishes the workflows and the migrations; it does not backfill every Node's missing test tiers. That backfill is per-Node test-hardening work surfaced by the `review` agent (packet 08) and the CI gate, filed as it arises.

## `gh` CLI Commands — File Wave 1–4 + Wave 6 Issues

Paths are relative to the `HoneyDrunk.Architecture` repo root. Wave 5 (packet 15) is **PARKED** and excluded from this batch — file it only when the first mobile app exists. **Packet 12** (Kernel Tier 2b Cosmos binding) is **hard-preconditioned** — exclude it from the batch until ADR-0042 is Accepted AND the Cosmos `IIdempotencyStore` backing package has shipped; file it on its own once both clear. The two migration packets (04, 05) are per-Node fan-outs: the `file-issues` agent derives the per-repo set from an actual grep for `FluentAssertions` / `Moq` usage at filing time (not the prose candidate list) and expands each into one issue per repo with a hit.

```bash
PACKETS="generated/work-items/active/adr-0047-testing-patterns-and-tooling"

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
  --title "Pilot Tier 2a — IIdempotencyStore reusable contract test + InMemory binding" \
  --body-file $PACKETS/11-kernel-tier-2a-idempotency-store-contract-tests.md \
  --label "feature,tier-2,core,adr-0047,wave-3"

# Packet 12 (Kernel Tier 2b Cosmos binding) is HARD-PRECONDITIONED — do NOT file
# until ADR-0042 is Accepted AND the Cosmos IIdempotencyStore backing package has
# shipped. File it on its own once both clear:
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
#   --title "Bind IIdempotencyStore contract test to Cosmos backing (Tier 2b, Testcontainers)" \
#   --body-file $PACKETS/12-kernel-tier-2b-idempotency-store-cosmos-binding.md \
#   --label "feature,tier-2,core,adr-0047,wave-3"

# --- Wave 4: Phase 4 — E2E web ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author job-e2e-web.yml reusable workflow for Playwright (.NET) E2E" \
  --body-file $PACKETS/13-actions-job-e2e-web-workflow.md \
  --label "feature,tier-2,ci-cd,ops,adr-0047,wave-4"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Studios \
  --title "Pilot E2E web — Studios.Tests.E2E with Playwright and nightly schedule" \
  --body-file $PACKETS/14-studios-e2e-web-playwright-pilot.md \
  --label "feature,tier-2,meta,adr-0047,wave-4"

# --- Wave 6: Phase 6 — performance ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Add Kernel.Tests.Benchmarks with BenchmarkDotNet idempotency-store baseline" \
  --body-file $PACKETS/16-kernel-benchmarkdotnet-idempotency-store-baseline.md \
  --label "feature,tier-2,core,adr-0047,wave-6"

# Wave 5 — packet 15 (job-e2e-mobile.yml) is PARKED. Do NOT file until the first
# mobile app repo exists per ADR-0047 D14 Phase 5.
```

## After filing — board fields and blocking relationships

For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>` then set Status=Backlog, Wave (1–6), Initiative=`adr-0047-testing-patterns-and-tooling`, Node (`honeydrunk-architecture` / `honeydrunk-standards` / `honeydrunk-actions` / `honeydrunk-data` / `honeydrunk-kernel` / `honeydrunk-studios`), Tier (per packet frontmatter), Actor=Agent (every packet in this initiative is `Actor=Agent` — none carries `human-only`; packets 12, 14, 16 have Human Prerequisites but the code-authoring critical path is delegable).

`HoneyDrunk.Standards` is now a modeled Node — `catalogs/nodes.json` id `honeydrunk-standards` — so packets 01–03 set `Node=honeydrunk-standards` directly. The prior workaround of mapping Standards packets onto `honeydrunk-architecture` is obsolete and must not be used.

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
- `11` blocked-by `01` (hard), `06` (hard), `07` (soft) — Tier 2a InMemory only; no Tier 2b workflow dependency
- `12` blocked-by `01` (hard), `07` (soft), `09` (hard), `11` (hard) — wired only when packet 12 is un-held (ADR-0042 Accepted + Cosmos backing shipped) and filed
- `13` blocked-by `06` (soft)
- `14` blocked-by `01` (hard), `13` (hard)
- `15` blocked-by `13` (soft) — wired only when packet 15 is un-parked and filed
- `16` blocked-by `01` (hard), `11` (soft)

## Notes

- **Acceptance precedes flip.** ADR-0047 stays Proposed until packet 00's PR merges. Packet 01 may run in parallel with 00 — it is `HoneyDrunk.Standards`-only build tooling and does not require the ADR flip, only the committed decision.
- **The Invariant 15 amendment and invariants 50/51 already landed** (commit 120f39d). No packet re-touches `constitution/invariants.md` beyond packet 00's conditional "(Proposed)" qualifier strip.
- **Packets 04 and 05 are per-Node fan-outs**, not single-repo packets. The `file-issues` agent derives the fan-out repo set from an actual grep for `FluentAssertions` / `Moq` usage at filing time — not from the packets' prose candidate list — and expands each into one issue per repo with a hit. Packet 05's per-Node issues are mutually independent (parallel-safe); they share only the upstream dependency on packet 01.
- **Test projects are excluded from the solution version (invariant 27).** None of the migration or pilot packets triggers a release — they are test-project-only changes recorded as tooling/chore CHANGELOG entries.
- **Packet 12 is HARD-PRECONDITIONED.** The Kernel Tier 2b Cosmos binding is not filed until ADR-0042 (Proposed as of 2026-05-22) is Accepted AND the `HoneyDrunk.Kernel.Idempotency.Cosmos` backing package has shipped. Packet 11 (the Tier 2a InMemory half) carries no such precondition and ships in Wave 3 independently. This split exists so the un-gated half of the Phase 3 Kernel pilot is not blocked on a Proposed-ADR-gated, unverified package.
- **Packet 15 is PARKED.** It is authored so the Maestro CI shape is recorded, but per ADR-0047 D14 Phase 5 it is not filed as a GitHub Issue until the first mobile app exists. The `file-issues` agent holds it. Packet 15 is also exempt from this initiative's archival gate (see Archival).
- **Each wave maps 1:1 to an ADR-0047 D14 phase, and each phase is a discrete go/no-go.** Do not start a wave before the prior wave's exit criteria are met.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).
- **No new repo created, no new ADR, no new runtime contract.** This initiative ships docs + build tooling + CI workflows + per-Node test migrations and pilots. The one catalog change is administrative: `HoneyDrunk.Standards` — an already-existing repo that was simply not yet modeled in the Architecture catalogs — is registered as a Node (`catalogs/nodes.json`, `relationships.json`, `grid-health.json`, `repos/HoneyDrunk.Standards/`). No new repository is created on GitHub; the catalog now reflects a repo that already exists. `catalogs/contracts.json` is untouched — Standards exposes analyzer/build-asset packages, not runtime contracts, so it gets no `contracts.json` entry (consistent with Architecture and Studios).
- **No Azure resources are provisioned.** Testcontainers runs locally on CI runners; the Cosmos/Postgres emulators are pulled from public registries. Azure Load Testing (D9) is explicitly out of scope until Notify Cloud GA. Cost: $0 recurring, plus a higher macOS-runner-minute multiplier when packet 14's iOS leg eventually runs.

## Archival

Per ADR-0008 D10, when every **filed and in-scope** packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0047-testing-patterns-and-tooling/` folder moves to `archive/adr-0047-testing-patterns-and-tooling/` in a single commit. Partial archival is forbidden.

**Archival-gate decisions for the two non-standard packets:**

- **Packet 15 (`job-e2e-mobile.yml`, Wave 5) is explicitly EXEMPT from this initiative's archival gate.** It depends on a mobile app that does not exist and has no committed ship date — gating archival on it would block an otherwise-complete initiative indefinitely, which is the wrong outcome. Decision: when the initiative's filed packets are all `Done`, the initiative archives **with packet 15 carried forward** — packet 15's file is re-homed (moved) into the future mobile-platform / first-consumer-app initiative folder at archival time, and filed there when that initiative runs. The Maestro CI-shape design is preserved; it simply travels to the initiative that can actually consume it. This initiative does not wait on it.
- **Packet 12 (Kernel Tier 2b Cosmos binding) is NOT exempt — it is in-scope but hard-preconditioned.** Unlike packet 15, packet 12 has a concrete unblock condition (ADR-0042 Accepted + Cosmos backing shipped) and ADR-0042 is an active near-term decision. The initiative's archival waits for packet 12 to be filed-and-`Done` once its preconditions clear. If ADR-0042 is rejected or materially deferred such that packet 12 becomes unviable, a future dispatch-plan revision records that and re-classifies packet 12 (exempt-and-re-home, like packet 15, or drop) — but the default expectation is that packet 12 completes within this initiative.

## Revision history

- **2026-05-22 initial scope** — 16 packets across six waves, mapped 1:1 to ADR-0047 D14's six phases. Packet 01 carried over from a prior scoping pass; packets 00, 02–15 authored 2026-05-22. Drafted ahead of ADR-0047 acceptance per the developer's request; packets are pending-acceptance drafts, not yet filed as GitHub Issues.
- **2026-05-22 refine revision** — applied `refine` "Needs Work" verdict fixes. (1) Registered `HoneyDrunk.Standards` as a Node: added `catalogs/nodes.json` id `honeydrunk-standards` (Meta sector, library-only, no-vault), `relationships.json` + `grid-health.json` entries, and `repos/HoneyDrunk.Standards/{overview,boundaries}.md`; packets 01–03 retargeted from `node: honeydrunk-architecture` to `node: honeydrunk-standards` with the hand-waving replaced by concrete references. (2) Split the old Kernel idempotency packet 11 into packet 11 (Tier 2a InMemory contract test, independently shippable) and a new packet 12 (Tier 2b Cosmos binding, hard-preconditioned on ADR-0042 Accepted + Cosmos backing shipped); old packets 12–15 renumbered to 13–16. (3) Packet 06 no-op CI guard made a mandatory explicit step with empty-repo verification before `pr-core.yml` wiring. (4) Packet 14 (Studios E2E) given a concrete .NET-project scaffold sub-step and minimal `.sln` layout. (5) Packets 04/05 instructed to derive the migration fan-out set from a real grep, not the prose list. (6) Packet 02 + this plan note forward-declared Tier 0/1 thresholds for not-yet-scaffolded Nodes. (7) D7/D8 added to the deferred section with rationale. (8) Packet 16 (was 15) `work-item:11` dependency annotated soft. (9) Packet 15 (was 14, mobile E2E) explicitly exempted from the archival gate with a re-home decision. Initiative is now **17 packets** (`00`–`16`).
