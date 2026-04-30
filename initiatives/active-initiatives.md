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

### Container Apps Rollout (ADR-0015)
**Status:** In Progress  
**Scope:** Architecture, Actions, Notify, Pulse  
**Initiative:** `adr-0015-container-apps-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Deploy Notify and Pulse to Azure Container Apps. Includes infrastructure walkthroughs, Container App deployment workflow in Actions, and per-service release workflows.

**Tracking:**
- [x] Architecture#37: Infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App (closed 2026-04-26)
- [x] Actions#48: Reusable workflow `job-deploy-container-app.yml` for Azure Container Apps (closed 2026-04-25)
- [ ] Notify#3: Release workflow and Azure bring-up for `Notify.Functions` (open)
- [ ] Notify#4: Release workflow and Azure bring-up for `Notify.Worker` on Container Apps (open)
- [ ] Pulse#3: Release workflow and Azure bring-up for `Pulse.Collector` on Container Apps (open)

> **Sync (2026-04-30):** 2/5 issues closed (40%). Infrastructure walkthroughs (Arch#37) and Container Apps deployment workflow (Actions#48) complete. Three per-service release workflows (Notify#3, Notify#4, Pulse#3) remain open. ADR-0005/0006 Wave 2 completion (2026-04-26) and Actions workflow availability (2026-04-25) unblocked progress. Services ready for deployment infrastructure.

### Vault.Rotation Bring-Up
**Status:** In Progress  
**Scope:** Vault.Rotation, Architecture, Actions  
**Initiative:** `vault-rotation-bring-up`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Scaffold HoneyDrunk.Vault.Rotation as a deployable Function Node, wire OIDC + RBAC, and complete ADR-0006 Tier-2 operational setup.
**Tracking:**
- [x] Architecture catalog registration + routing keywords (Architecture#7 closed 2026-04-11)
- [x] Repo scaffold implementation packet execution (Vault.Rotation#3 closed 2026-04-25)
- [x] Release tag: Vault.Rotation#4 (released 2026-04-25 as v0.1.0)
- [ ] Architecture repo stubs (`repos/HoneyDrunk.Vault.Rotation/*`)
- [ ] Managed identity + vault RBAC automation
- [ ] Rotation function runtime + observability

> **Sync (2026-04-30):** 3/6 tracking items complete. Vault.Rotation#3 scaffold closed 2026-04-25 after repo creation unblocked 2026-04-11. Release tagged 2026-04-25 as v0.1.0. Architecture stubs and operational setup (managed identity, RBAC, observability) remain. Foundation complete; operations/deployment work on deck.

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
