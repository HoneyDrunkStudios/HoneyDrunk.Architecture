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
- [x] Wave 1 issues filed on board (6/7 — #04 blocked on repo creation)
- [ ] Wave 1: Vault env-driven `AddVault` wiring
- [ ] Wave 1: Vault `AddAppConfiguration` extension
- [ ] Wave 1: Vault event-driven cache invalidation
- [ ] Wave 1: Vault.Rotation repo scaffold
- [ ] Wave 1: Architecture portal walkthroughs
- [ ] Wave 1: Architecture catalog registration for Vault.Rotation
- [ ] Wave 1: Actions OIDC federated-credential workflow
- [ ] Wave 2: Per-Node bootstrap migrations (Auth, Web.Rest, Data, Notify, Pulse, Studios)
- [ ] Wave 2: Actions direct secret removal + deploy-gate SLA check

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

## Planned

### HoneyDrunk.Lore Bring-Up
**Status:** On Deck  
**Scope:** Lore, Architecture  
**Initiative:** `honeydunk-lore-bringup`  
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)  
**Description:** Stand up HoneyDrunk.Lore as a flat-file LLM-compiled wiki. Repo scaffolded with `raw/`, `wiki/`, `output/`, `tools/` directories, CLAUDE.md schema doc, sourcing playbook, Obsidian vault configuration, Web Clipper, scheduled ingest agent, and OpenClaw sourcing skill. Inspired by the Karpathy LLM-wiki pattern. Flat-file-first — Knowledge/Agents integration deferred until those nodes exist.  
**Tracking:**
- [ ] Lore#1: Repo scaffold + CLAUDE.md schema doc
- [ ] Lore#2: Obsidian vault setup + Web Clipper (human-only)
- [ ] Lore#3: Scheduled ingest agent (CronCreate)
- [ ] Lore#4: sourcing-playbook.md
- [ ] Lore#5: OpenClaw setup + Lore sourcing skill (human-only)
- [ ] Architecture#9: Catalog registration for HoneyDrunk.Lore

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
