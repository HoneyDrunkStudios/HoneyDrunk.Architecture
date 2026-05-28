# Active Initiatives

Tracked initiatives currently in progress or planned. Completed and cancelled initiatives live in [archived-initiatives.md](archived-initiatives.md). For the ranked priority order across all work, see [current-focus.md](current-focus.md).

## In Progress

### ADR-0044 Cloud Code Review and AI-Authored PR Discipline
**Status:** In Progress
**Scope:** Architecture, Actions, OpenClaw runtime, and later the live Node repos
**Initiative:** `adr-0044-cloud-code-review`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0044 and ship the automatic Grid-aware code-review substrate: GitHub Actions emits signed review requests; OpenClaw/Codex runs the canonical `.claude/agents/review.md` with Grid context; review results are advisory in Phase 1 and piloted on `HoneyDrunk.Architecture` before fan-out.

**Tracking (Wave 1 — Phase 1: Architecture pilot):**
- [x] Architecture#170: Accept ADR-0044 — flip status, finalize invariants 52/53, register initiative (packet 01; shipped via PR #273)
- [x] Architecture#179: Define the OpenClaw/Codex Grid Review Runner runtime (packet 02b; shipped via PR #274)
- [x] Actions#87: Build `job-review-request.yml` — GitHub trigger rail for OpenClaw reviewer (packet 03b; shipped via Actions PR #99)
- [x] Architecture#172: Update `.claude/agents/review.md` with the D3 twenty-category rubric execution detail (packet 04; shipped via PR #276)
- [x] Architecture#180: Author the OpenClaw-aware `.honeydrunk-review.yaml` v1 schema doc (packet 05b; shipped via PR #277)
- [x] Architecture#181: Enable the OpenClaw/Codex reviewer on `HoneyDrunk.Architecture` (packet 06b; shipped via PR #278)

**Tracking (Wave 2 — Phase 2: live Node rollout + discipline foundations):**
- [x] Actions#85: Add authorship-check and pr-size-check jobs to `pr-core.yml` (packet 07; shipped via Actions PR #100, closed 2026-05-23)
- [x] Actions#86: Seed `large-pr`, `audit-sample`, and `skip-review` labels Grid-wide (packet 08; labels-as-code and seed/fanout workflows shipped via Actions PR #100; fanout repair shipped via Actions PR #101; fanout run verified 2026-05-24)
- [x] Architecture#175: Roll the D3 rubric into upstream authoring agents (packet 09; shipped via PR #279)
- [x] Architecture#176: Amend execution-surface prompts for `Authorship:` and D3 checklist (packet 10; shipped via PR #279)
- [ ] Architecture#182: Superseded by ADR-0086 packet 09 — enable the local-worker reviewer on the 10 remaining live Nodes instead of the OpenClaw/Codex runner.
- [x] Architecture#183: Verify `pr-review-rules.md` severity coverage across all D3 categories (packet 12; shipped via this PR)

**Tracking (Wave 3 — Phase 3: discipline tightening):**
- [ ] Architecture#184: Add `review_risk_class` to `catalogs/grid-health.json` (packet 13)
- [ ] Actions#88: Activate D8 multi-perspective review for high-risk-Node PRs (packet 14)

**Tracking (Wave 4 — Phase 4: sampling audit + drift detection):**
- [ ] Architecture#185: Create `generated/post-merge-audits/` with README (packet 15)
- [ ] Actions#89: Build the D9 `audit-sample` post-merge labeling and audit job (packet 16)
- [ ] Architecture#186: Wire `hive-sync` to detect D3 ↔ agent-file drift (packet 17)

**Superseded packets:** Architecture#171, Actions#84, Architecture#173, Architecture#174, and Architecture#182 are superseded and should not be executed. Architecture#173 and Architecture#174 should be closed as superseded by Architecture#180/#181; Architecture#182 is superseded by ADR-0086 packet 09, which fans out the `local-worker` default instead of `openclaw-codex`; Architecture#171 remains a gated human/infra item only if webhook/GitHub-App credentials become necessary for the non-cron path.

**Exit criteria:** ADR-0044 is Accepted; Phase 1 MVP (`job-review-request.yml` + Grid Review Runner) is enabled on `HoneyDrunk.Architecture` only and running on every non-draft PR; each phase's dispatch-plan go/no-go criterion is satisfied before the next wave starts.

> **Sync (2026-05-24):** Phase 1 is functionally complete in artifact-plus-cron/poll mode: ADR-0044 is Accepted, `job-review-request.yml` is live, Architecture has `.honeydrunk-review.yaml` and the caller workflow, and OpenClaw posted advisory PR comments for reviewed head SHAs. Webhook provisioning remains the transport hardening gap; the temporary OpenClaw cron/poll jobs should be disabled after signed webhook delivery is configured and verified. Wave 2 Architecture-side docs/prompts (#175, #176, #183) have landed. Actions#85 is closed via Actions PR #100; Actions#86 is closed after the `seed-labels-fanout.yml` run completed successfully on 2026-05-24. ADR-0044 no longer uses the deprecated multi-agent cloud-review path; broad Node fan-out (#182) is unblocked.

### ADR-0086 Pull-Based Local Worker Grid Review Runner
**Status:** In Progress
**Scope:** Architecture, Actions, the local worker host, and later the live Node repos
**Initiative:** `adr-0086-pull-based-local-worker-grid-review`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0086 and replace the fragile signed-webhook -> OpenClaw review path with a GitHub-native queue plus local pull worker. GitHub Actions normalizes managed PR labels and enqueues via labels plus a structured queue comment; the home-server worker polls, claims one PR/head SHA at a time, runs Codex CLI and Claude Code CLI under subscription auth when required, synthesizes their findings into one advisory verdict, and preserves ADR-0044/ADR-0079 review discipline.

**Tracking (Wave 1 — Phase A: Architecture pilot):**
- [x] Architecture: Accept ADR-0086, append supersession notes to ADR-0044/ADR-0079, register this initiative, and mark ADR-0044 Architecture#182 superseded (packet 01)
- [ ] Architecture: Audit and reuse the existing ADR-0044 review-agent GitHub App walkthrough/credential contract (packet 02)
- [ ] Architecture: Author the PowerShell pull worker under `infrastructure/workers/grid-review-runner/`, including dual Codex/Claude synthesis and Task Scheduler startup/restart behavior (packet 03)
- [ ] Architecture: Update the `.honeydrunk-review.yaml` schema doc for `runner: local-worker` / `api-ci` and removal of `openclaw-codex` (packet 04)
- [ ] Actions: Rewrite `job-review-request.yml` as the managed-label-normalizing label/comment enqueue workflow (packet 05)
- [ ] Actions: Add `needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, and `changes-requested-by-agent` labels Grid-wide (packet 06)
- [ ] Architecture: Cut over the Architecture pilot to the local worker and record Phase-A go/no-go evidence (packet 07)

**Tracking (Wave 2 — Phase B: decommission + fan-out):**
- [ ] Architecture: Decommission OpenClaw on the review path and document operator-side cutover steps (packet 08; must land before packet 09)
- [ ] Cross-repo: Enable the local-worker reviewer on the 10 remaining live Nodes, superseding ADR-0044 Architecture#182 (packet 09)

**Tracking (Wave 3 — Phase C: observability polish):**
- [ ] Architecture: Surface worker queue depth / backlog age through hive-sync and the weekly briefing surfaces (packet 10)

**Exit criteria:** Phase A proves verdict quality, reliable polling/claim semantics, deterministic head-SHA invalidation, and near-zero marginal cost under subscription auth on `HoneyDrunk.Architecture`; Phase B follows only after OpenClaw is decommissioned on the review path; Phase C makes worker availability visible through the existing narrative surfaces without adding a pager or inbound alert.

### ADR-0047 Testing Patterns and Tooling
**Status:** In Progress
**Scope:** Architecture, Standards, Actions, Data, Kernel, Studios, and every Node repo with test projects
**Initiative:** `adr-0047-testing-patterns-and-tooling`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Roll out the ADR-0047 Grid testing stack: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet for unit tests; WebApplicationFactory and Testcontainers for integration tiers; Playwright (.NET) for web E2E; Maestro for future mobile E2E; BenchmarkDotNet / Azure Load Testing for performance. Closes ADR-0011 Gap 1 and Gap 3.

**Tracking (Wave 1 — Phase 1: unit-test stack + migrations + coverage gates):**
- [x] Architecture#187: Accept ADR-0047 — flip status, close ADR-0011 Gap 1 and Gap 3, register the testing-patterns initiative (packet 00)
- [ ] Standards: Author shared unit-test-stack `Directory.Build.props` fragment (packet 01)
- [ ] Standards: Author `coverlet.runsettings` templates for D3 per-tier thresholds (packet 02)
- [ ] Standards: Add the `Thread.Sleep` analyzer rule for test projects (packet 03)
- [x] Architecture#188 / per-Node fan-out: Migrate FluentAssertions → AwesomeAssertions (packet 04)
- [x] Architecture#189 / per-Node fan-out: Migrate Moq → NSubstitute (packet 05)

**Tracking (Wave 2 — Phase 2: Tier 2a integration tests):**
- [ ] Actions: Author `job-integration-tests.yml` and wire it into `pr-core.yml` (packet 06)
- [x] Architecture#190: Author the integration-test scaffold template for the `scope` agent (packet 07)
- [x] Architecture#191: Update `.claude/agents/review.md` Testing Quality checklist per ADR-0047 D13 (packet 08)

**Tracking (Wave 3 — Phase 3: Tier 2b container-backed integration tests):**
- [ ] Actions: Author `job-integration-tests-containers.yml` (packet 09)
- [ ] Data: Pilot Tier 2b `Data.Tests.Integration.Containers` with Testcontainers Postgres (packet 10)
- [ ] Kernel: Pilot Tier 2a `IIdempotencyStore` reusable contract test + InMemory binding (packet 11)
- [ ] Kernel: Bind `IIdempotencyStore` contract test to Cosmos backing in Tier 2b (packet 12 — parked until ADR-0042 is Accepted and Cosmos backing exists)

**Tracking (Wave 4 — Phase 4: E2E web):**
- [ ] Actions: Author `job-e2e-web.yml` reusable workflow for Playwright (.NET) E2E (packet 13)
- [ ] Studios: Pilot `Studios.Tests.E2E` with Playwright and nightly schedule (packet 14)

**Tracking (Wave 5 — Phase 5: E2E mobile):**
- [ ] Actions: Author `job-e2e-mobile.yml` for Maestro (packet 15 — parked until first mobile app ships)

**Tracking (Wave 6 — Phase 6: performance):**
- [ ] Kernel: Add `Kernel.Tests.Benchmarks` with BenchmarkDotNet idempotency-store baseline (packet 16)

**Exit criteria:** ADR-0047 is Accepted; Standards ships the shared test stack, coverage templates, and analyzer; no Node test project retains Moq or FluentAssertions; Tier 2a/Tier 2b/E2E workflows and pilots land per D14; parked mobile/Cosmos work is either completed or explicitly re-homed when its trigger fires.

### Kernel Adoption Alignment
**Status:** In Progress
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data, Vault.Rotation, Notify, Pulse, Communications, Architecture
**Initiative:** `kernel-adoption-alignment`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Follow-up from the 2026-05-17 Kernel adoption audit. Align active .NET Nodes on canonical Kernel identity/context usage, remove avoidable runtime Kernel dependencies, enforce Grid/Operation context at HTTP/message/background entry points, clean up Notify queue-secret bootstrap drift, and reconcile Architecture compatibility metadata after repo PRs merge.

**Tracking:**
- [x] Kernel#29: Align Kernel context bootstrap and well-known Node IDs (packet 01 — closed 2026-05-18)
- [x] Transport#27: Drop Transport dependency on Kernel runtime (packet 02 — closed 2026-05-18)
- [x] Vault#31: Align Vault to current Kernel packages (packet 03 — closed 2026-05-18)
- [x] Auth#20: Align Auth to current Kernel packages (packet 04 — closed 2026-05-18)
- [x] Web.Rest#17: Require Kernel context in Web.Rest request pipeline (packet 05 — closed 2026-05-18)
- [x] Data#21: Require context for Data outbox enrichment (packet 06 — closed 2026-05-18)
- [x] Vault.Rotation#7: Establish Kernel context for rotation timer jobs (packet 07 — closed 2026-05-18)
- [x] Notify#13: Align Notify Kernel identity and queue secret boundary (packet 08 — closed 2026-05-18)
- [x] Pulse#15: Align Pulse to Kernel canonical identity (packet 09 — closed 2026-05-18)
- [x] Communications#14: Drop Communications runtime Kernel dependency (packet 10 — closed 2026-05-18)
- [x] Architecture#111: Reconcile Kernel adoption catalogs and compatibility (packet 11 — closed 2026-05-18)

> **Sync (2026-05-21):** Kernel#29, Transport#27, Communications#14, and Architecture#111 are now closed; packets 01, 02, 10, and 11 moved to `completed/`. All 11 packet issues are closed; initiative is ready for exit-criteria review/archive.

### ADR-0010 Observation Layer & AI Routing — Phase 1
**Status:** Phase 1 Observe-side complete; AI routing contracts satisfied by ADR-0016
**Scope:** Architecture, Observe (new), AI
**Initiative:** `adr-0010-observe-ai-routing-phase-1`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** ADR-0010 is accepted, HoneyDrunk.Observe is registered in Architecture catalogs/context, and the Observe repo now has the Phase 1 `HoneyDrunk.Observe.Abstractions` contract surface. The AI routing contracts originally tracked as packet 04 were superseded by ADR-0016 and shipped with the HoneyDrunk.AI standup scaffold. Phase 2 (first useful Observe connector + cost-first AI routing policy) and Phase 3 (HoneyHub integration, blocked on HoneyHub Phase 1 being live) remain future scope.

**Tracking (Phase 1 — Observe side):**
- [x] Architecture#35: Accept ADR-0010 — catalog, context folder, sectors, invariant 29-30 text, ADR index flip, initiative/roadmap trackers (packet 01 — closed 2026-05-21 via PR #157)
- [x] Architecture#36: Create HoneyDrunk.Observe GitHub repo (human-only chore — packet 02; closed 2026-04-18)
- [x] Observe#2: Scaffold HoneyDrunk.Observe.Abstractions with IObservationTarget / IObservationConnector / IObservationEvent (packet 03 — closed 2026-05-21 via Observe PR #3)

**Tracking (Phase 1 — AI routing contracts side):**
- [x] AI#2 / ADR-0016: HoneyDrunk.AI standup scaffold shipped `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`, and related routing/cost contracts in `HoneyDrunk.AI.Abstractions` (closed 2026-05-20 via AI PR #5)
- [x] AI#1 / AI#3: duplicate ADR-0010 packet-04 issues superseded by ADR-0016; retained only for traceability and closed during reconciliation

**Next (Phase 2 — not yet scoped):**
- Implement `HoneyDrunk.Observe` runtime composition and observation-state handling
- Implement `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver + repo health checks
- Implement cost-first `IRoutingPolicy` in HoneyDrunk.AI runtime and load routing policies from Azure App Configuration (per ADR-0005 three-tier config split)
- **Scope trigger:** Phase 1 contract surfaces are now present; begin Phase 2 only when there is a concrete external-project observation need and a live application-code caller for cost-first routing.

**Deferred (Phase 3 — blocked on HoneyHub Phase 1):**
- Route normalized `IObservationEvent` instances into HoneyHub's knowledge graph
- Allow HoneyHub to read routing-policy outcomes as plan-adjustment signals
- **Scope trigger:** HoneyHub Phase 1 domain model + graph API live

> **Sync (2026-05-21):** Architecture#35/#36 and Observe#2 are closed. HoneyDrunk.AI is no longer empty; ADR-0016 AI#2/PR#5 shipped the routing contracts packet 04 was waiting for. ADR-0010 Phase 1 contract/catalog work is complete; remaining work should be scoped as Phase 2 implementation, not more Phase 1 scaffold.

### ADR-0030 Grid-Wide Audit Substrate — Capability Acceptance
**Status:** In Progress
**Scope:** Architecture (capability acceptance only; HoneyDrunk.Audit standup is a separate ADR-0031-governed initiative)
**Initiative:** `adr-0030-audit-substrate`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept the capability/decision ADR for the Grid-wide durable, attributable security and action audit substrate homed in a new dedicated `HoneyDrunk.Audit` Node (Core sector). Registers the Node and its four new dependency edges across the catalogs, adds the Core-sector Audit row, flips the ADR index, verifies (does not modify) ADR-0018's pre-existing 2026-05-16 amendment (relocating `IAuditLog`/`AuditEntry` out of Operator, reclassifying Operator to consumer-not-owner), creates the `repos/HoneyDrunk.Audit/` context folder, and adds the constitutional audit-emission boundary invariant. The Node scaffold, the contract-shape canary, the Auth first-emitter wiring, and the Operator reconciliation are **all governed by the separate ADR-0031 standup** and are NOT in this initiative.

**Tracking:**
- [x] Architecture#108: Accept ADR-0030 — catalog registration, sectors row, ADR index flip, ADR-0018 amendment verification, repo context folder, trackers (packet 01 — closed 2026-05-18)
- [x] Architecture#109: Add the audit-emission boundary invariant to the constitution (packet 02 — closed 2026-05-18)

**Follow-up sync (2026-05-21):** ADR-0031 standup has now completed its initial packet set: Architecture invariants/catalog work, Audit repo scaffold + `v0.1.0` release, and Auth first-emitter wiring are closed. Remaining Operator reconciliation is future downstream work, not part of ADR-0030 capability acceptance. Audit `v0.1.0` and Auth `v0.5.0` are both published.

### ADR-0032 PR Validation Policy — Coverage Gate & NuGet Flagging
**Status:** In Progress
**Scope:** Meta (Actions CI/CD control plane) + ten test-bearing Nodes (per-repo coverage backfill)
**Initiative:** `adr-0032-pr-validation-policy`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** One PR Validation Policy owned by the Actions control plane, implemented once in the reusable workflows: (1) a blocking coverage gate — patch coverage threshold, no-regression vs. committed `.github/coverage-baseline.json`, flat absolute floor, skip-when-no-test-projects; (2) non-blocking NuGet flagging — outdated never blocks, surfaced as a PR-summary section and a single grouped `📦 Outdated Dependencies` issue per repo. Builds on ADR-0009 (outdated-vs-vulnerable split), ADR-0011 (`pr-core.yml` tier-1 gate), ADR-0012 (Actions as CI/CD control plane).

**Tracking (Wave 1 — Actions control plane, parallel):**
- [x] Actions#77: Coverage gate + ⚠️ outdated-packages PR-summary section (D1–D5) (packet 01 — closed 2026-05-19)
- [x] Actions#78: `nightly-deps` grouped per-repo `📦 Outdated Dependencies` tracking issue (D6) (packet 02 — closed 2026-05-19)

**Tracking (Wave 2 — per-repo coverage backfill to the absolute floor, hard-blocked by packet 01 only, fully parallel):**
- [x] Kernel#28 / Transport#26 / Vault#30 / Vault.Rotation#6 / Auth#19 / Web.Rest#16 / Data#20 / Pulse#14 / Notify#12 / Communications#13 — one backfill packet each (packets 03–12; closed 2026-05-19 through 2026-05-20)

**Notes:**
- New constitutional invariant (coverage gate at PR time) is added by the implementing packet; number assigned at acceptance, after the ADR-0030/0031 audit reservations (44–46) — see ADR-0032's New Invariant section.
- **Sync (2026-05-21):** All 12 packet issues are closed and packets moved to `completed/`. ADR-0032 remains `Proposed` because these packets do not yet declare `accepts:` frontmatter, so hive-sync will not auto-flip it; human/scope follow-up needed if acceptance should be automated.

### Hive Sync Rollout (ADR-0014)
**Status:** In Progress
**Scope:** Architecture
**Initiative:** `adr-0014-hive-sync-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Rename the legacy initiative sync agent to `hive-sync` and broaden its mandate to cover the packet lifecycle (active → completed), non-initiative board items, the Proposed-ADR/PDR queue, ADR/PDR auto-acceptance + README index sync, and a drift report. Closes the drift introduced by nightly-security issues having no Architecture-repo presence, completed packets lingering in `active/`, and ADRs/PDRs that drift out of sync with their implementing work or with the rest of the repo. Single repo (Architecture); six sequential phases. ADR-0014 itself auto-flips to Accepted via Phase 5's logic on the first run after Packet 06 closes.

**Tracking:**
- [x] Architecture#61: Rename agent + capability matrix (packet 01)
- [x] Architecture#62: Add packet lifecycle and Hive-Sync invariant for lifecycle (packet 02)
- [x] Architecture#63: Track non-initiative board items + Hive-Sync invariant for board coverage (packet 03)
- [x] Architecture#64: Surface Proposed-ADR acceptance queue (packet 04)
- [x] Architecture#65: ADR/PDR auto-acceptance + README index sync (packet 05)
- [x] Architecture#66: Drift detection + close out the rollout (packet 06)

> **Sync (2026-05-16):** ADR-0014 rollout implementation remains merged; Architecture#61-#66 remain closed. Hive Sync is running under OpenClaw cron; ready for human archive/exit-criteria review.


### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)
**Status:** In Progress
**Scope:** Vault, Vault.Rotation (new), Architecture, Actions, Auth, Web.Rest, Data, Notify, Pulse, Studios
**Initiative:** `adr-0005-0006-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Per-Node Key Vault + shared App Configuration + env-driven bootstrap model (ADR-0005), plus rotation lifecycle, event-driven invalidation, and deploy-gate SLA checks (ADR-0006). Two waves: foundation then per-Node migration.
**Tracking:**
- [x] Issue packets authored (15 packets, 2 waves)
- [x] Wave 1 issues filed on board (7/7 — Architecture#8 closed 2026-04-11, unblocking Vault.Rotation scaffold)
- [x] Wave 1: Vault env-driven `AddVault` wiring (Vault#9 closed 2026-04-12)
- [x] Wave 1: Vault `AddAppConfiguration` extension (Vault#9 closed 2026-04-12)
- [x] Wave 1: Vault event-driven cache invalidation (Vault#10 closed 2026-04-12)
- [x] Wave 1: Vault.Rotation repo creation (Architecture#8 closed 2026-04-11 — repo created, unblocking scaffold execution)
- [x] Wave 1: Architecture portal walkthroughs (Architecture#7 closed 2026-04-11)
- [x] Wave 1: Architecture catalog registration for Vault.Rotation (Architecture#7 closed 2026-04-11)
- [x] Wave 1: Actions OIDC federated-credential workflow (Actions#20 closed)
- [x] Wave 2: Per-Node bootstrap migrations (Auth#5, Web.Rest#4, Data#4, Notify#1, Pulse#1, Studios#2 closed)
- [x] Wave 2: Actions direct secret removal + deploy-gate SLA check (Actions#21 closed)

> **Sync (2026-05-16):** 15/15 issue packets remain closed. Completed manifest entries older than 30 days were pruned from `filed-packets.json`; packet files remain archived in `completed/`. Initiative remains ready for exit-criteria review/archive, with release-verification notes still tracked in `initiatives/releases.md`.

### Container Apps Rollout (ADR-0015)
**Status:** In Progress  
**Scope:** Architecture, Actions, Notify, Pulse  
**Initiative:** `adr-0015-container-apps-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Deploy Notify and Pulse to Azure Container Apps. Includes infrastructure walkthroughs, Container App deployment workflow in Actions, and per-service release workflows.

**Tracking:**
- [x] Architecture#37: Infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App (closed)
- [x] Actions#48: Reusable workflow `job-deploy-container-app.yml` for Azure Container Apps (closed)
- [ ] Notify#3: Release workflow and Azure bring-up for `Notify.Functions` (open)
- [ ] Notify#4: Release workflow and Azure bring-up for `Notify.Worker` on Container Apps (open)
- [ ] Pulse#3: Release workflow and Azure bring-up for `Pulse.Collector` on Container Apps (open)

> **Sync (2026-05-21):** 2/5 issues closed (40%). Foundation walkthroughs and reusable Actions workflow remain complete; Notify#3, Notify#4, and Pulse#3 are still open for service-specific release/Azure bring-up work. ADR-0033 environment-gated deploy-trigger packets (`Notify#19`, `Notify#20`, `Pulse#18`) are open in Backlog and should land before dev deploy verification resumes.

### Package Scanning Rollout (ADR-0009)
**Status:** In Progress  
**Scope:** Kernel, Auth, Data, Transport, Vault, Pulse, Notify, Web.Rest  
**Initiative:** `adr-0009-package-scanning-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Wire CI scan workflows and dynamic release notes across all Nodes. Standardizes vulnerability scanning and auto-generates release summaries from commit history.

**Tracking:**
- [x] Kernel wire up CI scan workflows (Kernel#14 closed 2026-04-16)
- [x] Auth wire up CI scan workflows (Auth#6 closed 2026-04-12)
- [x] Data wire up CI scan workflows (Data#5 closed 2026-04-16)
- [x] Transport wire up CI scan workflows (Transport#14 closed 2026-04-12)
- [x] Vault wire up CI scan workflows (Vault#13 closed 2026-04-12)
- [x] Pulse wire up CI scan workflows (Pulse#2 closed)
- [x] Notify wire up CI scan workflows (Notify#2 closed)
- [x] Web.Rest wire up CI scan workflows (Web.Rest#5 closed 2026-04-16)

> **Sync (2026-05-16):** 8/8 issues remain closed (100%). Older completed manifest entries were pruned; packet files remain archived in `completed/`. Rollout remains ready for archive/exit-criteria review.

### Vault.Rotation Bring-Up
**Status:** In Progress  
**Scope:** Vault.Rotation, Architecture, Actions  
**Initiative:** `vault-rotation-bring-up`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Scaffold HoneyDrunk.Vault.Rotation as a deployable Function Node, wire OIDC + RBAC, and complete ADR-0006 Tier-2 operational setup.
**Tracking:**
- [x] Architecture catalog registration + routing keywords (Architecture#7 closed 2026-04-11)
- [x] Architecture repo stubs (`repos/HoneyDrunk.Vault.Rotation/*`)
- [x] Repo scaffold implementation packet execution (Vault.Rotation#3 closed)
- [x] Managed identity + vault RBAC automation
- [x] Rotation function runtime + observability

> **Sync (2026-05-16):** Related ADR-0005/0006 Vault.Rotation packets remain closed, including scaffold and release-tag issues. Ready for archive/exit-criteria review.

### Grid v0.4 Stabilization
**Status:** In Progress  
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data  
**Description:** All Core Nodes aligned on Kernel 0.4.0 contracts. Canary tests passing across all boundaries.  
**Tracking:**
- [x] Kernel 0.4.0 released
- [x] Transport 0.4.0 aligned
- [x] Vault 0.2.0 aligned
- [x] Auth 0.2.0 aligned
- [x] Web.Rest 0.2.0 aligned
- [x] Data 0.3.0 aligned
- [ ] Notify aligned to Kernel 0.4.0 patterns
- [ ] Pulse aligned to Kernel 0.4.0 patterns

> **Sync (2026-04-16):** 6/8 items done. Core nodes (Kernel, Transport, Vault, Auth, Web.Rest, Data) all v0.4.0 aligned. Notify (v0.1.0) and Pulse (v0.1.0) have signal: Seed, blocked by Azure deployment per grid-health.json. No new progress in past 4 days. Core objectives met; Notify/Pulse deployment gated on infrastructure provisioning.

### Notification Subsystem Launch
**Status:** In Progress  
**Scope:** Notify  
**Description:** First release of HoneyDrunk.Notify with email (SMTP, Resend) and SMS (Twilio) providers.  
**Tracking:**
- [x] Abstractions and runtime packages
- [x] Email providers (SMTP, Resend)
- [x] SMS provider (Twilio)
- [x] Queue backends (Azure Storage, InMemory)
- [x] Background worker
- [x] Azure Functions deployment workflow
- [ ] Integration tests with live providers

> **Sync (2026-05-05):** 6/7 items done. Notify v0.2.0 released and the Azure Functions deploy workflow completed. Live provider integration tests remain as production-hardening work.

### Ops: Observability Pipeline
**Status:** In Progress  
**Scope:** Pulse  
**Description:** Multi-backend telemetry with Pulse.Collector as OTLP receiver.  
**Tracking:**
- [x] All sink implementations
- [x] Pulse.Collector with OTLP parsing
- [x] Health and readiness endpoints
- [ ] Production deployment of Pulse.Collector
- [ ] Dashboard templates for Grafana

> **Sync (2026-04-16):** 3/5 items done. Production Pulse.Collector deployment and Grafana dashboard templates remain. grid-health.json confirms active_blockers. No progress in 4 days; gated on deployment and dashboard work.

## Planned

### HoneyDrunk.Lore Bring-Up
**Status:** On Deck  
**Scope:** Lore, Architecture  
**Initiative:** `honeydrunk-lore-bringup`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Stand up HoneyDrunk.Lore as a flat-file LLM-compiled wiki. Repo scaffolded with `raw/`, `wiki/`, `output/`, `tools/` directories, CLAUDE.md schema doc, sourcing playbook, Obsidian vault configuration, Web Clipper, scheduled ingest agent, and OpenClaw sourcing skill. Inspired by the Karpathy LLM-wiki pattern. Flat-file-first — Knowledge/Agents integration deferred until those nodes exist.  
**Tracking:**
- [x] Lore#1: Repo scaffold + CLAUDE.md schema doc (closed)
- [x] Lore#2: Obsidian vault setup + Web Clipper (human-only) (closed)
- [x] Lore#3: Scheduled ingest agent (CronCreate) (closed)
- [x] Lore#4: sourcing-playbook.md (closed)
- [x] Lore#5: OpenClaw setup + Lore sourcing skill (closed)
- [x] Architecture#9: Catalog registration for HoneyDrunk.Lore (closed)

> **Sync (2026-05-16):** 6/6 issues remain closed (100%). Lore bring-up packets are closed and in the completed archive; ready for archive/exit-criteria review.

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
