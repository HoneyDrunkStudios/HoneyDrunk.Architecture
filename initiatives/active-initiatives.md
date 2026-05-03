# Active Initiatives

Tracked initiatives currently in progress or planned. Completed and cancelled initiatives live in [archived-initiatives.md](archived-initiatives.md).

## In Progress

### ADR-0010 Observation Layer & AI Routing — Phase 1
**Status:** In Progress
**Scope:** Architecture, Observe (new), AI
**Initiative:** `adr-0010-observe-ai-routing-phase-1`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Accept ADR-0010 and ship Phase 1 (contracts + stubs). Catalog registration for HoneyDrunk.Observe, new Observe repo scaffold with Abstractions package, and routing contracts in HoneyDrunk.AI.Abstractions. Phase 2 (first GitHub connector + cost-first routing policy) and Phase 3 (HoneyHub integration, blocked on HoneyHub Phase 1 being live) are tracked below so they do not get lost.

**Tracking (Phase 1 — Observe side):**
- [ ] Architecture#NN: Accept ADR-0010 — catalog, context folder, sectors, invariant 29-30 text, ADR index flip, initiative/roadmap trackers (packet 01)
- [ ] Architecture#NN: Create HoneyDrunk.Observe GitHub repo (human-only chore — packet 02)
- [ ] Observe#1: Scaffold HoneyDrunk.Observe.Abstractions with IObservationTarget / IObservationConnector / IObservationEvent (packet 03)

**Deferred (Phase 1 — AI routing contracts side):**
- AI#NN: Add IModelRouter / IRoutingPolicy / ModelCapabilityDeclaration to HoneyDrunk.AI.Abstractions (packet 04) — **parked pending HoneyDrunk.AI standup ADR**. The HoneyDrunk.AI repo exists but is empty; scaffolding choices (solution layout, M.E.AI alignment, package split, first provider, Pulse integration) deserve their own ADR. Provisional next step: draft `ADR-0016-stand-up-honeydrunk-ai-node`, accept it, run a scaffolding initiative, then file packet 04. Invariant 28's `(Proposed)` qualifier stays intact until packet 04 merges.

**Next (Phase 2 — not yet scoped):**
- Implement `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver + repo health checks
- Implement cost-first `IRoutingPolicy` in HoneyDrunk.AI runtime (gated on HoneyDrunk.AI standup)
- Wire routing policies to Azure App Configuration (per ADR-0005 three-tier config split)
- **Scope trigger:** Phase 1 Observe packets merged + a concrete external-project observation need exists + HoneyDrunk.AI standup ADR landed

**Deferred (Phase 3 — blocked on HoneyHub Phase 1):**
- Route normalized `IObservationEvent` instances into HoneyHub's knowledge graph
- Allow HoneyHub to read routing-policy outcomes as plan-adjustment signals
- **Scope trigger:** HoneyHub Phase 1 domain model + graph API live

> **Sync (2026-04-18):** Initiative scoped today. Packets 01–03 ready to file (Observe side). Packet 04 (AI routing contracts) parked pending HoneyDrunk.AI standup ADR — bundling scaffold with routing contracts would embed foundational-Node architectural decisions silently.

### Hive Sync Rollout (ADR-0014)
**Status:** In Progress
**Scope:** Architecture
**Initiative:** `adr-0014-hive-sync-rollout`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Rename the legacy initiative sync agent to `hive-sync` and broaden its mandate to cover the packet lifecycle (active → completed), non-initiative board items, the Proposed-ADR/PDR queue, ADR/PDR auto-acceptance + README index sync, and a drift report. Closes the drift introduced by nightly-security issues having no Architecture-repo presence, completed packets lingering in `active/`, and ADRs/PDRs that drift out of sync with their implementing work or with the rest of the repo. Single repo (Architecture); six sequential phases. ADR-0014 itself auto-flips to Accepted via Phase 5's logic on the first run after Packet 06 closes.

**Tracking:**
- [ ] Architecture#61: Rename agent + capability matrix (packet 01)
- [ ] Architecture#62: Add packet lifecycle and Hive-Sync invariant for lifecycle (packet 02)
- [ ] Architecture#63: Track non-initiative board items + Hive-Sync invariant for board coverage (packet 03)
- [ ] Architecture#64: Surface Proposed-ADR acceptance queue (packet 04)
- [ ] Architecture#65: ADR/PDR auto-acceptance + README index sync (packet 05)
- [ ] Architecture#66: Drift detection + close out the rollout (packet 06)


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
- [ ] Wave 1: Actions OIDC federated-credential workflow (Actions#20 — open)
- [ ] Wave 2: Per-Node bootstrap migrations (Auth, Web.Rest, Data, Notify, Pulse, Studios)
- [ ] Wave 2: Actions direct secret removal + deploy-gate SLA check

> **Sync (2026-04-20):** 4/15 issues closed (26.7%). Last closed: Vault#10, Vault#9 (both 2026-04-12). Wave 1 blocked on Actions#20 (OIDC federated-credential workflow) — critical gate for Wave 2. Wave 2 per-Node bootstrap issues (Auth#5, Web.Rest#4, Data#4, Notify#1, Pulse#1) waiting behind Wave 1. Also awaiting Vault#12 (release tag) and Vault.Rotation#4 (release tag). No progress on open issues in past 8 days (last activity 2026-04-12). Wave 1 foundation work complete; Wave 2 execution blocked on Actions#20.

### Container Apps Rollout (ADR-0015)
**Status:** In Progress  
**Scope:** Architecture, Actions, Notify, Pulse  
**Initiative:** `adr-0015-container-apps-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Deploy Notify and Pulse to Azure Container Apps. Includes infrastructure walkthroughs, Container App deployment workflow in Actions, and per-service release workflows.

**Tracking:**
- [ ] Architecture#37: Infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App (open)
- [ ] Actions#48: Reusable workflow `job-deploy-container-app.yml` for Azure Container Apps (open)
- [ ] Notify#3: Release workflow and Azure bring-up for `Notify.Functions` (open)
- [ ] Notify#4: Release workflow and Azure bring-up for `Notify.Worker` on Container Apps (open)
- [ ] Pulse#3: Release workflow and Azure bring-up for `Pulse.Collector` on Container Apps (open)

> **Sync (2026-04-20):** 0/5 issues closed (0%). Initiative scoped and filed 2026-04-12. No progress yet — work is sequenced after ADR-0005/0006 Wave 2 and Notify/Pulse stabilization.

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
- [ ] Pulse wire up CI scan workflows (Pulse#2 — open)
- [ ] Notify wire up CI scan workflows (Notify#2 — open)
- [x] Web.Rest wire up CI scan workflows (Web.Rest#5 closed 2026-04-16)

> **Sync (2026-04-20):** 6/8 issues closed (75%). Momentum resumed 2026-04-16 with Kernel#14, Data#5, Web.Rest#5 closures. Only Pulse#2 and Notify#2 remain open. Rollout near completion — last two issues are infrastructure-gated (both Pulse and Notify awaiting Azure deployment per grid-health.json).

### Vault.Rotation Bring-Up
**Status:** In Progress  
**Scope:** Vault.Rotation, Architecture, Actions  
**Initiative:** `vault-rotation-bring-up`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Scaffold HoneyDrunk.Vault.Rotation as a deployable Function Node, wire OIDC + RBAC, and complete ADR-0006 Tier-2 operational setup.
**Tracking:**
- [x] Architecture catalog registration + routing keywords (Architecture#7 closed 2026-04-11)
- [ ] Architecture repo stubs (`repos/HoneyDrunk.Vault.Rotation/*`)
- [ ] Repo scaffold implementation packet execution (Vault.Rotation#3 — open, unblocked by Architecture#8 closed 2026-04-11)
- [ ] Managed identity + vault RBAC automation
- [ ] Rotation function runtime + observability

> **Sync (2026-04-20):** 1/5 tracking items complete. Architecture#8 repo creation unblocked Vault.Rotation scaffold execution. Vault.Rotation#3 scaffold issue remains open (unblocked but awaiting Codex execution). No new progress since 2026-04-11.

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
- [ ] Azure Functions deployment
- [ ] Integration tests with live providers

> **Sync (2026-04-16):** 5/7 items done. Azure Functions deployment and live provider integration tests remain blocked on infrastructure provisioning. grid-health.json confirms active_blockers. No progress in 4 days; gated on deployment infrastructure.

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
- [ ] Lore#1: Repo scaffold + CLAUDE.md schema doc (open)
- [ ] Lore#2: Obsidian vault setup + Web Clipper (human-only) (open)
- [ ] Lore#3: Scheduled ingest agent (CronCreate) (open)
- [ ] Lore#4: sourcing-playbook.md (open)
- [ ] Lore#5: OpenClaw setup + Lore sourcing skill (human-only) (open)
- [ ] Architecture#9: Catalog registration for HoneyDrunk.Lore (open)

> **Sync (2026-04-20):** 0/6 issues closed (0%). All Lore bring-up issues remain open. grid-health.json shows signal: Seed with active_blockers = ["Repo not yet scaffolded", "Bring-up packets on deck"]. Status: On Deck behind ADR-0005/0006 Wave 1 completion (Actions#20 still blocking Wave 2, thus delaying Lore start). No progress since initial filing (2026-04-12).

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
