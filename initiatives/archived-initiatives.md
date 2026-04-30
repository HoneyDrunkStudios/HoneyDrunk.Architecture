# Archived Initiatives

Completed and cancelled initiatives. Active and planned work lives in [active-initiatives.md](active-initiatives.md).

---

## Completed

### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)
**Status:** Complete
**Scope:** Vault, Vault.Rotation, Architecture, Actions, Auth, Web.Rest, Data, Notify, Pulse, Studios
**Initiative:** `adr-0005-0006-rollout`
**Completed:** 2026-04-26
**Description:** Per-Node Key Vault + shared App Configuration + env-driven bootstrap model (ADR-0005), plus rotation lifecycle, event-driven invalidation, and deploy-gate SLA checks (ADR-0006). Two waves executed: foundation (Wave 1, 2026-04-11–12) then per-Node migration (Wave 2, 2026-04-25–26).
**Tracking:** 15/15 issues closed (100%)
- All Core+Ops Nodes now use env-var bootstrap with Azure Key Vault and App Configuration
- Vault.Rotation repo scaffolded and released as v0.1.0 (2026-04-25)
- OIDC federated-credential workflow enabled across Actions deployments
- Deploy-gate SLA checks wired into Actions release pipelines
- Vault v0.3.0+ and Vault.Rotation v0.1.0 released

### Package Scanning Rollout (ADR-0009)
**Status:** Complete
**Scope:** Kernel, Auth, Data, Transport, Vault, Pulse, Notify, Web.Rest
**Initiative:** `adr-0009-package-scanning-rollout`
**Completed:** 2026-04-25
**Description:** Wire CI scan workflows and dynamic release notes across all Nodes. Standardizes vulnerability scanning and auto-generates release summaries from commit history.
**Tracking:** 8/8 issues closed (100%)
- All Nodes now run package scanning in CI pipelines
- Dynamic release notes generated from commit history
- Final two Nodes (Pulse, Notify) completed after Azure Container Apps infrastructure became available (2026-04-25)

### Grid v0.4 Stabilization
**Status:** Complete
**Scope:** Kernel, Transport, Vault, Auth, Web.Rest, Data, Notify, Pulse
**Completed:** 2026-04-26
**Description:** All Core and initial Ops Nodes aligned on Kernel 0.4.0 contracts. Canary tests passing across all boundaries.
**Tracking:** 8/8 items complete
- Kernel v0.4.0 released (2026-04-05)
- Transport, Vault, Auth, Web.Rest, Data v0.4.0 released (2026-04-05)
- Notify and Pulse config bootstrap migrations completed (2026-04-26)
- Full Grid v0.4.0 alignment achieved

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
