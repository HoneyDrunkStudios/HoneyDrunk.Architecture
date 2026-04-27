# Archived Initiatives

Completed and cancelled initiatives. Active and planned work lives in [active-initiatives.md](active-initiatives.md).

---

## Completed

### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)
**Status:** Complete  
**Scope:** Vault, Vault.Rotation, Architecture, Actions, Auth, Web.Rest, Data, Notify, Pulse, Studios
**Initiative:** `adr-0005-0006-rollout`
**Completed:** 2026-04-26 (Wave 2 final issue merged)
**Description:** Per-Node Key Vault + shared App Configuration + env-driven bootstrap model (ADR-0005), plus rotation lifecycle, event-driven invalidation, and deploy-gate SLA checks (ADR-0006). Two waves: foundation then per-Node migration.
**Highlights:**
- All 15 issues merged (Wave 1 foundation 2026-04-11–2026-04-12; Wave 2 per-Node migrations 2026-04-25–2026-04-26)
- Vault v0.3.0 and Vault.Rotation v0.1.0 released 2026-04-25
- Grid now running on env-driven config with per-Node Key Vault bootstrap
- Event-driven cache invalidation and deploy-gate SLA checks operational

### Package Scanning Rollout (ADR-0009)
**Status:** Complete  
**Scope:** Kernel, Auth, Data, Transport, Vault, Pulse, Notify, Web.Rest
**Initiative:** `adr-0009-package-scanning-rollout`
**Completed:** 2026-04-25 (final two issues closed)
**Description:** Wire CI scan workflows and dynamic release notes across all Nodes. Standardizes vulnerability scanning and auto-generates release summaries from commit history.
**Highlights:**
- All 8/8 issues merged (6 completed by 2026-04-16; Pulse#2 and Notify#2 completed 2026-04-25)
- All 8 Nodes now have CI scan workflows configured
- Dynamic release notes in place for CHANGELOG generation

### Architecture Command Center
**Status:** Complete  
**Scope:** Architecture  
**Completed:** 2026-03-28  
**Description:** HoneyDrunk.Architecture stood up as the central command center. Catalogs, routing rules, issue templates, copilot instructions, per-repo context docs, and Azure infrastructure documentation all in place.  

---

## Cancelled

### ~~HoneyDrunk.Tools~~ (Scrapped)
**Status:** Cancelled  
**Scope:** Ops  
**Description:** Originally planned as a separate CLI for scanning, accessibility checks, and CI automation. Decision made to implement this logic directly as composite actions within HoneyDrunk.Actions instead.  
