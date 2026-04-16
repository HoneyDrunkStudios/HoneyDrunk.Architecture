# Active Initiatives

Tracked initiatives currently in progress or planned. Completed and cancelled initiatives live in [archived-initiatives.md](archived-initiatives.md).

## In Progress

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

> **Sync (2026-04-16):** 4/12 issues closed (33.3%). Last closed: Vault#10, Vault#9 (both 2026-04-12). Wave 1 blocked on Actions#20 (OIDC federated-credential workflow) — critical gate for Wave 2. Wave 2 per-Node bootstrap issues (Auth#5, Web.Rest#4, Data#4, Notify#1, Pulse#1) waiting behind Wave 1. Also awaiting Vault#12 (release tag). No progress in past 4 days.

### Package Scanning Rollout (ADR-0009)
**Status:** In Progress  
**Scope:** Kernel, Auth, Data, Transport, Vault, Pulse, Notify, Web.Rest  
**Initiative:** `adr-0009-package-scanning-rollout`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Wire CI scan workflows and dynamic release notes across all Nodes. Standardizes vulnerability scanning and auto-generates release summaries from commit history.

**Tracking:**
- [ ] Kernel wire up CI scan workflows (Kernel#14 — open)
- [x] Auth wire up CI scan workflows (Auth#6 closed 2026-04-12)
- [ ] Data wire up CI scan workflows (Data#5 — open)
- [x] Transport wire up CI scan workflows (Transport#14 closed 2026-04-12)
- [x] Vault wire up CI scan workflows (Vault#13 closed 2026-04-12)
- [ ] Pulse wire up CI scan workflows (Pulse#2 — open)
- [ ] Notify wire up CI scan workflows (Notify#2 — open)
- [ ] Web.Rest wire up CI scan workflows (Web.Rest#5 — open)

> **Sync (2026-04-16):** 3/8 issues closed (37.5%). Three closures on 2026-04-12 (Auth#6, Transport#14, Vault#13). Rollout has momentum but stalled in past 4 days. Kernel#14, Data#5, Pulse#2, Notify#2, Web.Rest#5 remain open. No blockers visible; ready to continue.

### Vault.Rotation Bring-Up
**Status:** In Progress  
**Scope:** Vault.Rotation, Architecture, Actions  
**Initiative:** `vault-rotation-bring-up`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Scaffold HoneyDrunk.Vault.Rotation as a deployable Function Node, wire OIDC + RBAC, and complete ADR-0006 Tier-2 operational setup.
**Tracking:**
- [x] Architecture catalog registration + routing keywords (Architecture#7 closed 2026-04-11)
- [ ] Architecture repo stubs (`repos/HoneyDrunk.Vault.Rotation/*`)
- [ ] Repo scaffold implementation packet execution (unblocked — Architecture#8 repo creation closed 2026-04-11)
- [ ] Managed identity + vault RBAC automation
- [ ] Rotation function runtime + observability

> **Sync (2026-04-16):** 1/5 tracking items complete. Architecture#8 repo creation (closed 2026-04-11) unblocked Vault.Rotation scaffold execution. Repo stubs and managed identity work now in-flight or on deck. Awaiting Codex handoff progress.

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

> **Sync (2026-04-16):** 6/8 items done. Core nodes (Kernel, Transport, Vault, Auth, Web.Rest, Data) all v0.4.0 aligned. Notify (v0.1.0) and Pulse (v0.1.0) are Seed signal, blocked by Azure deployment per grid-health.json. No new progress in past 4 days. Core objectives met; Notify/Pulse deployment gated on infrastructure provisioning.

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
- [ ] Lore#1: Repo scaffold + CLAUDE.md schema doc
- [ ] Lore#2: Obsidian vault setup + Web Clipper (human-only)
- [ ] Lore#3: Scheduled ingest agent (CronCreate)
- [ ] Lore#4: sourcing-playbook.md
- [ ] Lore#5: OpenClaw setup + Lore sourcing skill (human-only)
- [ ] Architecture#9: Catalog registration for HoneyDrunk.Lore

> **Sync (2026-04-16):** 0/6 issues closed (0%). All Lore bring-up issues remain open (Lore#1–5, Architecture#9). grid-health.json shows Seed signal with active_blockers = ["Repo not yet scaffolded", "Bring-up packets on deck"]. Status: On Deck behind ADR-0005/0006 Wave 1 completion (Actions#20 still blocking). Ready to start once Wave 1 closes.

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
