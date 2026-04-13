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

> **Sync (2026-04-13):** 4/14 issues closed (28.6%). No new closures since 2026-04-12. Wave 1 is still blocked on Actions#20 (OIDC federated-credential workflow). Wave 2 blocked behind Wave 1 completion. All Wave 2 per-Node bootstrap issues (Auth#5, Web.Rest#4, Data#4, Notify#1, Pulse#1) and Actions#21 (deploy-gate) remain open. Status unchanged.

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

> **Sync (2026-04-13):** 3/8 issues closed (37.5%). Three closures in past 24 hours (Auth#6, Transport#14, Vault#13 all on 2026-04-12). Rollout has momentum. Kernel#14, Data#5, Pulse#2, Notify#2, Web.Rest#5 remain open.

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

> **Sync (2026-04-12):** 1/5 tracking items complete. Architecture#8 (Create Vault.Rotation repo) closed 2026-04-11, meaning the GitHub repo now exists. Repo scaffold execution (Codex handoff) is unblocked. Architecture#7 closing confirmed catalog registration is done.

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

> **Sync (2026-04-12):** 6/8 items done. Notify (v0.1.0) and Pulse (v0.1.0) still awaiting deployment; both blocked on Azure provisioning and integration tests per grid-health.json. Core nodes all show 0.4.0 in grid-health. This initiative is effectively complete for Core and awaiting Notify/Pulse deploy to fully close.

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

> **Sync (2026-04-12):** 5/7 items done. Azure Functions deployment and live provider integration tests remain. grid-health.json confirms: active_blockers = ["Azure Functions deployment pending", "Integration tests pending"]. No change in status since last check.

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

> **Sync (2026-04-12):** 3/5 items done. grid-health.json confirms active_blockers = ["Production deployment pending", "Grafana templates pending"]. No change in status since last check.

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

> **Sync (2026-04-12):** 0/6 issues closed (0%). All Lore bring-up issues are open. grid-health.json shows Lore in Seed signal with active_blockers = ["Repo not yet scaffolded", "Bring-up packets on deck"]. This initiative is On Deck behind ADR-0005/0006 Wave 1 completion.

### Agent Kit
**Status:** On Deck  
**Scope:** AI  
**Description:** Agent execution runtime, tool abstraction, and memory. Foundation for AI-powered workflows across the Grid.  
