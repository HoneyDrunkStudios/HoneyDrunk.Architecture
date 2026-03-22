# Active Initiatives

Tracked initiatives across the HoneyDrunk Grid. Each initiative may span multiple repos.

## In Progress

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

### Architecture Command Center
**Status:** Starting  
**Scope:** Architecture  
**Description:** This repo (HoneyDrunk.Architecture) as the central command center for agentic workflows, issue generation, and cross-repo coordination.

### ~~HoneyDrunk.Tools~~ (Scrapped)
**Status:** Cancelled  
**Scope:** Ops  
**Description:** Originally planned as a separate CLI for scanning, accessibility checks, and CI automation. Decision made to implement this logic directly as composite actions within HoneyDrunk.Actions instead.
