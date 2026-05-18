# Active Initiatives

Tracked initiatives currently in progress or planned. Completed and cancelled initiatives live in [archived-initiatives.md](archived-initiatives.md).

## In Progress

### Kernel Adoption Alignment
**Status:** In Progress
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data, Vault.Rotation, Notify, Pulse, Communications, Architecture
**Initiative:** `kernel-adoption-alignment`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Follow-up from the 2026-05-17 Kernel adoption audit. Align active .NET Nodes on canonical Kernel identity/context usage, remove avoidable runtime Kernel dependencies, enforce Grid/Operation context at HTTP/message/background entry points, clean up Notify queue-secret bootstrap drift, and reconcile Architecture compatibility metadata after repo PRs merge.

**Tracking:**
- [ ] Kernel#29: Align Kernel context bootstrap and well-known Node IDs (packet 01) — v0.7.0 released; issue still open in GitHub.
- [ ] Transport#27: Drop Transport dependency on Kernel runtime (packet 02) — v0.6.0 released; issue still open in GitHub.
- [x] Vault#31: Align Vault to current Kernel packages (packet 03 — closed 2026-05-18)
- [x] Auth#20: Align Auth to current Kernel packages (packet 04 — closed 2026-05-18)
- [x] Web.Rest#17: Require Kernel context in Web.Rest request pipeline (packet 05 — closed 2026-05-18)
- [x] Data#21: Require context for Data outbox enrichment (packet 06 — closed 2026-05-18)
- [x] Vault.Rotation#7: Establish Kernel context for rotation timer jobs (packet 07 — closed 2026-05-18)
- [x] Notify#13: Align Notify Kernel identity and queue secret boundary (packet 08 — closed 2026-05-18)
- [x] Pulse#15: Align Pulse to Kernel canonical identity (packet 09 — closed 2026-05-18)
- [ ] Communications#14: Drop Communications runtime Kernel dependency (packet 10) — v0.2.0 released; issue still open in GitHub.
- [ ] Architecture#111: Reconcile Kernel adoption catalogs and compatibility (packet 11)

> **Sync (2026-05-18):** Core package reality is reconciled in Architecture metadata through Kernel 0.7.0 / Transport 0.6.0 / Vault 0.5.0 / Auth 0.4.0 / Web.Rest 0.5.0 / Data 0.6.0 / Notify 0.3.0 / Pulse 0.3.0 / Communications 0.2.0. Closed packets 03–09 moved to `completed/`; packets 01, 02, 10, and 11 remain active because their GitHub issues are still open.

### ADR-0010 Observation Layer & AI Routing — Phase 1
**Status:** In Progress
**Scope:** Architecture, Observe (new), AI
**Initiative:** `adr-0010-observe-ai-routing-phase-1`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0010 and ship Phase 1 (contracts + stubs). Catalog registration for HoneyDrunk.Observe, new Observe repo scaffold with Abstractions package, and routing contracts in HoneyDrunk.AI.Abstractions. Phase 2 (first GitHub connector + cost-first routing policy) and Phase 3 (HoneyHub integration, blocked on HoneyHub Phase 1 being live) are tracked below so they do not get lost.

**Tracking (Phase 1 — Observe side):**
- [ ] Architecture#35: Accept ADR-0010 — catalog, context folder, sectors, invariant 29-30 text, ADR index flip, initiative/roadmap trackers (packet 01)
- [x] Architecture#36: Create HoneyDrunk.Observe GitHub repo (human-only chore — packet 02)
- [ ] Observe#2: Scaffold HoneyDrunk.Observe.Abstractions with IObservationTarget / IObservationConnector / IObservationEvent (packet 03)

**Deferred (Phase 1 — AI routing contracts side):**
- AI#1: Add IModelRouter / IRoutingPolicy / ModelCapabilityDeclaration to HoneyDrunk.AI.Abstractions (packet 04) — **parked pending HoneyDrunk.AI standup ADR**. The HoneyDrunk.AI repo exists but is empty; scaffolding choices (solution layout, M.E.AI alignment, package split, first provider, Pulse integration) deserve their own ADR. Provisional next step: draft `ADR-0016-stand-up-honeydrunk-ai-node`, accept it, run a scaffolding initiative, then file packet 04. Invariant 28's `(Proposed)` qualifier stays intact until packet 04 merges.

**Next (Phase 2 — not yet scoped):**
- Implement `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver + repo health checks
- Implement cost-first `IRoutingPolicy` in HoneyDrunk.AI runtime (gated on HoneyDrunk.AI standup)
- Wire routing policies to Azure App Configuration (per ADR-0005 three-tier config split)
- **Scope trigger:** Phase 1 Observe packets merged + a concrete external-project observation need exists + HoneyDrunk.AI standup ADR landed

**Deferred (Phase 3 — blocked on HoneyHub Phase 1):**
- Route normalized `IObservationEvent` instances into HoneyHub's knowledge graph
- Allow HoneyHub to read routing-policy outcomes as plan-adjustment signals
- **Scope trigger:** HoneyHub Phase 1 domain model + graph API live

> **Sync (2026-05-18):** Architecture#36 closed 2026-05-16; the Observe repo creation packet was moved to the completed archive. Architecture#35 and Observe#2 remain open; AI routing remains parked/gated as documented.

### ADR-0030 Grid-Wide Audit Substrate — Capability Acceptance
**Status:** In Progress
**Scope:** Architecture (capability acceptance only; HoneyDrunk.Audit standup is a separate ADR-0031-governed initiative)
**Initiative:** `adr-0030-audit-substrate`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept the capability/decision ADR for the Grid-wide durable, attributable security and action audit substrate homed in a new dedicated `HoneyDrunk.Audit` Node (Core sector). Registers the Node and its four new dependency edges across the catalogs, adds the Core-sector Audit row, flips the ADR index, verifies (does not modify) ADR-0018's pre-existing 2026-05-16 amendment (relocating `IAuditLog`/`AuditEntry` out of Operator, reclassifying Operator to consumer-not-owner), creates the `repos/HoneyDrunk.Audit/` context folder, and adds the constitutional audit-emission boundary invariant. The Node scaffold, the contract-shape canary, the Auth first-emitter wiring, and the Operator reconciliation are **all governed by the separate ADR-0031 standup** and are NOT in this initiative.

**Tracking:**
- [ ] Architecture#NN: Accept ADR-0030 — catalog registration, sectors row, ADR index flip, ADR-0018 amendment verification, repo context folder, trackers (packet 01)
- [ ] Architecture#NN: Add the audit-emission boundary invariant to the constitution (packet 02)

**Next (separate initiative — ADR-0031 standup, not yet scoped here):**
- Stand up `HoneyDrunk.Audit` — public repo, `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`, three frozen contracts, Data-backed append-only store, the Node's own managed identity, in-memory fixture, contract-shape canary
- Wire HoneyDrunk.Auth as the first emitter (separate packet against the stood-up Abstractions)
- Reconcile HoneyDrunk.Operator as consumer/emitter of the relocated contracts (separate packet)
- **Scope trigger:** ADR-0030 acceptance PRs merged + ADR-0030 flipped to Accepted (this initiative complete) — then the user requests an ADR-0031 scoping run

### ADR-0032 PR Validation Policy — Coverage Gate & NuGet Flagging
**Status:** In Progress
**Scope:** Meta (Actions CI/CD control plane) + ten test-bearing Nodes (per-repo coverage backfill)
**Initiative:** `adr-0032-pr-validation-policy`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** One PR Validation Policy owned by the Actions control plane, implemented once in the reusable workflows: (1) a blocking coverage gate — patch coverage threshold, no-regression vs. committed `.github/coverage-baseline.json`, flat absolute floor, skip-when-no-test-projects; (2) non-blocking NuGet flagging — outdated never blocks, surfaced as a PR-summary section and a single grouped `📦 Outdated Dependencies` issue per repo. Builds on ADR-0009 (outdated-vs-vulnerable split), ADR-0011 (`pr-core.yml` tier-1 gate), ADR-0012 (Actions as CI/CD control plane).

**Tracking (Wave 1 — Actions control plane, parallel):**
- [ ] Actions#NN: Coverage gate + ⚠️ outdated-packages PR-summary section (D1–D5) (packet 01)
- [ ] Actions#NN: `nightly-deps` grouped per-repo `📦 Outdated Dependencies` tracking issue (D6) (packet 02)

**Tracking (Wave 2 — per-repo coverage backfill to the absolute floor, hard-blocked by packet 01 only, fully parallel):**
- [ ] Kernel / Transport / Vault / Vault.Rotation / Auth / Web.Rest / Data / Pulse / Notify / Communications — one backfill packet each (packets 03–12)

**Notes:**
- New constitutional invariant (coverage gate at PR time) is added by the implementing packet; number assigned at acceptance, after the ADR-0030/0031 audit reservations (44–46) — see ADR-0032's New Invariant section.
- **Scope trigger:** ADR-0032 Proposed 2026-05-17, scoped same day; packets land via the standard pipeline. Wave 2 unblocks when Wave 1 packet 01 merges.

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

> **Sync (2026-05-16):** 2/5 issues closed (40%). Foundation walkthroughs and reusable Actions workflow remain complete; Notify#3, Notify#4, and Pulse#3 are still open for service-specific release/Azure bring-up work.

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
